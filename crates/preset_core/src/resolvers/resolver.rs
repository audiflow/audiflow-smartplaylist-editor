use crate::models::{EpisodeData, Grouping, PlaylistDefinition, SortRule};

/// Interface for smart playlist resolvers that group episodes into
/// smart playlists.
pub trait Resolver {
    /// Unique identifier for this resolver type.
    fn resolver_type(&self) -> &str;

    /// Default sort rule for smart playlists produced by this resolver.
    fn default_sort(&self) -> SortRule;

    /// Attempts to group episodes into smart playlists.
    ///
    /// Returns None if this resolver cannot handle the given
    /// episodes. The `definition` provides resolver-specific
    /// configuration when available.
    fn resolve(
        &self,
        episodes: &[&dyn EpisodeData],
        definition: Option<&PlaylistDefinition>,
    ) -> Option<Grouping>;
}
