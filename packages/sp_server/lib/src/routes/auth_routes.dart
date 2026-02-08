import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middleware/auth_middleware.dart';
import '../services/github_oauth_service.dart';
import '../services/jwt_service.dart';
import '../services/user_service.dart';

/// Registers authentication routes under `/api/auth`.
Router authRouter({
  required GitHubOAuthService gitHubOAuthService,
  required JwtService jwtService,
  required UserService userService,
}) {
  final router = Router();

  router.get(
    '/api/auth/github',
    (Request request) => _handleGitHubAuth(request, gitHubOAuthService),
  );

  router.get(
    '/api/auth/github/callback',
    (Request request) => _handleGitHubCallback(
      request,
      gitHubOAuthService,
      jwtService,
      userService,
    ),
  );

  // The /me route is protected by auth middleware.
  final meHandler = const Pipeline()
      .addMiddleware(authMiddleware(jwtService))
      .addHandler((Request request) => _handleMe(request, userService));
  router.get('/api/auth/me', meHandler);

  return router;
}

Response _handleGitHubAuth(Request request, GitHubOAuthService oauthService) {
  final state = _generateState();
  final url = oauthService.getAuthorizationUrl(state);

  return Response.found(url);
}

Future<Response> _handleGitHubCallback(
  Request request,
  GitHubOAuthService oauthService,
  JwtService jwtService,
  UserService userService,
) async {
  final code = request.url.queryParameters['code'];
  if (code == null || code.isEmpty) {
    return Response(
      400,
      body: jsonEncode({'error': 'Missing code parameter'}),
      headers: _jsonHeaders,
    );
  }

  final accessToken = await oauthService.exchangeCode(code);
  if (accessToken == null) {
    return Response(
      502,
      body: jsonEncode({'error': 'Failed to exchange code for token'}),
      headers: _jsonHeaders,
    );
  }

  final userInfo = await oauthService.fetchUserInfo(accessToken);
  if (userInfo == null) {
    return Response(
      502,
      body: jsonEncode({'error': 'Failed to fetch user info from GitHub'}),
      headers: _jsonHeaders,
    );
  }

  final githubId = userInfo['id'] as int;
  final username = userInfo['login'] as String;
  final avatarUrl = userInfo['avatar_url'] as String?;

  final user = userService.findOrCreateUser(
    githubId: githubId,
    githubUsername: username,
    avatarUrl: avatarUrl,
  );

  final token = jwtService.createToken(user.id);

  return Response.ok(
    jsonEncode({'token': token, 'user': user.toJson()}),
    headers: _jsonHeaders,
  );
}

Response _handleMe(Request request, UserService userService) {
  final userId = request.context[userIdContextKey] as String?;
  if (userId == null) {
    return Response(
      401,
      body: jsonEncode({'error': 'Unauthorized'}),
      headers: _jsonHeaders,
    );
  }

  final user = userService.findById(userId);
  if (user == null) {
    return Response(
      404,
      body: jsonEncode({'error': 'User not found'}),
      headers: _jsonHeaders,
    );
  }

  return Response.ok(
    jsonEncode({'user': user.toJson()}),
    headers: _jsonHeaders,
  );
}

String _generateState() {
  final random = Random.secure();
  final values = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(values).replaceAll('=', '');
}

const _jsonHeaders = {'Content-Type': 'application/json'};
