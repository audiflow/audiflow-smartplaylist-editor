import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sp_shared/sp_shared.dart';

import '../middleware/api_key_middleware.dart';
import '../services/api_key_service.dart';
import '../services/config_repository.dart';
import '../services/feed_cache_service.dart';
import '../services/jwt_service.dart';

/// Registers config routes under `/api/configs`.
///
/// All routes require unified authentication
/// (JWT or API key).
Router configRouter({
  required ConfigRepository configRepository,
  required FeedCacheService feedCacheService,
  required JwtService jwtService,
  required ApiKeyService apiKeyService,
}) {
  final router = Router();

  final auth = unifiedAuthMiddleware(
    jwtService: jwtService,
    apiKeyService: apiKeyService,
  );

  // Legacy endpoints (adapted for split backend)

  // GET /api/configs
  final listHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handleList(r, configRepository));
  router.get('/api/configs', listHandler);

  // GET /api/configs/patterns/<id>/assembled
  // Must be registered before /api/configs/<id> to avoid
  // path conflicts.
  final assembledHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handleAssembled(r, configRepository));
  router.get('/api/configs/patterns/<id>/assembled', assembledHandler);

  // GET /api/configs/patterns/<id>/playlists/<pid>
  final playlistHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handlePlaylist(r, configRepository));
  router.get('/api/configs/patterns/<id>/playlists/<pid>', playlistHandler);

  // GET /api/configs/patterns/<id>
  final patternMetaHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handlePatternMeta(r, configRepository));
  router.get('/api/configs/patterns/<id>', patternMetaHandler);

  // GET /api/configs/patterns
  final patternsHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handlePatterns(r, configRepository));
  router.get('/api/configs/patterns', patternsHandler);

  // GET /api/configs/<id> (legacy: returns assembled config)
  final getHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handleGet(r, configRepository));
  router.get('/api/configs/<id>', getHandler);

  // POST /api/configs/validate
  final validateHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handleValidate(r));
  router.post('/api/configs/validate', validateHandler);

  // POST /api/configs/preview
  final previewHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handlePreview(r, feedCacheService));
  router.post('/api/configs/preview', previewHandler);

  return router;
}

/// GET /api/configs -- legacy list endpoint.
///
/// Returns pattern summaries wrapped in {configs: [...]}.
Future<Response> _handleList(
  Request request,
  ConfigRepository configRepository,
) async {
  try {
    final patterns = await configRepository.listPatterns();
    return Response.ok(
      jsonEncode({'configs': patterns.map((p) => p.toJson()).toList()}),
      headers: _jsonHeaders,
    );
  } on Object catch (e) {
    return Response(
      502,
      body: jsonEncode({'error': 'Failed to fetch configs: $e'}),
      headers: _jsonHeaders,
    );
  }
}

/// GET /api/configs/patterns -- returns pattern summaries.
Future<Response> _handlePatterns(
  Request request,
  ConfigRepository configRepository,
) async {
  try {
    final patterns = await configRepository.listPatterns();
    return Response.ok(
      jsonEncode(patterns.map((p) => p.toJson()).toList()),
      headers: _jsonHeaders,
    );
  } on Object catch (e) {
    return Response(
      502,
      body: jsonEncode({'error': 'Failed to fetch patterns: $e'}),
      headers: _jsonHeaders,
    );
  }
}

/// GET /api/configs/patterns/<id> -- returns pattern metadata.
Future<Response> _handlePatternMeta(
  Request request,
  ConfigRepository configRepository,
) async {
  final id = request.params['id'];
  if (id == null || id.isEmpty) {
    return _error(400, 'Missing pattern ID');
  }

  try {
    final meta = await configRepository.getPatternMeta(id);
    return Response.ok(jsonEncode(meta.toJson()), headers: _jsonHeaders);
  } on Object catch (e) {
    return Response(
      502,
      body: jsonEncode({'error': 'Failed to fetch pattern meta: $e'}),
      headers: _jsonHeaders,
    );
  }
}

/// GET /api/configs/patterns/<id>/playlists/<pid>
Future<Response> _handlePlaylist(
  Request request,
  ConfigRepository configRepository,
) async {
  final id = request.params['id'];
  final pid = request.params['pid'];
  if (id == null || id.isEmpty) {
    return _error(400, 'Missing pattern ID');
  }
  if (pid == null || pid.isEmpty) {
    return _error(400, 'Missing playlist ID');
  }

  try {
    final playlist = await configRepository.getPlaylist(id, pid);
    return Response.ok(jsonEncode(playlist.toJson()), headers: _jsonHeaders);
  } on Object catch (e) {
    return Response(
      502,
      body: jsonEncode({'error': 'Failed to fetch playlist: $e'}),
      headers: _jsonHeaders,
    );
  }
}

