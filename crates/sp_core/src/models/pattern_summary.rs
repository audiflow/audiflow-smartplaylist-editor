use serde::{Deserialize, Serialize};

fn default_data_version() -> i32 {
    1
}

/// Summary of a pattern from root meta.json.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PatternSummary {
    pub id: String,

    #[serde(default = "default_data_version")]
    pub data_version: i32,

    pub display_name: String,
    pub feed_url_hint: String,
    pub playlist_count: i32,
}
