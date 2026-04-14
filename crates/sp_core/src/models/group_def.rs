use serde::{Deserialize, Serialize};

use super::numbering_extractor::NumberingExtractor;
use super::sort::EpisodeSortRule;
use super::title_extractor::TitleExtractor;

/// Matches episode content by regex against a selected source field.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Matcher {
    pub source: String,
    pub pattern: String,
}

/// Static group definition within a playlist.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDef {
    pub id: String,
    pub display_name: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub pattern: Option<Matcher>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_listing: Option<GroupDefGroupListing>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_item: Option<GroupDefGroupItem>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_listing: Option<GroupDefEpisodeListing>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_item: Option<GroupDefEpisodeItem>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub numbering_extractor: Option<NumberingExtractor>,
}

/// Per-group overrides for the group list section.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefGroupListing {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year_binding: Option<String>,
}

/// Per-group overrides for the group card.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefGroupItem {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_date_range: Option<bool>,
}

/// Per-group overrides for the episode list.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefEpisodeListing {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_year_headers: Option<bool>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<EpisodeSortRule>,
}

/// Per-group overrides for individual episode rows.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefEpisodeItem {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,
}
