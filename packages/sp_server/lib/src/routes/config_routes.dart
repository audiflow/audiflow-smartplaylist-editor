import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sp_shared/sp_shared.dart';

import '../services/local_config_repository.dart';

/// Registers config routes under `/api/configs`.
Router configRouter({
  required LocalConfigRepository configRepository,
  required DiskFeedCacheService feedCacheService,
  required SmartPlaylistValidator validator,
}) {
  final router = Router();

  // GET /api/configs/patterns/<id>/assembled
  // Must be registered before /api/configs/patterns/<id> to avoid
  // path conflicts.
  router.get(
    '/api/configs/patterns/<id>/assembled',
    (Request r) => _handleAssembled(r, configRepository),
  );

  // PUT /api/configs/patterns/<id>/playlists/<pid>
  router.put(
    '/api/configs/patterns/<id>/playlists/<pid>',
    (Request r) => _handleSavePlaylist(r, configRepository, validator),
  );

  // DELETE /api/configs/patterns/<id>/playlists/<pid>
  router.delete(
    '/api/configs/patterns/<id>/playlists/<pid>',
    (Request r) => _handleDeletePlaylist(r, configRepository),
  );

  // GET /api/configs/patterns/<id>/playlists/<pid>
  router.get(
    '/api/configs/patterns/<id>/playlists/<pid>',
    (Request r) => _handlePlaylist(r, configRepository),
  );

  // PUT /api/configs/patterns/<id>/meta
  router.put(
    '/api/configs/patterns/<id>/meta',
    (Request r) => _handleSavePatternMeta(r, configRepository),
  );

  // DELETE /api/configs/patterns/<id>
  router.delete(
    '/api/configs/patterns/<id>',
    (Request r) => _handleDeletePattern(r, configRepository),
  );

  // GET /api/configs/patterns/<id>
  router.get(
    '/api/configs/patterns/<id>',
    (Request r) => _handlePatternMeta(r, configRepository),
  );

  // POST /api/configs/patterns (create new pattern)
  router.post(
    '/api/configs/patterns',
    (Request r) => _handleCreatePattern(r, configRepository),
  );

  // GET /api/configs/patterns
  router.get(
    '/api/configs/patterns',
    (Request r) => _handlePatterns(r, configRepository),
  );

  // POST /api/configs/validate
  router.post(
    '/api/configs/validate',
    (Request r) => _handleValidate(r, validator),
  );

  // POST /api/configs/preview
  router.post(
    '/api/configs/preview',
    (Request r) => _handlePreview(r, feedCacheService),
  );

  return router;
}

