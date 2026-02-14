import 'smart_playlist_definition.dart';

/// Top-level pattern configuration that matches a podcast and
/// provides its playlist definitions.
final class SmartPlaylistPatternConfig {
  const SmartPlaylistPatternConfig({
    required this.id,
    this.podcastGuid,
    this.feedUrls,
    this.yearGroupedEpisodes = false,
    required this.playlists,
  });

  /// Creates a config from JSON.
  factory SmartPlaylistPatternConfig.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistPatternConfig(
      id: json['id'] as String,
      podcastGuid: json['podcastGuid'] as String?,
      feedUrls: (json['feedUrls'] as List<dynamic>?)?.cast<String>(),
      yearGroupedEpisodes: (json['yearGroupedEpisodes'] as bool?) ?? false,
      playlists: (json['playlists'] as List<dynamic>)
          .map(
            (p) => SmartPlaylistDefinition.fromJson(p as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Unique identifier for this pattern config.
  final String id;

  /// Podcast GUID for exact matching.
  final String? podcastGuid;

  /// Exact feed URLs for matching.
  final List<String>? feedUrls;

  /// Whether episodes should be grouped by year.
  final bool yearGroupedEpisodes;

  /// Playlist definitions for this podcast.
  final List<SmartPlaylistDefinition> playlists;

  /// Returns true if this config matches the given podcast.
  bool matchesPodcast(String? guid, String feedUrl) {
    if (podcastGuid != null && guid == podcastGuid) return true;
    if (feedUrls != null && feedUrls!.contains(feedUrl)) return true;
    return false;
  }

  /// Converts to JSON representation.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (podcastGuid != null) 'podcastGuid': podcastGuid,
      if (feedUrls != null) 'feedUrls': feedUrls,
      if (yearGroupedEpisodes) 'yearGroupedEpisodes': yearGroupedEpisodes,
      'playlists': playlists.map((p) => p.toJson()).toList(),
    };
  }
}
