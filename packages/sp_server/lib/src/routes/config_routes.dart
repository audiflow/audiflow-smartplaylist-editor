import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sp_shared/sp_shared.dart';

import '../middleware/api_key_middleware.dart';
import '../services/api_key_service.dart';
import '../services/config_repository.dart';
import '../services/jwt_service.dart';

/// Registers config routes under `/api/configs`.
///
/// All routes require unified authentication
/// (JWT or API key).
Router configRouter({
  required ConfigRepository configRepository,
  required JwtService jwtService,
  required ApiKeyService apiKeyService,
}) {
  final router = Router();

  final auth = unifiedAuthMiddleware(
    jwtService: jwtService,
    apiKeyService: apiKeyService,
  );

  // GET /api/configs
  final listHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handleList(r, configRepository));
  router.get('/api/configs', listHandler);

  // GET /api/configs/<id>
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
      .addHandler((Request r) => _handlePreview(r));
  router.post('/api/configs/preview', previewHandler);

  return router;
}

Future<Response> _handleList(
  Request request,
  ConfigRepository configRepository,
) async {
  try {
    final configs = await configRepository.listConfigs();
    return Response.ok(
      jsonEncode({'configs': configs.map((c) => c.toJson()).toList()}),
      headers: _jsonHeaders,
    );
  } on Exception catch (e) {
    return Response(
      502,
      body: jsonEncode({'error': 'Failed to fetch configs: $e'}),
      headers: _jsonHeaders,
    );
  }
}

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
    final config = await configRepository.getConfig(id);
    if (config == null) {
      return Response(
        404,
        body: jsonEncode({'error': 'Config not found: $id'}),
        headers: _jsonHeaders,
      );
    }
    return Response.ok(jsonEncode(config), headers: _jsonHeaders);
  } on Exception catch (e) {
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

Future<Response> _handlePreview(Request request) async {
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
  final episodesJson = parsed['episodes'];

  if (configJson is! Map<String, dynamic>) {
    return Response(
      400,
      body: jsonEncode({'error': 'Missing or invalid "config" field'}),
      headers: _jsonHeaders,
    );
  }

  if (episodesJson is! List) {
    return Response(
      400,
      body: jsonEncode({'error': 'Missing or invalid "episodes" field'}),
      headers: _jsonHeaders,
    );
  }

  try {
    final config = SmartPlaylistPatternConfig.fromJson(configJson);
    final episodes = _parseEpisodes(episodesJson);
    final result = _runPreview(config, episodes);
    return Response.ok(jsonEncode(result), headers: _jsonHeaders);
  } on Exception catch (e) {
    return Response(
      400,
      body: jsonEncode({'error': 'Preview failed: $e'}),
      headers: _jsonHeaders,
    );
  }
}

List<SimpleEpisodeData> _parseEpisodes(List<dynamic> json) {
  return json.whereType<Map<String, dynamic>>().map(_parseEpisode).toList();
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

Map<String, dynamic> _runPreview(
  SmartPlaylistPatternConfig config,
  List<SimpleEpisodeData> episodes,
) {
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

  final result = service.resolveSmartPlaylists(
    podcastGuid: config.podcastGuid,
    feedUrl: config.feedUrlPatterns?.firstOrNull ?? '',
    episodes: episodes,
  );

  if (result == null) {
    return {
      'playlists': <Map<String, dynamic>>[],
      'ungroupedEpisodeIds': <int>[],
      'resolverType': null,
    };
  }

  return {
    'playlists': result.playlists.map(_serializePlaylist).toList(),
    'ungroupedEpisodeIds': result.ungroupedEpisodeIds,
    'resolverType': result.resolverType,
  };
}

Map<String, dynamic> _serializePlaylist(SmartPlaylist playlist) {
  return {
    'id': playlist.id,
    'displayName': playlist.displayName,
    'sortKey': playlist.sortKey,
    'episodeIds': playlist.episodeIds,
    'episodeCount': playlist.episodeCount,
    if (playlist.groups != null)
      'groups': playlist.groups!.map(_serializeGroup).toList(),
  };
}

Map<String, dynamic> _serializeGroup(SmartPlaylistGroup group) {
  return {
    'id': group.id,
    'displayName': group.displayName,
    'sortKey': group.sortKey,
    'episodeIds': group.episodeIds,
    'episodeCount': group.episodeCount,
  };
}

const _jsonHeaders = {'Content-Type': 'application/json'};
