import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/auth_routes.dart';
import 'package:sp_server/src/services/github_oauth_service.dart';
import 'package:sp_server/src/services/jwt_service.dart';
import 'package:sp_server/src/services/user_service.dart';

/// Builds a fake OAuth state containing [redirectUri].
String _fakeState(String redirectUri) {
  final payload = jsonEncode({
    'nonce': 'test-nonce',
    'redirect_uri': redirectUri,
  });
  return base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
}

void main() {
  group('Auth routes', () {
    late JwtService jwtService;
    late UserService userService;
    late GitHubOAuthService oauthService;
    late Handler handler;

    const frontendLogin = 'http://localhost:3000/login';

    setUp(() {
      jwtService = JwtService(secret: 'test-secret');
      userService = UserService();

      oauthService = GitHubOAuthService(
        clientId: 'test-client',
        clientSecret: 'test-secret',
        redirectUri: 'http://localhost/callback',
        httpPost: (url, {headers, body}) async {
          return HttpPostResponse(
            statusCode: 200,
            body: '{"access_token":"gho_mock"}',
          );
        },
        httpGet: (url, {headers}) async {
          return HttpGetResponse(
            statusCode: 200,
            body:
                '{'
                '"id":99,'
                '"login":"testuser",'
                '"avatar_url":"https://img/test"'
                '}',
          );
        },
      );

      handler = authRouter(
        gitHubOAuthService: oauthService,
        jwtService: jwtService,
        userService: userService,
      ).call;
    });

    group('GET /api/auth/github', () {
      test('redirects to GitHub authorize URL', () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/auth/github'
            '?redirect_uri=${Uri.encodeComponent(frontendLogin)}',
          ),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(302));
        final location = response.headers['location']!;
        final redirectUri = Uri.parse(location);
        expect(redirectUri.host, equals('github.com'));
        expect(redirectUri.path, equals('/login/oauth/authorize'));
        expect(redirectUri.queryParameters['client_id'], equals('test-client'));

        // The state should contain the redirect_uri.
        final state = redirectUri.queryParameters['state']!;
        final padded = state.padRight(
          state.length + (4 - state.length % 4) % 4,
          '=',
        );
        final decoded = utf8.decode(base64Url.decode(padded));
        final payload = jsonDecode(decoded) as Map<String, dynamic>;
        expect(payload['redirect_uri'], equals(frontendLogin));
      });

      test('returns 400 when redirect_uri is missing', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/auth/github'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });
    });

    group('GET /api/auth/github/callback', () {
      test('returns 400 when state is missing', () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost'
            '/api/auth/github/callback?code=valid',
          ),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('redirects to frontend with error when code is missing', () async {
        final state = _fakeState(frontendLogin);
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost'
            '/api/auth/github/callback?state=$state',
          ),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(302));
        final location = Uri.parse(response.headers['location']!);
        expect(location.queryParameters['error'], equals('missing_code'));
      });

      test('redirects to frontend with both tokens on valid code', () async {
        final state = _fakeState(frontendLogin);
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost'
            '/api/auth/github/callback'
            '?code=valid&state=$state',
          ),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(302));
        final location = Uri.parse(response.headers['location']!);
        expect(location.host, equals('localhost'));
        expect(location.port, equals(3000));
        expect(location.path, equals('/login'));
        expect(location.queryParameters['token'], isNotEmpty);
        expect(location.queryParameters['refresh_token'], isNotEmpty);
      });

      test('redirects with error when token exchange fails', () async {
        final failOAuth = GitHubOAuthService(
          clientId: 'c',
          clientSecret: 's',
          redirectUri: 'http://localhost/cb',
          httpPost: (url, {headers, body}) async {
            return HttpPostResponse(statusCode: 401, body: '{"error":"bad"}');
          },
        );
        final failHandler = authRouter(
          gitHubOAuthService: failOAuth,
          jwtService: jwtService,
          userService: userService,
        ).call;

        final state = _fakeState(frontendLogin);
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost'
            '/api/auth/github/callback'
            '?code=bad&state=$state',
          ),
        );

        final response = await failHandler(request);

        expect(response.statusCode, equals(302));
        final location = Uri.parse(response.headers['location']!);
        expect(
          location.queryParameters['error'],
          equals('token_exchange_failed'),
        );
      });
    });

    group('POST /api/auth/refresh', () {
      test('returns new token pair for valid refresh token', () async {
        final refreshToken = jwtService.createRefreshToken('user-1');
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['accessToken'], isNotEmpty);
        expect(body['refreshToken'], isNotEmpty);

        // Verify the new access token is valid.
        final userId = jwtService.validateToken(
          body['accessToken'] as String,
          requiredType: JwtService.accessTokenType,
        );
        expect(userId, equals('user-1'));
      });

      test('rejects expired refresh token', () async {
        final expiredToken = jwtService.createRefreshToken(
          'user-1',
          expiry: const Duration(seconds: -1),
        );
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': expiredToken}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });

      test('rejects invalid refresh token', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': 'garbage.token.value'}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });

      test('rejects access token used as refresh token', () async {
        final accessToken = jwtService.createToken('user-1');
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': accessToken}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 400 when refreshToken is missing', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': 'wrong-field'}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });
    });

    group('GET /api/auth/me', () {
      test('returns user when authenticated', () async {
        // First create a user via the callback flow.
        final state = _fakeState(frontendLogin);
        final callbackReq = Request(
          'GET',
          Uri.parse(
            'http://localhost'
            '/api/auth/github/callback'
            '?code=x&state=$state',
          ),
        );
        final callbackResp = await handler(callbackReq);
        final location = Uri.parse(callbackResp.headers['location']!);
        final token = location.queryParameters['token']!;

        // Now call /me with the token.
        final meReq = Request(
          'GET',
          Uri.parse('http://localhost/api/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        );

        final meResp = await handler(meReq);

        expect(meResp.statusCode, equals(200));
        final meBody =
            jsonDecode(await meResp.readAsString()) as Map<String, dynamic>;
        final user = meBody['user'] as Map<String, dynamic>;
        expect(user['githubUsername'], equals('testuser'));
      });

      test('returns 401 without auth header', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/auth/me'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });
    });
  });
}
