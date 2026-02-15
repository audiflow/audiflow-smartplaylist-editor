import 'episode_number_extractor.dart';
import 'smart_playlist_episode_extractor.dart';
import 'smart_playlist_group_def.dart';
import 'smart_playlist_sort.dart';
import 'smart_playlist_title_extractor.dart';

/// Unified per-playlist definition with all fields strongly typed.
final class SmartPlaylistDefinition {
  const SmartPlaylistDefinition({
    required this.id,
    required this.displayName,
    required this.resolverType,
    this.priority = 0,
    this.contentType,
    this.yearHeaderMode,
    this.episodeYearHeaders = false,
    this.titleFilter,
    this.excludeFilter,
    this.requireFilter,
    this.nullSeasonGroupKey,
    this.groups,
    this.customSort,
    this.titleExtractor,
    this.episodeNumberExtractor,
    this.showDateRange = false,
    this.smartPlaylistEpisodeExtractor,
  });

  static String? _nullIfEmpty(Object? value) {
    if (value is! String) return null;
    return value.isEmpty ? null : value;
  }

  /// Creates a definition from JSON configuration.
  factory SmartPlaylistDefinition.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistDefinition(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      resolverType: json['resolverType'] as String,
      priority: (json['priority'] as int?) ?? 0,
      contentType: _nullIfEmpty(json['contentType']),
      yearHeaderMode: _nullIfEmpty(json['yearHeaderMode']),
      episodeYearHeaders: (json['episodeYearHeaders'] as bool?) ?? false,
      showDateRange: (json['showDateRange'] as bool?) ?? false,
      titleFilter: _nullIfEmpty(json['titleFilter']),
      excludeFilter: _nullIfEmpty(json['excludeFilter']),
      requireFilter: _nullIfEmpty(json['requireFilter']),
      nullSeasonGroupKey: json['nullSeasonGroupKey'] as int?,
      groups: (json['groups'] as List<dynamic>?)
          ?.map(
            (g) => SmartPlaylistGroupDef.fromJson(g as Map<String, dynamic>),
          )
          .toList(),
      customSort: json['customSort'] != null
          ? SmartPlaylistSortSpec.fromJson(
              json['customSort'] as Map<String, dynamic>,
            )
          : null,
      titleExtractor: json['titleExtractor'] != null
          ? SmartPlaylistTitleExtractor.fromJson(
              json['titleExtractor'] as Map<String, dynamic>,
            )
          : null,
      episodeNumberExtractor: json['episodeNumberExtractor'] != null
          ? EpisodeNumberExtractor.fromJson(
              json['episodeNumberExtractor'] as Map<String, dynamic>,
            )
          : null,
      smartPlaylistEpisodeExtractor:
          json['smartPlaylistEpisodeExtractor'] != null
          ? SmartPlaylistEpisodeExtractor.fromJson(
              json['smartPlaylistEpisodeExtractor'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Unique identifier for this playlist definition.
  final String id;

  /// Human-readable name for display.
  final String displayName;

  /// Type of resolver to use for episode grouping.
  final String resolverType;

  /// Sort priority among sibling playlists (default: 0).
  final int priority;

  /// Content type hint (e.g., "bonus", "main").
  final String? contentType;

  /// How to group episodes by year ("publish", "season", etc.).
  final String? yearHeaderMode;

  /// Whether to show year headers within episode lists.
  final bool episodeYearHeaders;

  /// Regex pattern to filter episode titles (include match).
  final String? titleFilter;

  /// Regex pattern to exclude episodes by title.
  final String? excludeFilter;

  /// Regex pattern that episodes must match to be included.
  final String? requireFilter;

  /// Group key to assign to episodes with null season number.
  final int? nullSeasonGroupKey;

  /// Static group definitions for category-based grouping.
  final List<SmartPlaylistGroupDef>? groups;

  /// Custom sort specification.
  final SmartPlaylistSortSpec? customSort;

  /// Configuration for extracting playlist display names.
  final SmartPlaylistTitleExtractor? titleExtractor;

  /// Configuration for extracting episode numbers.
  final EpisodeNumberExtractor? episodeNumberExtractor;

  /// Whether group cards should display a date range.
  final bool showDateRange;

  /// Configuration for extracting both season and episode numbers.
  final SmartPlaylistEpisodeExtractor? smartPlaylistEpisodeExtractor;

  /// Converts to JSON representation.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'resolverType': resolverType,
      if (priority != 0) 'priority': priority,
      if (contentType != null) 'contentType': contentType,
      if (yearHeaderMode != null) 'yearHeaderMode': yearHeaderMode,
      if (episodeYearHeaders) 'episodeYearHeaders': episodeYearHeaders,
      if (showDateRange) 'showDateRange': showDateRange,
      if (titleFilter != null) 'titleFilter': titleFilter,
      if (excludeFilter != null) 'excludeFilter': excludeFilter,
      if (requireFilter != null) 'requireFilter': requireFilter,
      if (nullSeasonGroupKey != null) 'nullSeasonGroupKey': nullSeasonGroupKey,
      if (groups != null) 'groups': groups!.map((g) => g.toJson()).toList(),
      if (customSort != null) 'customSort': customSort!.toJson(),
      if (titleExtractor != null) 'titleExtractor': titleExtractor!.toJson(),
      if (episodeNumberExtractor != null)
        'episodeNumberExtractor': episodeNumberExtractor!.toJson(),
      if (smartPlaylistEpisodeExtractor != null)
        'smartPlaylistEpisodeExtractor': smartPlaylistEpisodeExtractor!
            .toJson(),
    };
  }
}
