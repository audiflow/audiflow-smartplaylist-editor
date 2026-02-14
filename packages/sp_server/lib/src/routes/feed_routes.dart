import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middleware/api_key_middleware.dart';
import '../services/api_key_service.dart';
import '../services/feed_cache_service.dart';
import '../services/jwt_service.dart';

/// Registers feed routes under `/api/feeds`.
///
/// All routes require unified authentication
/// (JWT or API key).
Router feedRouter({
  required FeedCacheService feedCacheService,
  required JwtService jwtService,
  required ApiKeyService apiKeyService,
}) {
  final router = Router();

  final auth = unifiedAuthMiddleware(
    jwtService: jwtService,
    apiKeyService: apiKeyService,
  );

  final getHandler = const Pipeline()
      .addMiddleware(auth)
      .addHandler(
        (Request request) => _handleGetFeed(request, feedCacheService),
      );
  router.get('/api/feeds', getHandler);

  return router;
}

Future<Response> _handleGetFeed(
  Request request,
  FeedCacheService feedCacheService,
) async {
  final url = request.url.queryParameters['url'];
  if (url == null || url.isEmpty) {
    return Response(
      400,
      body: jsonEncode({'error': 'Missing required query parameter: url'}),
      headers: _jsonHeaders,
    );
  }

  // Basic URL validation.
  final parsed = Uri.tryParse(url);
  if (parsed == null || !parsed.hasScheme) {
    return Response(
      400,
      body: jsonEncode({'error': 'Invalid URL'}),
      headers: _jsonHeaders,
    );
  }

  try {
    final episodes = await feedCacheService.fetchFeed(url);
    return Response.ok(
      jsonEncode({'episodes': episodes}),
      headers: _jsonHeaders,
    );
  } on Object catch (e) {
    return Response(
      502,
      body: jsonEncode({'error': 'Failed to fetch feed: $e'}),
      headers: _jsonHeaders,
    );
  }
}

const _jsonHeaders = {'Content-Type': 'application/json'};
