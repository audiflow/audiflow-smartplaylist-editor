import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:http/http.dart' as http;
import 'package:sp_shared/sp_shared.dart';
import 'package:sp_server/src/handlers/static_file_handler.dart';
import 'package:sp_server/src/middleware/cors_middleware.dart';
import 'package:sp_server/src/routes/config_routes.dart';
import 'package:sp_server/src/routes/feed_routes.dart';
import 'package:sp_server/src/routes/health_routes.dart';
import 'package:sp_server/src/routes/schema_routes.dart';
import 'package:sp_server/src/services/local_config_repository.dart';

Future<void> main() async {
  final env = Platform.environment;
  final portString = env['PORT'] ?? '8080';
  final port = int.parse(portString);

  // TODO(task-7): wire dataDir and cacheDir from env/CLI args
  final dataDir = env['DATA_DIR'] ?? 'data';
  final cacheDir = env['CACHE_DIR'] ?? 'cache/feeds';

  final feedCacheService = DiskFeedCacheService(
    cacheDir: cacheDir,
    httpGet: (Uri url) async {
      final response = await http.get(url);
      return response.body;
    },
  );
  final configRepository = LocalConfigRepository(dataDir: dataDir);

  final validator = SmartPlaylistValidator();

  // Top-level router that mounts sub-routers.
  final router = Router();

  // Mount health routes.
  final health = healthRouter();
  router.get('/api/health', health.call);

  // Mount schema routes (public, no auth required).
  final schema = schemaRouter(validator: validator);
  router.get('/api/schema', schema.call);

  // Mount config routes.
  final configs = configRouter(
    configRepository: configRepository,
    feedCacheService: feedCacheService,
    validator: validator,
  );
  router.get('/api/configs/patterns', configs.call);
  router.get('/api/configs/patterns/<id>', configs.call);
  router.get('/api/configs/patterns/<id>/assembled', configs.call);
  router.get('/api/configs/patterns/<id>/playlists/<pid>', configs.call);
  router.post('/api/configs/validate', configs.call);
  router.post('/api/configs/preview', configs.call);

  // Mount feed routes.
  final feeds = feedRouter(feedCacheService: feedCacheService);
  router.get('/api/feeds', feeds.call);

  final apiHandler = const Pipeline()
      .addMiddleware(corsMiddleware())
      .addHandler(router.call);

  // Serve static files and SPA fallback when WEB_ROOT exists.
  final webRoot = env['WEB_ROOT'] ?? 'public';
  final staticHandler = createStaticFileHandler(webRoot);
  final spaHandler = createSpaFallbackHandler(webRoot);

  final Handler appHandler;
  if (staticHandler != null && spaHandler != null) {
    appHandler = Cascade()
        .add(apiHandler)
        .add(staticHandler)
        .add(spaHandler)
        .handler;
    print('Serving static files from $webRoot');
  } else {
    appHandler = apiHandler;
    print('No web root found at $webRoot; API-only mode');
  }

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(appHandler);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  print(
    'Server listening on '
    'http://${server.address.host}:${server.port}',
  );
}
