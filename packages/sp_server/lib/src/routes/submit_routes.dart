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
  final configId = parsed['configId'];
  if (configId is! String || configId.isEmpty) {
    return _error(400, 'Missing or invalid "configId" field');
  }

  final configJson = parsed['config'];
  if (configJson is! Map<String, dynamic>) {
    return _error(400, 'Missing or invalid "config" field');
  }

  final description =
      parsed['description'] as String? ?? 'Add config $configId';

  // Validate config against schema by wrapping it
  // in the root format expected by SmartPlaylistSchema.
  final wrappedConfig = jsonEncode({
    'version': SmartPlaylistSchema.currentVersion,
    'patterns': [configJson],
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

  // Submit PR via GitHub API.
  try {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final branch = 'smartplaylist/$configId-$timestamp';

    final baseSha = await gitHubAppService.getDefaultBranchSha();

    await gitHubAppService.createBranch(branch, baseSha);

    final configContent = const JsonEncoder.withIndent(
      '  ',
    ).convert(configJson);

    await gitHubAppService.commitFile(
      branchName: branch,
      filePath: 'configs/$configId.json',
      content: '$configContent\n',
      message: 'Add config: $configId',
    );

    final userId = request.context['userId'] as String?;
    final prBody = _buildPrBody(description, configId, userId);

    final prUrl = await gitHubAppService.createPullRequest(
      title: 'Add smart playlist config: $configId',
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

String _buildPrBody(String description, String configId, String? userId) {
  final buffer = StringBuffer()
    ..writeln('## Description')
    ..writeln()
    ..writeln(description)
    ..writeln()
    ..writeln('## Config')
    ..writeln()
    ..writeln('- ID: `$configId`');

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
