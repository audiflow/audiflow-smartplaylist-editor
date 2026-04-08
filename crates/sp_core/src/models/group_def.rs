use serde::{Deserialize, Serialize};

use super::numbering_extractor::NumberingExtractor;
use super::sort::EpisodeSortRule;
use super::title_extractor::TitleExtractor;

/// Static group definition within a playlist.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDef {
    pub id: String,
    pub display_name: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub pattern: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub display: Option<GroupDefDisplay>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_list: Option<GroupDefEpisodeList>,

    /// Accepts legacy `episodeExtractor` key for v3 backward compatibility.
    #[serde(skip_serializing_if = "Option::is_none", alias = "episodeExtractor")]
    pub numbering_extractor: Option<NumberingExtractor>,
}

/// Per-group display overrides for the group card.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefDisplay {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_date_range: Option<bool>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub year_binding: Option<String>,
}

/// Per-group episode list overrides.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefEpisodeList {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_year_headers: Option<bool>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<EpisodeSortRule>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,
}
