import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/auth_routes.dart';
import 'package:sp_server/src/services/github_oauth_service.dart';
import 'package:sp_server/src/services/jwt_service.dart';
import 'package:sp_server/src/services/user_service.dart';

void main() {
  group('Auth routes', () {
    late JwtService jwtService;
    late UserService userService;
    late GitHubOAuthService oauthService;
    late Handler handler;

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
          Uri.parse('http://localhost/api/auth/github'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(302));
        final location = response.headers['location']!;
        final redirectUri = Uri.parse(location);
        expect(redirectUri.host, equals('github.com'));
        expect(redirectUri.path, equals('/login/oauth/authorize'));
        expect(redirectUri.queryParameters['client_id'], equals('test-client'));
      });

      test('encodes caller origin in state parameter', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/auth/github'),
          headers: {'origin': 'http://localhost:3000'},
        );

        final response = await handler(request);

        final location = response.headers['location']!;
        final redirectUri = Uri.parse(location);
        final state = redirectUri.queryParameters['state']!;
        final decoded = utf8.decode(
          base64Url.decode(base64Url.normalize(state)),
        );
        final payload = jsonDecode(decoded) as Map<String, dynamic>;
        expect(payload['origin'], equals('http://localhost:3000'));
        expect(payload['nonce'], isNotEmpty);
      });
    });

    group('GET /api/auth/github/callback', () {
      test('returns 400 when code is missing', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/auth/github/callback'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('redirects to caller origin with token on valid code', () async {
        // Build a state with embedded origin.
        final statePayload = jsonEncode({
          'nonce': 'test',
          'origin': 'http://localhost:9999',
        });
        final state = base64Url.encode(utf8.encode(statePayload));

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost'
            '/api/auth/github/callback?code=valid&state=$state',
          ),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(302));
        final location = response.headers['location']!;
        final redirectUri = Uri.parse(location);
        expect(redirectUri.origin, equals('http://localhost:9999'));
        expect(redirectUri.path, equals('/login'));
        expect(redirectUri.queryParameters['token'], isNotEmpty);
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

        final statePayload = jsonEncode({
          'nonce': 'test',
          'origin': 'http://localhost:9999',
        });
        final state = base64Url.encode(utf8.encode(statePayload));

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost'
            '/api/auth/github/callback?code=bad&state=$state',
          ),
        );

        final response = await failHandler(request);

        expect(response.statusCode, equals(302));
        final location = response.headers['location']!;
        expect(location, contains('error=token_exchange_failed'));
        expect(location, contains('localhost:9999'));
      });
    });

    group('GET /api/auth/me', () {
      test('returns user when authenticated', () async {
        // First create a user via the callback flow.
        final statePayload = jsonEncode({
          'nonce': 'test',
          'origin': 'http://localhost:9999',
        });
        final state = base64Url.encode(utf8.encode(statePayload));

        final callbackReq = Request(
          'GET',
          Uri.parse(
            'http://localhost'
            '/api/auth/github/callback?code=x&state=$state',
          ),
        );
        final callbackResp = await handler(callbackReq);
        // Extract token from the redirect URL.
        final location = callbackResp.headers['location']!;
        final redirectUri = Uri.parse(location);
        final token = redirectUri.queryParameters['token']!;

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
