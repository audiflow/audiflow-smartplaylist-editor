import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:http/http.dart' as http;
import 'package:sp_server/src/middleware/cors_middleware.dart';
import 'package:sp_server/src/routes/auth_routes.dart';
import 'package:sp_server/src/routes/config_routes.dart';
import 'package:sp_server/src/routes/draft_routes.dart';
import 'package:sp_server/src/routes/feed_routes.dart';
import 'package:sp_server/src/routes/health_routes.dart';
import 'package:sp_server/src/routes/key_routes.dart';
import 'package:sp_server/src/routes/schema_routes.dart';
import 'package:sp_server/src/routes/submit_routes.dart';
import 'package:sp_server/src/services/api_key_service.dart';
import 'package:sp_server/src/services/config_repository.dart';
import 'package:sp_server/src/services/draft_service.dart';
import 'package:sp_server/src/services/feed_cache_service.dart';
import 'package:sp_server/src/services/github_app_service.dart';
import 'package:sp_server/src/services/github_oauth_service.dart';
import 'package:sp_server/src/services/jwt_service.dart';
import 'package:sp_server/src/services/user_service.dart';

Future<void> main() async {
  final env = Platform.environment;
  final portString = env['PORT'] ?? '8080';
  final port = int.parse(portString);
  final jwtSecret = env['JWT_SECRET'] ?? 'dev-secret';

  final configBaseUrl =
      env['CONFIG_REPO_URL'] ??
      'https://raw.githubusercontent.com/'
          'reedom/audiflow-smart-playlists/main';

  final jwtService = JwtService(secret: jwtSecret);
  final userService = UserService();
  final gitHubOAuthService = GitHubOAuthService();
  final apiKeyService = ApiKeyService();
  final draftService = DraftService();
  final gitHubAppService = GitHubAppService();
  final feedCacheService = FeedCacheService(
    httpGet: (Uri url) async {
      final response = await http.get(url);
      return response.body;
    },
  );
  final configRepository = ConfigRepository(
    httpGet: (Uri url) async {
      final response = await http.get(url);
      return response.body;
    },
    baseUrl: configBaseUrl,
  );

  // Top-level router that mounts sub-routers.
  final router = Router();

  // Mount health routes.
  final health = healthRouter();
  router.get('/api/health', health.call);

  // Mount schema routes (public, no auth required).
  final schema = schemaRouter();
  router.get('/api/schema', schema.call);

  // Mount auth routes.
  final auth = authRouter(
    gitHubOAuthService: gitHubOAuthService,
    jwtService: jwtService,
    userService: userService,
  );
  router.get('/api/auth/<path|.*>', auth.call);

  // Mount API key management routes.
  final keys = keyRouter(jwtService: jwtService, apiKeyService: apiKeyService);
  router.post('/api/keys', keys.call);
  router.get('/api/keys', keys.call);
  router.delete('/api/keys/<id>', keys.call);

  // Mount config routes.
  final configs = configRouter(
    configRepository: configRepository,
    jwtService: jwtService,
    apiKeyService: apiKeyService,
  );
  router.get('/api/configs', configs.call);
  router.get('/api/configs/patterns', configs.call);
  router.get('/api/configs/patterns/<id>', configs.call);
  router.get('/api/configs/patterns/<id>/assembled', configs.call);
  router.get('/api/configs/patterns/<id>/playlists/<pid>', configs.call);
  router.get('/api/configs/<id>', configs.call);
  router.post('/api/configs/validate', configs.call);
  router.post('/api/configs/preview', configs.call);

  // Mount feed routes.
  final feeds = feedRouter(
    feedCacheService: feedCacheService,
    jwtService: jwtService,
    apiKeyService: apiKeyService,
  );
  router.get('/api/feeds', feeds.call);

  // Mount submit routes.
  final submit = submitRouter(
    gitHubAppService: gitHubAppService,
    jwtService: jwtService,
    apiKeyService: apiKeyService,
  );
  router.post('/api/configs/submit', submit.call);

  // Mount draft routes.
  final drafts = draftRouter(
    draftService: draftService,
    jwtService: jwtService,
    apiKeyService: apiKeyService,
  );
  router.post('/api/drafts', drafts.call);
  router.get('/api/drafts', drafts.call);
  router.get('/api/drafts/<id>', drafts.call);
  router.delete('/api/drafts/<id>', drafts.call);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  print(
    'Server listening on '
    'http://${server.address.host}:${server.port}',
  );
}
