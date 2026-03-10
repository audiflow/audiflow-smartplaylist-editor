use quick_xml::events::Event;
use quick_xml::reader::Reader;
use serde_json::{json, Value};

/// Parses an RSS feed into the JSON format the React app expects.
///
/// Each item is mapped to a JSON object with fields: id, title,
/// description, guid, publishedAt, seasonNumber, episodeNumber, imageUrl.
pub fn parse_feed(content: &str) -> Vec<Value> {
    let mut reader = Reader::from_str(content);
    let mut episodes = Vec::new();
    let mut buf = Vec::new();
    let mut inside_item = false;
    let mut index: usize = 0;

    // Current item fields
    let mut title = String::new();
    let mut description: Option<String> = None;
    let mut guid: Option<String> = None;
    let mut pub_date: Option<String> = None;
    let mut season_number: Option<i64> = None;
    let mut episode_number: Option<i64> = None;
    let mut image_url: Option<String> = None;

    // Tracks the current element name (local name + prefix)
    let mut current_element: Option<(String, Option<String>)> = None;

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) | Ok(Event::Empty(ref e)) => {
                let local = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                let prefix = e
                    .name()
                    .prefix()
                    .map(|p| String::from_utf8_lossy(p.as_ref()).to_string());

                if local == "item" && prefix.is_none() {
                    inside_item = true;
                    title = String::new();
                    description = None;
                    guid = None;
                    pub_date = None;
                    season_number = None;
                    episode_number = None;
                    image_url = None;
                } else if inside_item {
                    // Handle itunes:image as empty element with href attr
                    if local == "image" && prefix.as_deref() == Some("itunes")
                        && let Some(attr) = e
                            .attributes()
                            .flatten()
                            .find(|a| a.key.as_ref() == b"href")
                    {
                        image_url = String::from_utf8(attr.value.to_vec()).ok();
                    }
                    current_element = Some((local, prefix));
                }
            }
            Ok(Event::Text(ref e)) => {
                if !inside_item {
                    continue;
                }
                let text = e.unescape().unwrap_or_default().trim().to_string();
                apply_text_content(
                    &text, &current_element, &mut title, &mut description,
                    &mut guid, &mut pub_date, &mut season_number, &mut episode_number,
                );
            }
            Ok(Event::CData(ref e)) => {
                if !inside_item {
                    continue;
                }
                let text = String::from_utf8_lossy(e.as_ref()).trim().to_string();
                apply_text_content(
                    &text, &current_element, &mut title, &mut description,
                    &mut guid, &mut pub_date, &mut season_number, &mut episode_number,
                );
            }
            Ok(Event::End(ref e)) => {
                let local = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if local == "item" && inside_item {
                    let published_at = pub_date.as_deref().and_then(parse_date);
                    episodes.push(json!({
                        "id": index,
                        "title": title,
                        "description": description,
                        "guid": guid,
                        "publishedAt": published_at,
                        "seasonNumber": season_number,
                        "episodeNumber": episode_number,
                        "imageUrl": image_url,
                    }));
                    index += 1;
                    inside_item = false;
                }
                current_element = None;
            }
            Ok(Event::Eof) => break,
            Err(_) => return Vec::new(),
            _ => {}
        }
        buf.clear();
    }

    episodes
}

#[allow(clippy::too_many_arguments)]
fn apply_text_content(
    text: &str,
    current_element: &Option<(String, Option<String>)>,
    title: &mut String,
    description: &mut Option<String>,
    guid: &mut Option<String>,
    pub_date: &mut Option<String>,
    season_number: &mut Option<i64>,
    episode_number: &mut Option<i64>,
) {
    if text.is_empty() {
        return;
    }
    if let Some((local, prefix)) = current_element {
        match (prefix.as_deref(), local.as_str()) {
            (None, "title") => *title = text.to_string(),
            (None, "description") => *description = Some(text.to_string()),
            (None, "guid") => *guid = Some(text.to_string()),
            (None, "pubDate") => *pub_date = Some(text.to_string()),
            (Some("itunes"), "season") => {
                *season_number = text.parse::<i64>().ok();
            }
            (Some("itunes"), "episode") => {
                *episode_number = text.parse::<i64>().ok();
            }
            _ => {}
        }
    }
}

/// Attempts to parse a date string, trying ISO 8601 first, then RFC 2822.
fn parse_date(date_str: &str) -> Option<String> {
    // Try ISO 8601 / RFC 3339
    if let Ok(dt) = chrono::DateTime::parse_from_rfc3339(date_str) {
        return Some(dt.to_rfc3339());
    }
    // Try RFC 2822 (common in RSS pubDate)
    if let Ok(dt) = chrono::DateTime::parse_from_rfc2822(date_str) {
        return Some(dt.to_rfc3339());
    }
    // Try manual RFC 2822-like parsing as fallback
    parse_rfc2822_manual(date_str)
}

