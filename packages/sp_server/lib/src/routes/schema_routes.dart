import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sp_shared/sp_shared.dart';

/// Registers the schema endpoint under `/api`.
Router schemaRouter({required SmartPlaylistValidator validator}) {
  final router = Router();

  // Cache the schema string since it never changes at runtime.
  final schema = validator.schemaString;

  router.get('/api/schema', (Request request) {
    return Response.ok(schema, headers: {'Content-Type': 'application/json'});
  });

  return router;
}
