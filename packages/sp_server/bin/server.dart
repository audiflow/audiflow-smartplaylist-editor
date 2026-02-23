import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sp_shared/sp_shared.dart';

import 'package:sp_server/src/handlers/static_file_handler.dart';
import 'package:sp_server/src/middleware/cors_middleware.dart';
import 'package:sp_server/src/routes/config_routes.dart';
import 'package:sp_server/src/routes/events_routes.dart';
import 'package:sp_server/src/routes/feed_routes.dart';
import 'package:sp_server/src/routes/health_routes.dart';
import 'package:sp_server/src/routes/schema_routes.dart';
import 'package:sp_server/src/services/file_watcher_service.dart';
import 'package:sp_server/src/services/local_config_repository.dart';

Future<void> main() async {
  final env = Platform.environment;

  final port = int.parse(env['PORT'] ?? '8080');
  final webRoot = env['WEB_ROOT'] ?? 'public';
  final feedCacheTtlSeconds = int.parse(env['SP_FEED_CACHE_TTL'] ?? '3600');

  // Auto-detect data directory from CWD
  final dataDir = Directory.current.path;
  final metaFile = File('$dataDir/patterns/meta.json');
  if (!metaFile.existsSync()) {
    stderr.writeln(
      'Error: No patterns/meta.json found in current directory. '
      'Run this server from a data repository root.',
    );
    exit(1);
  }

  // Construct services
  final configRepository = LocalConfigRepository(dataDir: dataDir);

  final cacheDir = '$dataDir/.cache/feeds';
  final feedCacheService = DiskFeedCacheService(
    cacheDir: cacheDir,
    httpGet: (Uri url) async {
      final response = await http.get(url);
      return response.body;
    },
    cacheTtl: Duration(seconds: feedCacheTtlSeconds),
  );

  final validator = SmartPlaylistValidator();

  final fileWatcher = FileWatcherService(
    watchDir: dataDir,
    ignorePatterns: ['.cache'],
  );

  // Mount routes
  final router = Router();

  final health = healthRouter();
  router.get('/api/health', health.call);

  final schema = schemaRouter(validator: validator);
  router.get('/api/schema', schema.call);

  final configs = configRouter(
    configRepository: configRepository,
    feedCacheService: feedCacheService,
    validator: validator,
  );
  router.get('/api/configs/patterns', configs.call);
  router.post('/api/configs/patterns', configs.call);
  router.get('/api/configs/patterns/<id>', configs.call);
  router.delete('/api/configs/patterns/<id>', configs.call);
  router.put('/api/configs/patterns/<id>/meta', configs.call);
  router.get('/api/configs/patterns/<id>/assembled', configs.call);
  router.get('/api/configs/patterns/<id>/playlists/<pid>', configs.call);
  router.put('/api/configs/patterns/<id>/playlists/<pid>', configs.call);
  router.delete('/api/configs/patterns/<id>/playlists/<pid>', configs.call);
  router.post('/api/configs/validate', configs.call);
  router.post('/api/configs/preview', configs.call);

  final feeds = feedRouter(feedCacheService: feedCacheService);
  router.get('/api/feeds', feeds.call);

  router.get('/api/events', eventsHandler(fileWatcher.events));

  // Build pipeline
  final apiHandler = const Pipeline()
      .addMiddleware(corsMiddleware())
      .addHandler(router.call);

  final staticHandler = createStaticFileHandler(webRoot);
  final spaHandler = createSpaFallbackHandler(webRoot);

  final Handler appHandler;
  if (staticHandler != null && spaHandler != null) {
    appHandler = Cascade()
        .add(apiHandler)
        .add(staticHandler)
        .add(spaHandler)
        .handler;
  } else {
    appHandler = apiHandler;
  }

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(appHandler);

  // Start file watcher before binding server
  await fileWatcher.start();

  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4,
    port,
  );

  print('Serving data from: $dataDir');
  print('Feed cache: $cacheDir (TTL: ${feedCacheTtlSeconds}s)');
  print(
    'Server listening on '
    'http://${server.address.host}:${server.port}',
  );
}
