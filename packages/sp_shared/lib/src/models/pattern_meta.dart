import 'dart:convert';

/// Pattern-level meta.json from a pattern directory.
///
/// Contains feed matching rules and ordered playlist IDs.
final class PatternMeta {
  const PatternMeta({
    required this.version,
    required this.id,
    this.podcastGuid,
    required this.feedUrls,
    this.yearGroupedEpisodes = false,
    required this.playlists,
  });

  factory PatternMeta.fromJson(Map<String, dynamic> json) {
    return PatternMeta(
      version: json['version'] as int,
      id: json['id'] as String,
      podcastGuid: json['podcastGuid'] as String?,
      feedUrls: (json['feedUrls'] as List<dynamic>).cast<String>(),
      yearGroupedEpisodes: (json['yearGroupedEpisodes'] as bool?) ?? false,
      playlists: (json['playlists'] as List<dynamic>).cast<String>(),
    );
  }

  /// Parses a JSON string into a PatternMeta.
  static PatternMeta parseJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    return PatternMeta.fromJson(data);
  }

  final int version;
  final String id;
  final String? podcastGuid;
  final List<String> feedUrls;
  final bool yearGroupedEpisodes;

  /// Ordered list of playlist IDs. Each corresponds to
  /// `playlists/{id}.json` in the pattern directory.
  final List<String> playlists;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'id': id,
      if (podcastGuid != null) 'podcastGuid': podcastGuid,
      'feedUrls': feedUrls,
      if (yearGroupedEpisodes) 'yearGroupedEpisodes': yearGroupedEpisodes,
      'playlists': playlists,
    };
  }
}