/// GET /api/configs/patterns/<id>/assembled
Future<Response> _handleAssembled(
  Request request,
  ConfigRepository configRepository,
) async {
  final id = request.params['id'];
  if (id == null || id.isEmpty) {
    return _error(400, 'Missing pattern ID');
  }

  try {
    final config = await configRepository.assembleConfig(id);
    return Response.ok(jsonEncode(config.toJson()), headers: _jsonHeaders);
  } on Object catch (e) {
    return Response(
      502,
      body: jsonEncode({'error': 'Failed to assemble config: $e'}),
      headers: _jsonHeaders,
    );
  }
}

/// GET /api/configs/<id> -- legacy: returns assembled config.
Future<Response> _handleGet(
  Request request,
  ConfigRepository configRepository,
) async {
  final id = request.params['id'];
  if (id == null || id.isEmpty) {
    return Response(
      400,
      body: jsonEncode({'error': 'Missing config ID'}),
      headers: _jsonHeaders,
    );
  }

  try {
    final config = await configRepository.assembleConfig(id);
    return Response.ok(jsonEncode(config.toJson()), headers: _jsonHeaders);
  } on Object catch (e) {
    return Response(
      502,
      body: jsonEncode({'error': 'Failed to fetch config: $e'}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _handleValidate(Request request) async {
  final body = await request.readAsString();
  if (body.isEmpty) {
    return Response(
      400,
      body: jsonEncode({'error': 'Request body is empty'}),
      headers: _jsonHeaders,
    );
  }

  final errors = SmartPlaylistSchema.validate(body);
  return Response.ok(
    jsonEncode({'valid': errors.isEmpty, 'errors': errors}),
    headers: _jsonHeaders,
  );
}

Future<Response> _handlePreview(
  Request request,
  FeedCacheService feedCacheService,
) async {
  final body = await request.readAsString();
  if (body.isEmpty) {
    return Response(
      400,
      body: jsonEncode({'error': 'Request body is empty'}),
      headers: _jsonHeaders,
    );
  }

  final Object? parsed;
  try {
    parsed = jsonDecode(body);
  } on FormatException {
    return Response(
      400,
      body: jsonEncode({'error': 'Invalid JSON'}),
      headers: _jsonHeaders,
    );
  }

  if (parsed is! Map<String, dynamic>) {
    return Response(
      400,
      body: jsonEncode({'error': 'Request body must be a JSON object'}),
      headers: _jsonHeaders,
    );
  }

  final configJson = parsed['config'];
  final feedUrl = parsed['feedUrl'];

  if (configJson is! Map<String, dynamic>) {
    return _error(400, 'Missing or invalid "config" field');
  }
  if (feedUrl is! String || feedUrl.isEmpty) {
    return _error(400, 'Missing or invalid "feedUrl" field');
  }

  try {
    final config = SmartPlaylistPatternConfig.fromJson(configJson);
    final episodeMaps = await feedCacheService.fetchFeed(feedUrl);
    final episodes = episodeMaps
        .map((e) => _parseEpisode(e.cast<String, dynamic>()))
        .toList();
    final result = _runPreview(config, episodes);
    return Response.ok(jsonEncode(result), headers: _jsonHeaders);
  } on Object catch (e) {
    return Response(
      400,
      body: jsonEncode({'error': 'Preview failed: $e'}),
      headers: _jsonHeaders,
    );
  }
}

SimpleEpisodeData _parseEpisode(Map<String, dynamic> json) {
  return SimpleEpisodeData(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String?,
    seasonNumber: json['seasonNumber'] as int?,
    episodeNumber: json['episodeNumber'] as int?,
    publishedAt: _parseDateTime(json['publishedAt']),
    imageUrl: json['imageUrl'] as String?,
  );
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Applies the first available [SmartPlaylistEpisodeExtractor] from the
/// config to enrich episodes with title-derived season/episode numbers.
///
/// This matches the mobile app behavior where episodes are enriched
/// during feed sync before the resolver runs.
List<SimpleEpisodeData> _enrichEpisodes(
  SmartPlaylistPatternConfig config,
  List<SimpleEpisodeData> episodes,
) {
  final extractor = config.playlists
      .map((d) => d.smartPlaylistEpisodeExtractor)
      .nonNulls
      .firstOrNull;
  if (extractor == null) return episodes;

  return episodes.map((episode) {
    final result = extractor.extract(episode);
    if (!result.hasValues) return episode;
    return SimpleEpisodeData(
      id: episode.id,
      title: episode.title,
      description: episode.description,
      seasonNumber: result.seasonNumber ?? episode.seasonNumber,
      episodeNumber: result.episodeNumber ?? episode.episodeNumber,
      publishedAt: episode.publishedAt,
      imageUrl: episode.imageUrl,
    );
  }).toList();
}

Map<String, dynamic> _runPreview(
  SmartPlaylistPatternConfig config,
  List<SimpleEpisodeData> episodes,
) {
  final enriched = _enrichEpisodes(config, episodes);

  final resolvers = <SmartPlaylistResolver>[
    RssMetadataResolver(),
    CategoryResolver(),
    YearResolver(),
    TitleAppearanceOrderResolver(),
  ];

  final service = SmartPlaylistResolverService(
    resolvers: resolvers,
    patterns: [config],
  );

  final result = service.resolveForPreview(
    podcastGuid: config.podcastGuid,
    feedUrl: config.feedUrls?.firstOrNull ?? '',
    episodes: enriched,
  );

  if (result == null) {
    return {
      'playlists': <Map<String, dynamic>>[],
      'ungrouped': <Map<String, dynamic>>[],
      'resolverType': null,
    };
  }

  final episodeById = <int, SimpleEpisodeData>{
    for (final e in enriched) e.id: e,
  };

  // Pre-compute extracted display names per definition
  final extractedDisplayNames = <String, Map<int, String>>{};
  for (final definition in config.playlists) {
    final extractor = definition.titleExtractor;
    if (extractor == null) continue;
    final names = <int, String>{};
    for (final episode in enriched) {
      final name = extractor.extract(episode);
      if (name != null) {
        names[episode.id] = name;
      }
    }
    extractedDisplayNames[definition.id] = names;
  }

  final groupedCount = result.playlistResults.fold<int>(
    0,
    (sum, pr) => sum + pr.playlist.episodeIds.length,
  );

  return {
    'playlists': result.playlistResults
        .map(
          (pr) => _serializePreviewResult(
            pr,
            result.resolverType,
            episodeById,
            extractedDisplayNames: extractedDisplayNames[pr.definitionId],
          ),
        )
        .toList(),
    'ungrouped': result.ungroupedEpisodeIds
        .map((id) => _serializeEpisode(episodeById[id]))
        .whereType<Map<String, dynamic>>()
        .toList(),
    'resolverType': result.resolverType,
    'debug': {
      'totalEpisodes': enriched.length,
      'groupedEpisodes': groupedCount,
      'ungroupedEpisodes': result.ungroupedEpisodeIds.length,
    },
  };
}

Map<String, dynamic> _serializePlaylist(
  SmartPlaylist playlist,
  String? resolverType,
  Map<int, SimpleEpisodeData> episodeById, {
  Map<int, String>? extractedDisplayNames,
}) {
  return {
    'id': playlist.id,
    'displayName': playlist.displayName,
    'sortKey': playlist.sortKey,
    'resolverType': resolverType,
    'episodeCount': playlist.episodeCount,
    if (playlist.groups != null)
      'groups': playlist.groups!
          .map(
            (g) => _serializeGroup(
              g,
              episodeById,
              extractedDisplayNames: extractedDisplayNames,
            ),
          )
          .toList(),
  };
}

Map<String, dynamic> _serializePreviewResult(
  PlaylistPreviewResult pr,
  String? resolverType,
  Map<int, SimpleEpisodeData> episodeById, {
  Map<int, String>? extractedDisplayNames,
}) {
  final base = _serializePlaylist(
    pr.playlist,
    resolverType,
    episodeById,
    extractedDisplayNames: extractedDisplayNames,
  );

  if (pr.claimedByOthers.isNotEmpty) {
    base['claimedByOthers'] = pr.claimedByOthers.entries.map((entry) {
      final episode = episodeById[entry.key];
      return {
        if (episode != null) ...{
          'id': episode.id,
          'title': episode.title,
          'seasonNumber': episode.seasonNumber,
          'episodeNumber': episode.episodeNumber,
        },
        'claimedBy': entry.value,
      };
    }).toList();
  }

  final filterMatchedCount =
      pr.playlist.episodeIds.length + pr.claimedByOthers.length;
  base['debug'] = {
    'filterMatched': filterMatchedCount,
    'episodeCount': pr.playlist.episodeIds.length,
    'claimedByOthersCount': pr.claimedByOthers.length,
  };

  return base;
}

Map<String, dynamic> _serializeGroup(
  SmartPlaylistGroup group,
  Map<int, SimpleEpisodeData> episodeById, {
  Map<int, String>? extractedDisplayNames,
}) {
  return {
    'id': group.id,
    'displayName': group.displayName,
    'sortKey': group.sortKey,
    'episodeCount': group.episodeCount,
    'episodes': group.episodeIds
        .map(
          (id) => _serializeEpisode(
            episodeById[id],
            extractedDisplayName: extractedDisplayNames?[id],
          ),
        )
        .whereType<Map<String, dynamic>>()
        .toList(),
  };
}

Map<String, dynamic>? _serializeEpisode(
  SimpleEpisodeData? episode, {
  String? extractedDisplayName,
}) {
  if (episode == null) return null;
  return {
    'id': episode.id,
    'title': episode.title,
    if (episode.publishedAt != null)
      'publishedAt': episode.publishedAt!.toIso8601String(),
    if (episode.seasonNumber != null) 'seasonNumber': episode.seasonNumber,
    if (episode.episodeNumber != null) 'episodeNumber': episode.episodeNumber,
    if (extractedDisplayName != null)
      'extractedDisplayName': extractedDisplayName,
  };
}

Response _error(int status, String message) {
  return Response(
    status,
    body: jsonEncode({'error': message}),
    headers: _jsonHeaders,
  );
}

const _jsonHeaders = {'Content-Type': 'application/json'};
