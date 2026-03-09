use std::collections::HashMap;

use crate::models::{PatternConfig, PatternMeta, PlaylistDefinition};

/// Assembles a full PatternConfig from pattern metadata and playlist
/// definitions.
pub struct ConfigAssembler;

impl ConfigAssembler {
    /// Combines a PatternMeta with its playlist definitions into the
    /// unified config that resolvers expect.
    ///
    /// Playlists are ordered according to meta.playlists. Any playlists
    /// not listed in meta are appended at the end.
    pub fn assemble(meta: &PatternMeta, playlists: &[PlaylistDefinition]) -> PatternConfig {
        let mut playlist_map: HashMap<&str, &PlaylistDefinition> =
            playlists.iter().map(|p| (p.id.as_str(), p)).collect();

        let mut ordered: Vec<PlaylistDefinition> = Vec::new();
        for id in &meta.playlists {
            if let Some(playlist) = playlist_map.remove(id.as_str()) {
                ordered.push(playlist.clone());
            }
        }
        // Append any remaining playlists not in meta order
        for playlist in playlist_map.into_values() {
            ordered.push(playlist.clone());
        }

        PatternConfig {
            id: meta.id.clone(),
            podcast_guid: meta.podcast_guid.clone(),
            feed_urls: if meta.feed_urls.is_empty() {
                None
            } else {
                Some(meta.feed_urls.clone())
            },
            year_grouped_episodes: meta.year_grouped_episodes,
            playlists: ordered,
        }
    }
}
