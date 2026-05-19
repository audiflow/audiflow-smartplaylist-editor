use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use super::playlist::Playlist;

/// Preview-specific wrapper for a single playlist definition's
/// resolution result.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaylistPreviewResult {
    /// The playlist definition ID this result corresponds to.
    pub definition_id: String,

    /// The resolved playlist (groups, episodes, etc).
    pub playlist: Playlist,

    /// Episodes that matched this definition's filters but were
    /// already claimed by a higher-priority definition.
    /// Maps episode ID to the claiming definition's ID.
    pub claimed_by_others: HashMap<i64, String>,
}

/// Preview-specific grouping that includes per-playlist
/// claimed-episode tracking.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PreviewGrouping {
    pub playlist_results: Vec<PlaylistPreviewResult>,
    pub ungrouped_episode_ids: Vec<i64>,
    pub resolver_type: String,
}
