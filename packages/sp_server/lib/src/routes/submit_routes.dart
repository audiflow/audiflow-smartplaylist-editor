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
}) {
  final router = Router();

  final auth = unifiedAuthMiddleware(
    jwtService: jwtService,
    apiKeyService: apiKeyService,
  );

  // POST /api/configs/submit
  final submitHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handleSubmit(r, gitHubAppService));
  router.post('/api/configs/submit', submitHandler);

  return router;
}

Future<Response> _handleSubmit(
  Request request,
  GitHubAppService gitHubAppService,
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

  final playlistId = parsed['playlistId'] as String?;
  final playlistJson = parsed['playlist'];
  final patternMetaJson = parsed['patternMeta'];
  final isNewPattern = parsed['isNewPattern'] as bool? ?? false;
  final description =
      parsed['description'] as String? ?? 'Update config $patternId';

  // At minimum we need a playlist to submit.
  if (playlistJson is! Map<String, dynamic>) {
    return _error(400, 'Missing or invalid "playlist" field');
  }

  // Validate playlist against schema by wrapping in
  // the root format expected by SmartPlaylistSchema.
  final wrappedConfig = jsonEncode({
    'version': SmartPlaylistSchema.currentVersion,
    'patterns': [
      {
        'id': patternId,
        'playlists': [playlistJson],
      },
    ],
  });
  final errors = SmartPlaylistSchema.validate(wrappedConfig);
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

  final SmartPlaylistDefinition playlistDef;
  try {
    playlistDef = SmartPlaylistDefinition.fromJson(playlistJson);
  } on Object catch (e) {
    return _error(400, 'Invalid playlist definition: $e');
  }

  // Submit PR via GitHub API.
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final branch = 'smartplaylist/$patternId-$timestamp';

    final baseSha = await gitHubAppService.getDefaultBranchSha();
    await gitHubAppService.createBranch(branch, baseSha);

    final encoder = const JsonEncoder.withIndent('  ');

    // Commit playlist file.
    final effectivePlaylistId = playlistId ?? playlistDef.id;
    final playlistContent = encoder.convert(playlistJson);
    await gitHubAppService.commitFile(
      branchName: branch,
      filePath: '$patternId/playlists/$effectivePlaylistId.json',
      content: '$playlistContent\n',
      message: 'Add playlist: $effectivePlaylistId',
    );

    // Commit pattern meta if provided.
    if (patternMetaJson is Map<String, dynamic>) {
      final metaContent = encoder.convert(patternMetaJson);
      await gitHubAppService.commitFile(
        branchName: branch,
        filePath: '$patternId/meta.json',
        content: '$metaContent\n',
        message: isNewPattern
            ? 'Add pattern meta: $patternId'
            : 'Update pattern meta: $patternId',
      );
    }

    final userId = request.context['userId'] as String?;
    final prBody = _buildPrBody(
      description,
      patternId,
      effectivePlaylistId,
      userId,
    );

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
  String playlistId,
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
    ..writeln('- Playlist: `$playlistId`');

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