/// Manual RFC 2822-like date parsing for unusual formats.
fn parse_rfc2822_manual(input: &str) -> Option<String> {
    let cleaned = if input.contains(',') {
        input[input.find(',')? + 1..].trim()
    } else {
        input.trim()
    };

    let parts: Vec<&str> = cleaned.split_whitespace().collect();
    if 4 <= parts.len() {
        let day: u32 = parts[0].parse().ok()?;
        let month = month_number(parts[1])?;
        let year: i32 = parts[2].parse().ok()?;

        let time_parts: Vec<&str> = parts[3].split(':').collect();
        let hour: u32 = time_parts.first().and_then(|s| s.parse().ok()).unwrap_or(0);
        let minute: u32 = time_parts.get(1).and_then(|s| s.parse().ok()).unwrap_or(0);
        let second: u32 = time_parts.get(2).and_then(|s| s.parse().ok()).unwrap_or(0);

        let dt = chrono::NaiveDate::from_ymd_opt(year, month, day)?
            .and_hms_opt(hour, minute, second)?;
        let utc = chrono::DateTime::<chrono::Utc>::from_naive_utc_and_offset(dt, chrono::Utc);
        return Some(utc.to_rfc3339());
    }
    None
}

fn month_number(abbr: &str) -> Option<u32> {
    match abbr {
        "Jan" => Some(1),
        "Feb" => Some(2),
        "Mar" => Some(3),
        "Apr" => Some(4),
        "May" => Some(5),
        "Jun" => Some(6),
        "Jul" => Some(7),
        "Aug" => Some(8),
        "Sep" => Some(9),
        "Oct" => Some(10),
        "Nov" => Some(11),
        "Dec" => Some(12),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_rss() -> &'static str {
        r#"<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Test Podcast</title>
    <item>
      <title>Episode 1: Pilot</title>
      <description>The first episode</description>
      <guid>ep-001</guid>
      <pubDate>Mon, 01 Jan 2024 12:00:00 +0000</pubDate>
      <itunes:season>1</itunes:season>
      <itunes:episode>1</itunes:episode>
      <itunes:image href="https://example.com/ep1.jpg"/>
    </item>
    <item>
      <title>Episode 2: Continuation</title>
      <description>The second episode</description>
      <guid>ep-002</guid>
      <pubDate>Mon, 08 Jan 2024 12:00:00 +0000</pubDate>
      <itunes:season>1</itunes:season>
      <itunes:episode>2</itunes:episode>
    </item>
    <item>
      <title>Bonus: Behind the Scenes</title>
      <guid>ep-bonus</guid>
    </item>
  </channel>
</rss>"#
    }

    #[test]
    fn parse_feed_extracts_episode_data() {
        let episodes = parse_feed(sample_rss());
        assert_eq!(episodes.len(), 3);

        let ep1 = &episodes[0];
        assert_eq!(ep1["id"], 0);
        assert_eq!(ep1["title"], "Episode 1: Pilot");
        assert_eq!(ep1["description"], "The first episode");
        assert_eq!(ep1["guid"], "ep-001");
        assert_eq!(ep1["seasonNumber"], 1);
        assert_eq!(ep1["episodeNumber"], 1);
        assert_eq!(ep1["imageUrl"], "https://example.com/ep1.jpg");
        assert!(!ep1["publishedAt"].is_null());
    }

    #[test]
    fn parse_feed_handles_missing_optional_fields() {
        let episodes = parse_feed(sample_rss());
        let bonus = &episodes[2];

        assert_eq!(bonus["id"], 2);
        assert_eq!(bonus["title"], "Bonus: Behind the Scenes");
        assert!(bonus["description"].is_null());
        assert!(bonus["seasonNumber"].is_null());
        assert!(bonus["episodeNumber"].is_null());
        assert!(bonus["imageUrl"].is_null());
    }

    #[test]
    fn parse_feed_returns_empty_for_invalid_xml() {
        let episodes = parse_feed("not valid xml at all");
        assert!(episodes.is_empty());
    }

    #[test]
    fn parse_feed_returns_empty_title_when_missing() {
        let xml = r#"<?xml version="1.0"?>
<rss version="2.0">
  <channel>
    <item>
      <guid>no-title</guid>
    </item>
  </channel>
</rss>"#;
        let episodes = parse_feed(xml);
        assert_eq!(episodes.len(), 1);
        assert_eq!(episodes[0]["title"], "");
    }

    #[test]
    fn parse_feed_handles_cdata_description() {
        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title><![CDATA[CDATA Title]]></title>
      <description><![CDATA[This is a <b>rich</b> description]]></description>
      <guid>cdata-ep</guid>
    </item>
  </channel>
</rss>"#;
        let episodes = parse_feed(xml);
        assert_eq!(episodes.len(), 1);
        assert_eq!(episodes[0]["title"], "CDATA Title");
        assert_eq!(
            episodes[0]["description"],
            "This is a <b>rich</b> description"
        );
    }

    #[test]
    fn parse_date_handles_rfc2822() {
        let result = parse_date("Mon, 01 Jan 2024 12:00:00 +0000");
        assert!(result.is_some());
        assert!(result.unwrap().contains("2024"));
    }

    #[test]
    fn parse_date_returns_none_for_garbage() {
        assert!(parse_date("not a date").is_none());
    }
}
