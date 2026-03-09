use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Whether a smart playlist directly contains episodes or groups.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PlaylistStructure {
    Split,
    Grouped,
}

impl Default for PlaylistStructure {
    fn default() -> Self {
        PlaylistStructure::Split
    }
}

/// How year headers are applied to groups or episodes.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum YearBinding {
    None,
    PinToYear,
    SplitByYear,
}

impl Default for YearBinding {
    fn default() -> Self {
        YearBinding::None
    }
}

fn is_default_playlist_structure(v: &PlaylistStructure) -> bool {
    *v == PlaylistStructure::Split
}

fn is_default_year_binding(v: &YearBinding) -> bool {
    *v == YearBinding::None
}

fn is_zero_i32(v: &i32) -> bool {
    *v == 0
}

/// A group within a smart playlist containing episodes.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaylistGroup {
    pub id: String,
    pub display_name: String,

    #[serde(default, skip_serializing_if = "is_zero_i32")]
    pub sort_key: i32,

    pub episode_ids: Vec<i64>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub thumbnail_url: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub year_override: Option<YearBinding>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_year_headers: Option<bool>,

    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub show_date_range: bool,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub earliest_date: Option<DateTime<Utc>>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub latest_date: Option<DateTime<Utc>>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub total_duration_ms: Option<i64>,
}

impl PlaylistGroup {
    pub fn episode_count(&self) -> usize {
        self.episode_ids.len()
    }
}

/// Represents a smart playlist grouping of episodes within a podcast.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Playlist {
    pub id: String,
    pub display_name: String,
    pub sort_key: i32,
    pub episode_ids: Vec<i64>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub thumbnail_url: Option<String>,

    #[serde(default, skip_serializing_if = "is_default_playlist_structure")]
    pub playlist_structure: PlaylistStructure,

    #[serde(default, skip_serializing_if = "is_default_year_binding")]
    pub year_binding: YearBinding,

    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub show_year_headers: bool,

    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub show_date_range: bool,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub groups: Option<Vec<PlaylistGroup>>,
}

impl Playlist {
    pub fn episode_count(&self) -> usize {
        self.episode_ids.len()
    }
}

/// Result from a smart playlist resolver containing grouped playlists.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Grouping {
    pub playlists: Vec<Playlist>,
    pub ungrouped_episode_ids: Vec<i64>,
    pub resolver_type: String,
}

impl Grouping {
    pub fn has_ungrouped(&self) -> bool {
        !self.ungrouped_episode_ids.is_empty()
    }
}
