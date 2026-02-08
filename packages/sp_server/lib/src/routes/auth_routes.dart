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
  final redirectUri = request.url.queryParameters['redirect_uri'];
  if (redirectUri == null || redirectUri.isEmpty) {
    return Response(
      400,
      body: jsonEncode({'error': 'Missing redirect_uri parameter'}),
      headers: _jsonHeaders,
    );
  }

  final state = _encodeState(redirectUri);
  final url = oauthService.getAuthorizationUrl(state);

  return Response.found(url);
}

Future<Response> _handleGitHubCallback(
  Request request,
  GitHubOAuthService oauthService,
  JwtService jwtService,
  UserService userService,
) async {
  final stateParam = request.url.queryParameters['state'];
  final redirectUri = _decodeRedirectUri(stateParam);
  if (redirectUri == null) {
    return Response(
      400,
      body: jsonEncode({'error': 'Invalid or missing state'}),
      headers: _jsonHeaders,
    );
  }

  final code = request.url.queryParameters['code'];
  if (code == null || code.isEmpty) {
    return Response.found(
      Uri.parse('$redirectUri?error=missing_code'),
    );
  }

  final accessToken = await oauthService.exchangeCode(code);
  if (accessToken == null) {
    return Response.found(
      Uri.parse('$redirectUri?error=token_exchange_failed'),
    );
  }

  final userInfo = await oauthService.fetchUserInfo(accessToken);
  if (userInfo == null) {
    return Response.found(
      Uri.parse('$redirectUri?error=user_fetch_failed'),
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

  return Response.found(
    Uri.parse('$redirectUri?token=$token'),
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

/// Encodes [redirectUri] and a CSRF nonce into a
/// base64url-encoded JSON string for the OAuth state
/// parameter.
String _encodeState(String redirectUri) {
  final random = Random.secure();
  final nonce = List<int>.generate(16, (_) => random.nextInt(256));
  final payload = jsonEncode({
    'nonce': base64Url.encode(nonce),
    'redirect_uri': redirectUri,
  });
  return base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
}

/// Decodes the OAuth state parameter and returns the
/// embedded redirect URI, or `null` if the state is
/// missing or malformed.
String? _decodeRedirectUri(String? state) {
  if (state == null || state.isEmpty) return null;
  try {
    // Re-pad the base64url string.
    final padded = state.padRight(
      state.length + (4 - state.length % 4) % 4,
      '=',
    );
    final decoded = utf8.decode(base64Url.decode(padded));
    final payload = jsonDecode(decoded) as Map<String, dynamic>;
    return payload['redirect_uri'] as String?;
  } on Object {
    return null;
  }
}

const _jsonHeaders = {'Content-Type': 'application/json'};
