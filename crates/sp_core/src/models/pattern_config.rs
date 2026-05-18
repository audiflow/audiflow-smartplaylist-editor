use serde::{Deserialize, Serialize};

use super::playlist_definition::PlaylistDefinition;

/// Deserialize empty strings as None for podcastGuid.
fn deserialize_null_if_empty<'de, D>(deserializer: D) -> Result<Option<String>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let opt: Option<String> = Option::deserialize(deserializer)?;
    Ok(opt.filter(|s| !s.is_empty()))
}

/// Top-level pattern configuration that matches a podcast and
/// provides its playlist definitions.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PatternConfig {
    pub id: String,

    #[serde(
        default,
        skip_serializing_if = "Option::is_none",
        deserialize_with = "deserialize_null_if_empty"
    )]
    pub podcast_guid: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub feed_urls: Option<Vec<String>>,

    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub year_grouped_episodes: bool,

    /// Tri-state: `None` = use schema default; `Some(true)` = explicit on; `Some(false)` = explicit off.
    /// Mirrors `PatternMeta::show_episode_thumbnail` so the assembled config round-trips
    /// the field to the editor; without this, `GET /assembled` would drop the value.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub show_episode_thumbnail: Option<bool>,

    pub playlists: Vec<PlaylistDefinition>,
}

impl PatternConfig {
    /// Returns true if this config matches the given podcast.
    pub fn matches_podcast(&self, guid: Option<&str>, feed_url: &str) -> bool {
        if let Some(ref my_guid) = self.podcast_guid
            && guid == Some(my_guid.as_str())
        {
            return true;
        }
        if let Some(ref urls) = self.feed_urls
            && urls.iter().any(|u| u == feed_url)
        {
            return true;
        }
        false
    }
}
