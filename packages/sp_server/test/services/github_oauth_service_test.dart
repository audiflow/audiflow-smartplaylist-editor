import 'package:test/test.dart';

import 'package:sp_server/src/services/github_oauth_service.dart';

void main() {
  group('GitHubOAuthService', () {
    group('getAuthorizationUrl', () {
      test('builds valid GitHub authorize URL', () {
        final service = GitHubOAuthService(
          clientId: 'test-client-id',
          clientSecret: 'test-secret',
          redirectUri: 'http://localhost:8080/callback',
        );

        final url = service.getAuthorizationUrl('random-state');

        expect(url.scheme, equals('https'));
        expect(url.host, equals('github.com'));
        expect(url.path, equals('/login/oauth/authorize'));
        expect(url.queryParameters['client_id'], equals('test-client-id'));
        expect(
          url.queryParameters['redirect_uri'],
          equals('http://localhost:8080/callback'),
        );
        expect(url.queryParameters['scope'], equals('read:user'));
        expect(url.queryParameters['state'], equals('random-state'));
      });
    });

    group('exchangeCode', () {
      test('returns access token on success', () async {
        final service = GitHubOAuthService(
          clientId: 'cid',
          clientSecret: 'csec',
          redirectUri: 'http://localhost/cb',
          httpPost: (url, {headers, body}) async {
            return HttpPostResponse(
              statusCode: 200,
              body: '{"access_token":"gho_abc123"}',
            );
          },
        );

        final token = await service.exchangeCode('auth-code');
        expect(token, equals('gho_abc123'));
      });

      test('returns null on non-200 response', () async {
        final service = GitHubOAuthService(
          clientId: 'cid',
          clientSecret: 'csec',
          redirectUri: 'http://localhost/cb',
          httpPost: (url, {headers, body}) async {
            return HttpPostResponse(
              statusCode: 401,
              body: '{"error":"bad_code"}',
            );
          },
        );

        final token = await service.exchangeCode('bad');
        expect(token, isNull);
      });
    });

    group('fetchUserInfo', () {
      test('returns user map on success', () async {
        final service = GitHubOAuthService(
          clientId: 'cid',
          clientSecret: 'csec',
          redirectUri: 'http://localhost/cb',
          httpGet: (url, {headers}) async {
            return HttpGetResponse(
              statusCode: 200,
              body:
                  '{'
                  '"id":42,'
                  '"login":"octocat",'
                  '"avatar_url":"https://img/avatar"'
                  '}',
            );
          },
        );

        final info = await service.fetchUserInfo('gho_token');

        expect(info, isNotNull);
        expect(info!['id'], equals(42));
        expect(info['login'], equals('octocat'));
        expect(info['avatar_url'], equals('https://img/avatar'));
      });

      test('returns null on non-200 response', () async {
        final service = GitHubOAuthService(
          clientId: 'cid',
          clientSecret: 'csec',
          redirectUri: 'http://localhost/cb',
          httpGet: (url, {headers}) async {
            return HttpGetResponse(
              statusCode: 401,
              body: '{"message":"Bad credentials"}',
            );
          },
        );

        final info = await service.fetchUserInfo('bad');
        expect(info, isNull);
      });
    });
  });
}
