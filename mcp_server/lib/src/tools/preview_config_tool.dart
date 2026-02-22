import 'package:sp_shared/sp_shared.dart';

import 'tool_definition.dart';

/// Previews how a config resolves episodes from a feed.
///
/// Fetches the feed locally, parses episodes, and runs the
/// resolver chain to produce a preview grouping.
const previewConfigTool = ToolDefinition(
  name: 'preview_config',
  description: 'Preview how a config resolves episodes from a feed',
  inputSchema: {
    'type': 'object',
    'properties': {
      'config': {
        'type': 'object',
        'description': 'The SmartPlaylist config to preview',
      },
      'feedUrl': {
        'type': 'string',
        'description': 'The RSS feed URL to fetch episodes from',
      },
    },
    'required': ['config', 'feedUrl'],
  },
);

/// Executes the preview_config tool.
///
/// Throws [ArgumentError] if the required parameters are missing.
Future<Map<String, dynamic>> executePreviewConfig(
  DiskFeedCacheService feedService,
  Map<String, dynamic> arguments,
) async {
  final config = arguments['config'];
  if (config is! Map<String, dynamic>) {
    throw ArgumentError('Missing or invalid required parameter: config');
  }
  final feedUrl = arguments['feedUrl'] as String?;
  if (feedUrl == null || feedUrl.isEmpty) {
    throw ArgumentError('Missing required parameter: feedUrl');
  }

  final patternConfig = SmartPlaylistPatternConfig.fromJson(config);
  final episodeMaps = await feedService.fetchFeed(feedUrl);
  final episodes = episodeMaps.map(_parseEpisode).toList();

  final resolvers = <SmartPlaylistResolver>[
    RssMetadataResolver(),
    CategoryResolver(),
    YearResolver(),
    TitleAppearanceOrderResolver(),
  ];
  final service = SmartPlaylistResolverService(
    resolvers: resolvers,
    patterns: [patternConfig],
  );
  final result = service.resolveForPreview(
    podcastGuid: patternConfig.podcastGuid,
    feedUrl: patternConfig.feedUrls?.firstOrNull ?? feedUrl,
    episodes: episodes,
  );

  if (result == null) {
    return {'playlists': <Object>[], 'ungrouped': <int>[], 'resolverType': null};
  }

  return {
    'playlists': result.playlistResults.map((pr) => {
      'id': pr.playlist.id,
      'displayName': pr.playlist.displayName,
      'episodeCount': pr.playlist.episodeCount,
    }).toList(),
    'ungrouped': result.ungroupedEpisodeIds,
    'resolverType': result.resolverType,
  };
}

/// Parses an episode map (from DiskFeedCacheService) into
/// a [SimpleEpisodeData] for use with the resolver chain.
SimpleEpisodeData _parseEpisode(Map<String, dynamic> map) {
  return SimpleEpisodeData(
    id: map['id'] as int,
    title: map['title'] as String? ?? '',
    description: map['description'] as String?,
    seasonNumber: map['seasonNumber'] as int?,
    episodeNumber: map['episodeNumber'] as int?,
    publishedAt: _parseDateTime(map['publishedAt']),
    imageUrl: map['imageUrl'] as String?,
  );
}

DateTime? _parseDateTime(Object? value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}
