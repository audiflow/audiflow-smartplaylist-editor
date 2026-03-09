use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use super::is_zero;

/// Whether a smart playlist directly contains episodes or groups.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PlaylistStructure {
    #[default]
    Split,
    Grouped,
}

/// How year headers are applied to groups or episodes.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum YearBinding {
    #[default]
    None,
    PinToYear,
    SplitByYear,
}

fn is_default_playlist_structure(v: &PlaylistStructure) -> bool {
    *v == PlaylistStructure::Split
}

fn is_default_year_binding(v: &YearBinding) -> bool {
    *v == YearBinding::None
}

/// A group within a smart playlist containing episodes.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaylistGroup {
    pub id: String,
    pub display_name: String,

    #[serde(default, skip_serializing_if = "is_zero")]
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
    pub fn new(id: String, display_name: String, sort_key: i32, episode_ids: Vec<i64>) -> Self {
        Self {
            id,
            display_name,
            sort_key,
            episode_ids,
            thumbnail_url: None,
            playlist_structure: PlaylistStructure::default(),
            year_binding: YearBinding::default(),
            show_year_headers: false,
            show_date_range: false,
            groups: None,
        }
    }

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
