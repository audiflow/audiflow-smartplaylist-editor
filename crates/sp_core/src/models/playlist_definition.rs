use serde::{Deserialize, Serialize};

use super::numbering_extractor::NumberingExtractor;
use super::group_def::GroupDef;
use super::is_zero;
use super::sort::{EpisodeSortRule, SortRule};
use super::title_extractor::TitleExtractor;

/// Unified per-playlist definition with all fields strongly typed.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaylistDefinition {
    pub id: String,
    pub display_name: String,
    pub resolver_type: String,
    #[serde(alias = "playlistStructure")]
    pub presentation: String,

    /// Episode claiming order among siblings (lower = first, default: 0).
    #[serde(default, skip_serializing_if = "is_zero")]
    pub priority: i32,

    /// Episode filters applied before resolver processing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_filters: Option<EpisodeFilters>,

    /// Group key to assign to episodes with null season number.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub null_season_group_key: Option<i32>,

    /// Configuration for extracting playlist/group display names.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,

    /// Whether to prepend "S{n}" to resolver result names.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub prepend_season_number: bool,

    /// Settings for the group list view (grouped mode only).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_list: Option<GroupListSettings>,

    /// Default episode list display and ordering settings.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_list: Option<EpisodeListSettings>,

    /// Configuration for extracting season and episode numbers.
    /// Accepts legacy `episodeExtractor` key for v3 backward compatibility.
    #[serde(skip_serializing_if = "Option::is_none", alias = "episodeExtractor")]
    pub numbering_extractor: Option<NumberingExtractor>,

    /// Static group definitions for titleClassifier-based grouping.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub groups: Option<Vec<GroupDef>>,
}

impl PlaylistDefinition {
    /// Whether this definition has any effective episode filters.
    pub fn has_filters(&self) -> bool {
        match &self.episode_filters {
            None => false,
            Some(f) => {
                let has_require = f
                    .require
                    .as_ref()
                    .is_some_and(|r| !r.is_empty());
                let has_exclude = f
                    .exclude
                    .as_ref()
                    .is_some_and(|e| !e.is_empty());
                has_require || has_exclude
            }
        }
    }
}

/// Episode filters applied before resolver processing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpisodeFilters {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub require: Option<Vec<EpisodeFilterEntry>>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub exclude: Option<Vec<EpisodeFilterEntry>>,
}

/// A single filter condition matched against episode fields.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpisodeFilterEntry {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
}

/// Settings for the group list view (grouped mode only).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupListSettings {
    /// How groups relate to year headers.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year_binding: Option<String>,

    /// Allow users to change sort order at runtime.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user_sortable: Option<bool>,

    /// Show date range on group cards.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_date_range: Option<bool>,

    /// Sort rule for ordering groups.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<SortRule>,
}

/// Default episode list display and ordering settings.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EpisodeListSettings {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_year_headers: Option<bool>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<EpisodeSortRule>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,
}
