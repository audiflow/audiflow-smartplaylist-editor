/** Field descriptions for form tooltips, sourced from SmartPlaylistSchema. */
export const FIELD_HINTS = {
  // Pattern-level fields
  patternId: 'Unique identifier for this pattern config.',
  podcastGuid: 'Podcast GUID for exact matching. Checked before feedUrls.',
  feedUrls: 'Exact feed URLs for matching.',
  yearGroupedEpisodes: 'Whether the all-episodes view groups by year.',

  // Playlist-level fields
  playlistId: 'Unique identifier for this playlist definition.',
  displayName: 'Human-readable name for display.',
  resolverType: 'Type of resolver to use for episode grouping.',
  priority: 'Sort priority among sibling playlists.',
  titleFilter: 'Regex pattern to filter episode titles (include).',
  excludeFilter: 'Regex pattern to exclude episodes by title.',
  requireFilter: 'Regex pattern that episodes must match.',
  episodeYearHeaders: 'Whether to show year headers within episode lists.',
  showDateRange: 'Whether group cards display a date range.',
} as const;
