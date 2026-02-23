import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sp_shared/sp_shared.dart';

/// Registers feed routes under `/api/feeds`.
Router feedRouter({required DiskFeedCacheService feedCacheService}) {
  final router = Router();

  router.get(
    '/api/feeds',
    (Request request) => _handleGetFeed(request, feedCacheService),
  );

  return router;
}

Future<Response> _handleGetFeed(
  Request request,
  DiskFeedCacheService feedCacheService,
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