/// GET /api/configs/patterns -- returns pattern summaries.
Future<Response> _handlePatterns(
  Request request,
  LocalConfigRepository configRepository,
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
  LocalConfigRepository configRepository,
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
  LocalConfigRepository configRepository,
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
  LocalConfigRepository configRepository,
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

/// PUT /api/configs/patterns/<id>/playlists/<pid> -- saves playlist to disk.
Future<Response> _handleSavePlaylist(
  Request request,
  LocalConfigRepository configRepository,
  SmartPlaylistValidator validator,
) async {
  final id = request.params['id'];
  final pid = request.params['pid'];
  if (id == null || id.isEmpty) return _error(400, 'Missing pattern ID');
  if (pid == null || pid.isEmpty) return _error(400, 'Missing playlist ID');

  final bodyStr = await request.readAsString();
  if (bodyStr.isEmpty) return _error(400, 'Request body is empty');

  final Object? parsed;
  try {
    parsed = jsonDecode(bodyStr);
  } on FormatException {
    return _error(400, 'Invalid JSON');
  }

  if (parsed is! Map<String, dynamic>) {
    return _error(400, 'Request body must be a JSON object');
  }

  // Validate the playlist by wrapping in a full config envelope
  final envelope = {
    'version': 1,
    'patterns': [
      {
        'id': id,
        'playlists': [parsed],
      },
    ],
  };
  final errors = validator.validate(envelope);
  if (errors.isNotEmpty) {
    return Response(
      400,
      body: jsonEncode({
        'error': 'Validation failed',
        'errors': errors,
      }),
      headers: _jsonHeaders,
    );
  }

  try {
    await configRepository.savePlaylist(id, pid, parsed);
    return Response.ok(
      jsonEncode({'ok': true}),
      headers: _jsonHeaders,
    );
  } on Object catch (e) {
    return Response(
      500,
      body: jsonEncode({'error': 'Failed to save playlist: $e'}),
      headers: _jsonHeaders,
    );
  }
}

/// PUT /api/configs/patterns/<id>/meta -- saves pattern meta to disk.
Future<Response> _handleSavePatternMeta(
  Request request,
  LocalConfigRepository configRepository,
) async {
  final id = request.params['id'];
  if (id == null || id.isEmpty) return _error(400, 'Missing pattern ID');

  final bodyStr = await request.readAsString();
  if (bodyStr.isEmpty) return _error(400, 'Request body is empty');

  final Object? parsed;
  try {
    parsed = jsonDecode(bodyStr);
  } on FormatException {
    return _error(400, 'Invalid JSON');
  }

  if (parsed is! Map<String, dynamic>) {
    return _error(400, 'Request body must be a JSON object');
  }

  try {
    await configRepository.savePatternMeta(id, parsed);
    return Response.ok(
      jsonEncode({'ok': true}),
      headers: _jsonHeaders,
    );
  } on Object catch (e) {
    return Response(
      500,
      body: jsonEncode({'error': 'Failed to save pattern meta: $e'}),
      headers: _jsonHeaders,
    );
  }
}

/// POST /api/configs/patterns -- creates a new pattern directory with meta.
Future<Response> _handleCreatePattern(
  Request request,
  LocalConfigRepository configRepository,
) async {
  final bodyStr = await request.readAsString();
  if (bodyStr.isEmpty) return _error(400, 'Request body is empty');

  final Object? parsed;
  try {
    parsed = jsonDecode(bodyStr);
  } on FormatException {
    return _error(400, 'Invalid JSON');
  }

  if (parsed is! Map<String, dynamic>) {
    return _error(400, 'Request body must be a JSON object');
  }

  final id = parsed['id'];
  final meta = parsed['meta'];

  if (id is! String || id.isEmpty) {
    return _error(400, 'Missing or invalid "id" field');
  }
  if (meta is! Map<String, dynamic>) {
    return _error(400, 'Missing or invalid "meta" field');
  }

  try {
    await configRepository.createPattern(id, meta);
    return Response(
      201,
      body: jsonEncode({'ok': true, 'id': id}),
      headers: _jsonHeaders,
    );
  } on Object catch (e) {
    return Response(
      500,
      body: jsonEncode({'error': 'Failed to create pattern: $e'}),
      headers: _jsonHeaders,
    );
  }
}

/// DELETE /api/configs/patterns/<id>/playlists/<pid>
Future<Response> _handleDeletePlaylist(
  Request request,
  LocalConfigRepository configRepository,
) async {
  final id = request.params['id'];
  final pid = request.params['pid'];
  if (id == null || id.isEmpty) return _error(400, 'Missing pattern ID');
  if (pid == null || pid.isEmpty) return _error(400, 'Missing playlist ID');

  try {
    await configRepository.deletePlaylist(id, pid);
    return Response.ok(
      jsonEncode({'ok': true}),
      headers: _jsonHeaders,
    );
  } on FileSystemException {
    return _error(404, 'Playlist not found');
  } on Object catch (e) {
    return Response(
      500,
      body: jsonEncode({'error': 'Failed to delete playlist: $e'}),
      headers: _jsonHeaders,
    );
  }
}

/// DELETE /api/configs/patterns/<id>
Future<Response> _handleDeletePattern(
  Request request,
  LocalConfigRepository configRepository,
) async {
  final id = request.params['id'];
  if (id == null || id.isEmpty) return _error(400, 'Missing pattern ID');

  try {
    await configRepository.deletePattern(id);
    return Response.ok(
      jsonEncode({'ok': true}),
      headers: _jsonHeaders,
    );
  } on FileSystemException {
    return _error(404, 'Pattern not found');
  } on Object catch (e) {
    return Response(
      500,
      body: jsonEncode({'error': 'Failed to delete pattern: $e'}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _handleValidate(
  Request request,
  SmartPlaylistValidator validator,
) async {
  final body = await request.readAsString();
  if (body.isEmpty) {
    return Response(
      400,
      body: jsonEncode({'error': 'Request body is empty'}),
      headers: _jsonHeaders,
    );
  }

  final errors = validator.validateString(body);
  return Response.ok(
    jsonEncode({'valid': errors.isEmpty, 'errors': errors}),
    headers: _jsonHeaders,
  );
}

Future<Response> _handlePreview(
  Request request,
  DiskFeedCacheService feedCacheService,
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
