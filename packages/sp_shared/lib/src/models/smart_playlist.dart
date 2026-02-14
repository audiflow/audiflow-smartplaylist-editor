/// Whether a smart playlist directly contains episodes or groups.
enum SmartPlaylistContentType {
  /// Playlist directly contains an episode list.
  episodes,

  /// Playlist contains groups; tapping a group opens its episode list.
  groups,
}

/// How year headers are applied to groups or episodes.
enum YearHeaderMode {
  /// No year headers.
  none,

  /// Group's year = first episode's publishedAt year. Group appears once.
  firstEpisode,

  /// Group appears under each year it has episodes in.
  /// Tapping shows only that year's episodes.
  perEpisode,
}

/// A group within a smart playlist containing episodes.
final class SmartPlaylistGroup {
  const SmartPlaylistGroup({
    required this.id,
    required this.displayName,
    required this.episodeIds,
    this.sortKey = 0,
    this.thumbnailUrl,
    this.yearOverride,
    this.episodeYearHeaders,
    this.showDateRange = false,
    this.earliestDate,
    this.latestDate,
    this.totalDurationMs,
  });

  /// Unique identifier within the parent playlist.
  final String id;

  /// Display name for the group.
  final String displayName;

  /// Sort key for ordering groups.
  final int sortKey;

  /// Episode IDs belonging to this group.
  final List<int> episodeIds;

  /// Thumbnail URL from the latest episode in this group.
  final String? thumbnailUrl;

  /// Per-group override of the parent playlist's yearHeaderMode.
  final YearHeaderMode? yearOverride;

  /// Per-group override of the parent playlist's episodeYearHeaders.
  ///
  /// When null, inherits the playlist-level setting.
  final bool? episodeYearHeaders;

  /// Whether this group shows date range and duration metadata.
  final bool showDateRange;

  /// Earliest episode publish date in this group.
  final DateTime? earliestDate;

  /// Latest episode publish date in this group.
  final DateTime? latestDate;

  /// Total duration of all episodes in milliseconds.
  final int? totalDurationMs;

  /// Number of episodes in this group.
  int get episodeCount => episodeIds.length;

  /// Creates a copy with optional field overrides.
  SmartPlaylistGroup copyWith({
    String? id,
    String? displayName,
    List<int>? episodeIds,
    int? sortKey,
    String? thumbnailUrl,
    YearHeaderMode? yearOverride,
    bool? episodeYearHeaders,
    bool? showDateRange,
    DateTime? earliestDate,
    DateTime? latestDate,
    int? totalDurationMs,
  }) {
    return SmartPlaylistGroup(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      episodeIds: episodeIds ?? this.episodeIds,
      sortKey: sortKey ?? this.sortKey,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      yearOverride: yearOverride ?? this.yearOverride,
      episodeYearHeaders: episodeYearHeaders ?? this.episodeYearHeaders,
      showDateRange: showDateRange ?? this.showDateRange,
      earliestDate: earliestDate ?? this.earliestDate,
      latestDate: latestDate ?? this.latestDate,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
    );
  }
}

/// Represents a smart playlist grouping of episodes within a podcast.
final class SmartPlaylist {
  const SmartPlaylist({
    required this.id,
    required this.displayName,
    required this.sortKey,
    required this.episodeIds,
    this.thumbnailUrl,
    this.contentType = SmartPlaylistContentType.episodes,
    this.yearHeaderMode = YearHeaderMode.none,
    this.episodeYearHeaders = false,
    this.showDateRange = false,
    this.groups,
  });

  /// Unique identifier within podcast.
  final String id;

  /// Display name.
  final String displayName;

  /// Sort key for ordering smart playlists.
  final int sortKey;

  /// Episode IDs belonging to this smart playlist.
  final List<int> episodeIds;

  /// Thumbnail URL from the latest episode in this smart playlist.
  final String? thumbnailUrl;

  /// Whether this playlist contains episodes directly or groups.
  final SmartPlaylistContentType contentType;

  /// How year headers are applied in the group list view.
  final YearHeaderMode yearHeaderMode;

  /// Whether episodes within groups show year headers.
  final bool episodeYearHeaders;

  /// Whether group cards should display a date range.
  final bool showDateRange;

  /// Groups within this playlist (when contentType == groups).
  final List<SmartPlaylistGroup>? groups;

  /// Number of episodes in this smart playlist.
  int get episodeCount => episodeIds.length;

  /// Creates a copy with optional field overrides.
  SmartPlaylist copyWith({
    String? id,
    String? displayName,
    int? sortKey,
    List<int>? episodeIds,
    String? thumbnailUrl,
    SmartPlaylistContentType? contentType,
    YearHeaderMode? yearHeaderMode,
    bool? episodeYearHeaders,
    bool? showDateRange,
    List<SmartPlaylistGroup>? groups,
  }) {
    return SmartPlaylist(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      sortKey: sortKey ?? this.sortKey,
      episodeIds: episodeIds ?? this.episodeIds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      contentType: contentType ?? this.contentType,
      yearHeaderMode: yearHeaderMode ?? this.yearHeaderMode,
      episodeYearHeaders: episodeYearHeaders ?? this.episodeYearHeaders,
      showDateRange: showDateRange ?? this.showDateRange,
      groups: groups ?? this.groups,
    );
  }
}

/// Result from a smart playlist resolver containing grouped playlists.
final class SmartPlaylistGrouping {
  const SmartPlaylistGrouping({
    required this.playlists,
    required this.ungroupedEpisodeIds,
    required this.resolverType,
  });

  /// Smart playlists detected by the resolver.
  final List<SmartPlaylist> playlists;

  /// Episode IDs that could not be grouped.
  final List<int> ungroupedEpisodeIds;

  /// Resolver type that produced this grouping.
  final String resolverType;

  /// True if there are ungrouped episodes.
  bool get hasUngrouped => ungroupedEpisodeIds.isNotEmpty;
}
