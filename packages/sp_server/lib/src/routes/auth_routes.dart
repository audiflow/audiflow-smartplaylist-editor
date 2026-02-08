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
  // Capture the caller's origin from the Origin or Referer header
  // so we know where to redirect after the OAuth callback.
  final callerOrigin =
      request.headers['origin'] ??
      _extractOrigin(request.headers['referer']) ??
      'http://localhost:8080';

  final nonce = _generateNonce();
  // Encode both nonce and caller origin into the state parameter.
  final statePayload = jsonEncode({'nonce': nonce, 'origin': callerOrigin});
  final state = base64Url.encode(utf8.encode(statePayload));

  final url = oauthService.getAuthorizationUrl(state);

  return Response.found(url);
}

Future<Response> _handleGitHubCallback(
  Request request,
  GitHubOAuthService oauthService,
  JwtService jwtService,
  UserService userService,
) async {
  // Decode the caller origin from the state parameter.
  final stateParam = request.url.queryParameters['state'] ?? '';
  final callerOrigin = _decodeOriginFromState(stateParam);

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
    return Response.found(
      Uri.parse('$callerOrigin/login?error=token_exchange_failed'),
    );
  }

  final userInfo = await oauthService.fetchUserInfo(accessToken);
  if (userInfo == null) {
    return Response.found(
      Uri.parse('$callerOrigin/login?error=user_fetch_failed'),
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

  // Redirect back to the web app with the token in the URL.
  return Response.found(
    Uri.parse('$callerOrigin/login?token=${Uri.encodeComponent(token)}'),
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

/// Decodes the caller origin from the base64-encoded state parameter.
/// Falls back to localhost if decoding fails.
String _decodeOriginFromState(String state) {
  try {
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(state)));
    final payload = jsonDecode(decoded) as Map<String, dynamic>;
    return payload['origin'] as String? ?? 'http://localhost:8080';
  } on Object {
    return 'http://localhost:8080';
  }
}

/// Extracts the origin (scheme + host + port) from a full URL.
String? _extractOrigin(String? url) {
  if (url == null) return null;
  try {
    final uri = Uri.parse(url);
    return uri.origin;
  } on Object {
    return null;
  }
}

String _generateNonce() {
  final random = Random.secure();
  final values = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(values).replaceAll('=', '');
}

const _jsonHeaders = {'Content-Type': 'application/json'};
