use serde::{Deserialize, Serialize};

/// Fields by which smart playlist groups can be sorted.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SortField {
    PlaylistNumber,
    NewestEpisodeDate,
    Alphabetical,
}

/// Fields by which episodes can be sorted within a group.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum EpisodeSortField {
    PublishedAt,
    EpisodeNumber,
    Title,
}

/// Sort direction.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SortOrder {
    Ascending,
    Descending,
}

/// A single sort rule for ordering groups.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SortRule {
    pub field: SortField,
    pub order: SortOrder,
}

/// A sort rule for ordering episodes within a group or playlist.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EpisodeSortRule {
    pub field: EpisodeSortField,
    pub order: SortOrder,
}
