/// Whether a smart playlist directly contains episodes or groups.
enum PlaylistStructure {
  /// Playlist directly contains an episode list.
  split,

  /// Playlist contains groups; tapping a group opens its episode list.
  grouped,
}

/// How year headers are applied to groups or episodes.
enum YearBinding {
  /// No year headers.
  none,

  /// Group is pinned to its first episode's year. Group appears once.
  pinToYear,

  /// Group appears under each year it has episodes in.
  /// Tapping shows only that year's episodes.
  splitByYear,
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
    this.showYearHeaders,
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

  /// Per-group override of the parent playlist's yearBinding.
  final YearBinding? yearOverride;

  /// Per-group override of the parent playlist's showYearHeaders.
  ///
  /// When null, inherits the playlist-level setting.
  final bool? showYearHeaders;

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
    YearBinding? yearOverride,
    bool? showYearHeaders,
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
      showYearHeaders: showYearHeaders ?? this.showYearHeaders,
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
    this.playlistStructure = PlaylistStructure.split,
    this.yearBinding = YearBinding.none,
    this.showYearHeaders = false,
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
  final PlaylistStructure playlistStructure;

  /// How year headers are applied in the group list view.
  final YearBinding yearBinding;

  /// Whether episodes within groups show year headers.
  final bool showYearHeaders;

  /// Whether group cards should display a date range.
  final bool showDateRange;

  /// Groups within this playlist (when playlistStructure == grouped).
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
    PlaylistStructure? playlistStructure,
    YearBinding? yearBinding,
    bool? showYearHeaders,
    bool? showDateRange,
    List<SmartPlaylistGroup>? groups,
  }) {
    return SmartPlaylist(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      sortKey: sortKey ?? this.sortKey,
      episodeIds: episodeIds ?? this.episodeIds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      playlistStructure: playlistStructure ?? this.playlistStructure,
      yearBinding: yearBinding ?? this.yearBinding,
      showYearHeaders: showYearHeaders ?? this.showYearHeaders,
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
