import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middleware/auth_middleware.dart';
import '../services/api_key_service.dart';
import '../services/jwt_service.dart';

/// Registers API key management routes under
/// `/api/keys`.
///
/// All routes require JWT authentication (not API key)
/// because key management should only be done by
/// authenticated users via the web UI.
Router keyRouter({
  required JwtService jwtService,
  required ApiKeyService apiKeyService,
}) {
  final router = Router();
  final jwtAuth = authMiddleware(jwtService);

  // POST /api/keys - Generate a new API key.
  final createHandler = const Pipeline()
      .addMiddleware(jwtAuth)
      .addHandler((Request request) => _handleCreate(request, apiKeyService));
  router.post('/api/keys', createHandler);

  // GET /api/keys - List user's API keys.
  final listHandler = const Pipeline()
      .addMiddleware(jwtAuth)
      .addHandler((Request request) => _handleList(request, apiKeyService));
  router.get('/api/keys', listHandler);

  // DELETE /api/keys/<id> - Revoke an API key.
  router.delete('/api/keys/<id>', (Request request, String id) {
    final authedHandler = const Pipeline()
        .addMiddleware(jwtAuth)
        .addHandler((Request req) => _handleDelete(req, apiKeyService, id));
    return authedHandler(request);
  });

  return router;
}

Future<Response> _handleCreate(
  Request request,
  ApiKeyService apiKeyService,
) async {
  final userId = request.context[userIdContextKey] as String?;
  if (userId == null) {
    return Response(
      401,
      body: jsonEncode({'error': 'Unauthorized'}),
      headers: _jsonHeaders,
    );
  }

  final bodyString = await request.readAsString();
  if (bodyString.isEmpty) {
    return Response(
      400,
      body: jsonEncode({'error': 'Request body required'}),
      headers: _jsonHeaders,
    );
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(bodyString) as Map<String, dynamic>;
  } on Object {
    return Response(
      400,
      body: jsonEncode({'error': 'Invalid JSON'}),
      headers: _jsonHeaders,
    );
  }

  final name = body['name'] as String?;
  if (name == null || name.isEmpty) {
    return Response(
      400,
      body: jsonEncode({'error': 'Name is required'}),
      headers: _jsonHeaders,
    );
  }

  final result = apiKeyService.generateKey(userId, name);

  return Response(
    201,
    body: jsonEncode({
      'key': result.plaintext,
      'metadata': result.apiKey.toJson(),
    }),
    headers: _jsonHeaders,
  );
}

Response _handleList(Request request, ApiKeyService apiKeyService) {
  final userId = request.context[userIdContextKey] as String?;
  if (userId == null) {
    return Response(
      401,
      body: jsonEncode({'error': 'Unauthorized'}),
      headers: _jsonHeaders,
    );
  }

  final keys = apiKeyService.listKeys(userId);
  final jsonList = keys.map((k) => k.toJson()).toList();

  return Response.ok(jsonEncode({'keys': jsonList}), headers: _jsonHeaders);
}

Response _handleDelete(
  Request request,
  ApiKeyService apiKeyService,
  String id,
) {
  final userId = request.context[userIdContextKey] as String?;
  if (userId == null) {
    return Response(
      401,
      body: jsonEncode({'error': 'Unauthorized'}),
      headers: _jsonHeaders,
    );
  }

  final deleted = apiKeyService.deleteKey(userId, id);
  if (!deleted) {
    return Response(
      404,
      body: jsonEncode({'error': 'Key not found'}),
      headers: _jsonHeaders,
    );
  }

  return Response.ok(jsonEncode({'deleted': true}), headers: _jsonHeaders);
}

const _jsonHeaders = {'Content-Type': 'application/json'};
