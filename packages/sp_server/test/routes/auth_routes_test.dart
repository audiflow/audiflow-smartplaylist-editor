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

      test('returns JWT and user on valid code', () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost'
            '/api/auth/github/callback?code=valid',
          ),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['token'], isNotEmpty);
        final user = body['user'] as Map<String, dynamic>;
        expect(user['githubId'], equals(99));
        expect(user['githubUsername'], equals('testuser'));
      });

      test('returns 502 when token exchange fails', () async {
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

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost'
            '/api/auth/github/callback?code=bad',
          ),
        );

        final response = await failHandler(request);

        expect(response.statusCode, equals(502));
      });
    });

    group('GET /api/auth/me', () {
      test('returns user when authenticated', () async {
        // First create a user via the callback flow.
        final callbackReq = Request(
          'GET',
          Uri.parse(
            'http://localhost'
            '/api/auth/github/callback?code=x',
          ),
        );
        final callbackResp = await handler(callbackReq);
        final callbackBody =
            jsonDecode(await callbackResp.readAsString())
                as Map<String, dynamic>;
        final token = callbackBody['token'] as String;

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
