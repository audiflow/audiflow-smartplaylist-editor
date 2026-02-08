import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Registers health-check routes under `/api`.
Router healthRouter() {
  final router = Router();

  router.get('/api/health', _healthHandler);

  return router;
}

Response _healthHandler(Request request) {
  return Response.ok(
    jsonEncode({'status': 'ok'}),
    headers: {'Content-Type': 'application/json'},
  );
}
