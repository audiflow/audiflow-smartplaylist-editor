import 'smart_playlist_episode_extractor.dart';
import 'smart_playlist_sort.dart';
import 'smart_playlist_title_extractor.dart';

/// Configuration for how to group episodes into smart playlists
/// for a specific podcast.
final class SmartPlaylistPattern {
  const SmartPlaylistPattern({
    required this.id,
    this.podcastGuid,
    this.feedUrls,
    required this.resolverType,
    required this.config,
    this.priority = 0,
    this.customSort,
    this.titleExtractor,
    this.smartPlaylistEpisodeExtractor,
    this.yearGroupedEpisodes = false,
  });

  /// Unique identifier for this pattern.
  final String id;

  /// Match by podcast GUID (checked first).
  final String? podcastGuid;

  /// Exact feed URLs for matching.
  final List<String>? feedUrls;

  /// Which resolver type to use (e.g., "rss", "title_appearance").
  final String resolverType;

  /// Resolver-specific configuration.
  final Map<String, dynamic> config;

  /// Priority for pattern ordering (higher = checked first).
  final int priority;

  /// Custom default sort for smart playlists from this pattern.
  final SmartPlaylistSortSpec? customSort;

  /// Custom title extractor for generating smart playlist display
  /// names.
  ///
  /// When provided, overrides the default title generation logic.
  final SmartPlaylistTitleExtractor? titleExtractor;

  /// Extracts both playlist and episode numbers from episode title
  /// prefix.
  ///
  /// When provided, extracted values can override RSS metadata.
  /// Useful for podcasts with unreliable RSS metadata but reliable
  /// title encoding.
  final SmartPlaylistEpisodeExtractor? smartPlaylistEpisodeExtractor;

  /// Whether the all-episodes view groups by year.
  final bool yearGroupedEpisodes;

  /// Returns true if this pattern matches the given podcast.
  bool matchesPodcast(String? guid, String feedUrl) {
    if (podcastGuid != null && guid == podcastGuid) return true;
    if (feedUrls != null && feedUrls!.contains(feedUrl)) return true;
    return false;
  }
}
