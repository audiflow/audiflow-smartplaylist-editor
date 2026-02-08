/// Static group definition within a playlist.
///
/// Groups with a [pattern] match episodes by title regex.
/// Groups without a pattern act as fallback (catch-all).
final class SmartPlaylistGroupDef {
  const SmartPlaylistGroupDef({
    required this.id,
    required this.displayName,
    this.pattern,
    this.episodeYearHeaders,
    this.showDateRange,
  });

  /// Creates a group definition from JSON configuration.
  factory SmartPlaylistGroupDef.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistGroupDef(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      pattern: json['pattern'] as String?,
      episodeYearHeaders: json['episodeYearHeaders'] as bool?,
      showDateRange: json['showDateRange'] as bool?,
    );
  }

  /// Unique identifier for this group within the playlist.
  final String id;

  /// Human-readable name for display.
  final String displayName;

  /// Regex pattern to match episode titles.
  ///
  /// When null, this group acts as a catch-all fallback.
  final String? pattern;

  /// Per-group override for episode year headers.
  ///
  /// When null, inherits the playlist-level setting.
  final bool? episodeYearHeaders;

  /// Per-group override for showing date range and duration.
  ///
  /// When null, inherits the playlist-level setting.
  final bool? showDateRange;

  /// Converts to JSON representation.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      if (pattern != null) 'pattern': pattern,
      if (episodeYearHeaders != null) 'episodeYearHeaders': episodeYearHeaders,
      if (showDateRange != null) 'showDateRange': showDateRange,
    };
  }
}
