import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middleware/api_key_middleware.dart';
import '../middleware/auth_middleware.dart';
import '../services/api_key_service.dart';
import '../services/draft_service.dart';
import '../services/jwt_service.dart';

/// Registers draft config routes under `/api/drafts`.
///
/// All routes require unified authentication
/// (JWT or API key).
Router draftRouter({
  required DraftService draftService,
  required JwtService jwtService,
  required ApiKeyService apiKeyService,
}) {
  final router = Router();

  final auth = unifiedAuthMiddleware(
    jwtService: jwtService,
    apiKeyService: apiKeyService,
  );

  // POST /api/drafts
  final createHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handleCreate(r, draftService));
  router.post('/api/drafts', createHandler);

  // GET /api/drafts
  final listHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handleList(r, draftService));
  router.get('/api/drafts', listHandler);

  // GET /api/drafts/<id>
  final getHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler((Request r) => _handleGet(r, draftService));
  router.get('/api/drafts/<id>', getHandler);

  // DELETE /api/drafts/<id>
  router.delete('/api/drafts/<id>', (Request request, String id) {
    final authedHandler = const Pipeline()
        .addMiddleware(auth)
        .addHandler((Request req) => _handleDelete(req, draftService, id));
    return authedHandler(request);
  });

  return router;
}

Future<Response> _handleCreate(
  Request request,
  DraftService draftService,
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

  final config = body['config'];
  if (config is! Map<String, dynamic>) {
    return Response(
      400,
      body: jsonEncode({'error': 'Config must be a JSON object'}),
      headers: _jsonHeaders,
    );
  }

  final feedUrl = body['feedUrl'] as String?;

  final draft = draftService.saveDraft(userId, name, config, feedUrl: feedUrl);

  return Response(201, body: jsonEncode(draft.toJson()), headers: _jsonHeaders);
}

Response _handleList(Request request, DraftService draftService) {
  final userId = request.context[userIdContextKey] as String?;
  if (userId == null) {
    return Response(
      401,
      body: jsonEncode({'error': 'Unauthorized'}),
      headers: _jsonHeaders,
    );
  }

  final drafts = draftService.listDrafts(userId);
  final jsonList = drafts.map((d) => d.toJson()).toList();

  return Response.ok(jsonEncode({'drafts': jsonList}), headers: _jsonHeaders);
}

Response _handleGet(Request request, DraftService draftService) {
  final userId = request.context[userIdContextKey] as String?;
  if (userId == null) {
    return Response(
      401,
      body: jsonEncode({'error': 'Unauthorized'}),
      headers: _jsonHeaders,
    );
  }

  final id = request.params['id'];
  if (id == null || id.isEmpty) {
    return Response(
      400,
      body: jsonEncode({'error': 'Missing draft ID'}),
      headers: _jsonHeaders,
    );
  }

  final draft = draftService.getDraft(userId, id);
  if (draft == null) {
    return Response(
      404,
      body: jsonEncode({'error': 'Draft not found'}),
      headers: _jsonHeaders,
    );
  }

  return Response.ok(jsonEncode(draft.toJson()), headers: _jsonHeaders);
}

Response _handleDelete(Request request, DraftService draftService, String id) {
  final userId = request.context[userIdContextKey] as String?;
  if (userId == null) {
    return Response(
      401,
      body: jsonEncode({'error': 'Unauthorized'}),
      headers: _jsonHeaders,
    );
  }

  final deleted = draftService.deleteDraft(userId, id);
  if (!deleted) {
    return Response(
      404,
      body: jsonEncode({'error': 'Draft not found'}),
      headers: _jsonHeaders,
    );
  }

  return Response(204);
}

const _jsonHeaders = {'Content-Type': 'application/json'};
