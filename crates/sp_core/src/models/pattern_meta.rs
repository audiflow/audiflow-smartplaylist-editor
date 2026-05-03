use serde::{Deserialize, Serialize};

use super::default_data_version;

fn default_true() -> bool {
    true
}

fn is_true(b: &bool) -> bool {
    *b
}

/// Pattern-level meta.json from a pattern directory.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PatternMeta {
    #[serde(default = "default_data_version")]
    pub data_version: i32,

    pub id: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub podcast_guid: Option<String>,

    pub feed_urls: Vec<String>,

    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub year_grouped_episodes: bool,

    /// Show thumbnails on rows of the main podcast episode list. Defaults to true; omitted from JSON when true.
    #[serde(default = "default_true", skip_serializing_if = "is_true")]
    pub show_episode_thumbnail: bool,

    /// Ordered list of playlist IDs.
    pub playlists: Vec<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn show_episode_thumbnail_defaults_to_true_when_absent() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        assert!(meta.show_episode_thumbnail, "default should be true");
    }

    #[test]
    fn show_episode_thumbnail_round_trips_false() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "showEpisodeThumbnail": false,
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        assert!(!meta.show_episode_thumbnail);
        let out = serde_json::to_value(&meta).unwrap();
        assert_eq!(out["showEpisodeThumbnail"], serde_json::json!(false));
    }

    #[test]
    fn show_episode_thumbnail_omitted_when_default_true() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        let out = serde_json::to_value(&meta).unwrap();
        assert!(out.get("showEpisodeThumbnail").is_none(),
                "field should be omitted when default true");
    }
}
