use serde::{Deserialize, Serialize};

use super::default_data_version;

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

    /// Ordered list of playlist IDs.
    pub playlists: Vec<String>,
}
