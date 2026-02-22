import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sp_shared/sp_shared.dart';

import '../middleware/api_key_middleware.dart';
import '../services/api_key_service.dart';
import '../services/github_app_service.dart';
import '../services/jwt_service.dart';

/// Registers submit routes under `/api/configs`.
///
/// Requires unified authentication (JWT or API key).
Router submitRouter({
  required GitHubAppService gitHubAppService,
  required JwtService jwtService,
  required ApiKeyService apiKeyService,
  required SmartPlaylistValidator validator,
}) {
  final router = Router();

  final auth = unifiedAuthMiddleware(
    jwtService: jwtService,
    apiKeyService: apiKeyService,
  );

  // POST /api/configs/submit
  final submitHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handleSubmit(r, gitHubAppService, validator));
  router.post('/api/configs/submit', submitHandler);

  return router;
}

Future<Response> _handleSubmit(
  Request request,
  GitHubAppService gitHubAppService,
  SmartPlaylistValidator validator,
) async {
  // Parse body.
  final body = await request.readAsString();
  if (body.isEmpty) {
    return _error(400, 'Request body is empty');
  }

  final Object? parsed;
  try {
    parsed = jsonDecode(body);
  } on FormatException {
    return _error(400, 'Invalid JSON');
  }

  if (parsed is! Map<String, dynamic>) {
    return _error(400, 'Request body must be a JSON object');
  }

  // Validate required fields.
  final patternId = parsed['patternId'];
  if (patternId is! String || patternId.isEmpty) {
    return _error(400, 'Missing or invalid "patternId" field');
  }

  final isNewPattern = parsed['isNewPattern'] as bool? ?? false;
  final description =
      parsed['description'] as String? ?? 'Update config $patternId';

  // Accept either `playlists` (array) or `playlist` (single, legacy).
  final List<Map<String, dynamic>> playlistJsonList;
  final playlistsRaw = parsed['playlists'];
  final playlistRaw = parsed['playlist'];
  if (playlistsRaw is List && playlistsRaw.isNotEmpty) {
    playlistJsonList = playlistsRaw.cast<Map<String, dynamic>>();
  } else if (playlistRaw is Map<String, dynamic>) {
    playlistJsonList = [playlistRaw];
  } else {
    return _error(400, 'Missing "playlists" or "playlist" field');
  }

  // Validate all playlists against schema.
  final wrappedConfig = jsonEncode({
    'version': SmartPlaylistSchemaConstants.currentVersion,
    'patterns': [
      {'id': patternId, 'playlists': playlistJsonList},
    ],
  });
  final errors = validator.validateString(wrappedConfig);
  if (errors.isNotEmpty) {
    return Response(
      400,
      body: jsonEncode({
        'error': 'Config validation failed',
        'details': errors,
      }),
      headers: _jsonHeaders,
    );
  }

  // Parse all playlist definitions.
  final List<SmartPlaylistDefinition> playlistDefs;
  try {
    playlistDefs = [
      for (final json in playlistJsonList)
        SmartPlaylistDefinition.fromJson(json),
    ];
  } on Object catch (e) {
    return _error(400, 'Invalid playlist definition: $e');
  }

  // Build canonical PatternMeta from known data + client fields.
  final patternMetaJson = parsed['patternMeta'] as Map<String, dynamic>? ?? {};
  final patternMeta = PatternMeta(
    version: SmartPlaylistSchemaConstants.currentVersion,
    id: patternId,
    feedUrls:
        (patternMetaJson['feedUrls'] as List<dynamic>?)?.cast<String>() ?? [],
    playlists: playlistDefs.map((d) => d.id).toList(),
    podcastGuid: patternMetaJson['podcastGuid'] as String?,
    yearGroupedEpisodes:
        (patternMetaJson['yearGroupedEpisodes'] as bool?) ?? false,
  );

  // If `branch` is provided, append commits to existing branch.
  final existingBranch = parsed['branch'] as String?;

  // Submit via GitHub API.
  try {
    final String branch;
    if (existingBranch != null) {
      branch = existingBranch;
    } else {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      branch = 'smartplaylist/$patternId-$timestamp';
      final baseSha = await gitHubAppService.getDefaultBranchSha();
      await gitHubAppService.createBranch(branch, baseSha);
    }

    final encoder = const JsonEncoder.withIndent('  ');

    // Commit each playlist file (normalized via Dart model).
    for (final def in playlistDefs) {
      final playlistContent = encoder.convert(def.toJson());
      await gitHubAppService.commitFile(
        branchName: branch,
        filePath: '$patternId/playlists/${def.id}.json',
        content: '$playlistContent\n',
        message: isNewPattern
            ? 'Add playlist: ${def.id}'
            : 'Update playlist: ${def.id}',
      );
    }

    // Always commit meta.json with canonical structure.
    final metaContent = encoder.convert(patternMeta.toJson());
    await gitHubAppService.commitFile(
      branchName: branch,
      filePath: '$patternId/meta.json',
      content: '$metaContent\n',
      message: isNewPattern
          ? 'Add pattern meta: $patternId'
          : 'Update pattern meta: $patternId',
    );

    // Skip PR creation when updating an existing branch.
    if (existingBranch != null) {
      return Response(
        200,
        body: jsonEncode({'branch': branch}),
        headers: _jsonHeaders,
      );
    }

    final userId = request.context['userId'] as String?;
    final playlistIds = playlistDefs.map((d) => d.id).join(', ');
    final prBody = _buildPrBody(description, patternId, playlistIds, userId);

    final prUrl = await gitHubAppService.createPullRequest(
      title: isNewPattern
          ? 'Add smart playlist pattern: $patternId'
          : 'Update pattern: $patternId',
      body: prBody,
      head: branch,
    );

    return Response(
      201,
      body: jsonEncode({'prUrl': prUrl, 'branch': branch}),
      headers: _jsonHeaders,
    );
  } on GitHubApiException catch (e) {
    return Response(
      502,
      body: jsonEncode({'error': 'GitHub API error: ${e.message}'}),
      headers: _jsonHeaders,
    );
  }
}

String _buildPrBody(
  String description,
  String patternId,
  String playlistIds,
  String? userId,
) {
  final buffer = StringBuffer()
    ..writeln('## Description')
    ..writeln()
    ..writeln(description)
    ..writeln()
    ..writeln('## Config')
    ..writeln()
    ..writeln('- Pattern: `$patternId`')
    ..writeln('- Playlists: `$playlistIds`');

  if (userId != null) {
    buffer
      ..writeln()
      ..writeln('## Contributor')
      ..writeln()
      ..writeln('- Submitted by: `$userId`');
  }

  return buffer.toString();
}

Response _error(int status, String message) {
  return Response(
    status,
    body: jsonEncode({'error': message}),
    headers: _jsonHeaders,
  );
}

const _jsonHeaders = {'Content-Type': 'application/json'};
