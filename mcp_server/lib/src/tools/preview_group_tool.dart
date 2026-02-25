import 'package:sp_shared/sp_shared.dart';

import 'tool_definition.dart';

/// Previews episodes within a specific group of a playlist.
///
/// Runs the resolver chain like `preview_config`, then drills into
/// the requested playlist and group to return episode-level detail.
const previewGroupTool = ToolDefinition(
  name: 'preview_group',
  description:
      'Preview episodes in a specific group within a playlist. '
      'Returns episode titles and dates for analysis.',
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
      'playlistId': {
        'type': 'string',
        'description': 'The playlist definition ID to look in',
      },
      'groupId': {
        'type': 'string',
        'description': 'The group ID within the playlist',
      },
    },
    'required': ['config', 'feedUrl', 'playlistId', 'groupId'],
  },
);

/// Executes the preview_group tool.
///
/// Throws [ArgumentError] if required parameters are missing or
/// the specified playlist/group is not found.
Future<Map<String, dynamic>> executePreviewGroup(
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
  final playlistId = arguments['playlistId'] as String?;
  if (playlistId == null || playlistId.isEmpty) {
    throw ArgumentError('Missing required parameter: playlistId');
  }
  final groupId = arguments['groupId'] as String?;
  if (groupId == null || groupId.isEmpty) {
    throw ArgumentError('Missing required parameter: groupId');
  }

  final patternConfig = SmartPlaylistPatternConfig.fromJson(config);
  final episodeMaps = await feedService.fetchFeed(feedUrl);
  final episodes = episodeMaps.map(_parseEpisode).toList();
  final episodeById = {for (final e in episodes) e.id: e};

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
    throw ArgumentError('No resolver matched the config');
  }

  // Find the requested playlist
  final playlistResult = result.playlistResults
      .where((pr) => pr.definitionId == playlistId)
      .firstOrNull;
  if (playlistResult == null) {
    final available = result.playlistResults
        .map((pr) => pr.definitionId)
        .toList();
    throw ArgumentError(
      'Playlist "$playlistId" not found. Available: $available',
    );
  }

  // Find the requested group
  final groups = playlistResult.playlist.groups;
  if (groups == null || groups.isEmpty) {
    throw ArgumentError(
      'Playlist "$playlistId" has no groups (contentType may be "episodes")',
    );
  }

  final group = groups.where((g) => g.id == groupId).firstOrNull;
  if (group == null) {
    final available = groups.map((g) => g.id).toList();
    throw ArgumentError(
      'Group "$groupId" not found in playlist "$playlistId". '
      'Available: $available',
    );
  }

  // Build episode detail for the group
  final episodeDetails = group.episodeIds.map((id) {
    final ep = episodeById[id];
    return {
      'id': id,
      'title': ep?.title ?? '',
      'publishedAt': ep?.publishedAt?.toIso8601String(),
    };
  }).toList();

  return {
    'group': {
      'id': group.id,
      'displayName': group.displayName,
      'episodeCount': group.episodeCount,
    },
    'episodes': episodeDetails,
  };
}

/// Parses an episode map into a [SimpleEpisodeData].
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
