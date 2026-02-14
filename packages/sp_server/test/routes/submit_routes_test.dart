import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/submit_routes.dart';
import 'package:sp_server/src/services/api_key_service.dart';
import 'package:sp_server/src/services/github_app_service.dart';
import 'package:sp_server/src/services/jwt_service.dart';

/// A minimal valid playlist for testing.
Map<String, dynamic> _validPlaylist() => {
  'id': 'seasons',
  'displayName': 'Seasons',
  'resolverType': 'rss',
};

/// A valid pattern meta for testing.
Map<String, dynamic> _validPatternMeta() => {
  'version': 1,
  'id': 'test-podcast',
  'feedUrls': ['https://example.com/feed.xml'],
  'playlists': ['seasons'],
};

/// Builds a mock GitHubAppService that records
/// calls and returns predictable responses.
GitHubAppService _mockGitHubService({
  String defaultSha = 'abc123',
  String prUrl = 'https://github.com/o/r/pull/1',
  bool failOnGetSha = false,
  bool failOnCreateBranch = false,
  bool failOnCommit = false,
  bool failOnCreatePr = false,
}) {
  return GitHubAppService(
    token: 'test-token',
    owner: 'owner',
    repo: 'repo',
    httpFn: (method, url, {headers, body}) async {
      final path = url.path;

      // GET default branch SHA
      if (method == 'GET' && path.contains('git/ref')) {
        if (failOnGetSha) {
          return GitHubHttpResponse(
            statusCode: 500,
            body: '{"message":"Server Error"}',
          );
        }
        return GitHubHttpResponse(
          statusCode: 200,
          body: jsonEncode({
            'ref': 'refs/heads/main',
            'object': {'sha': defaultSha, 'type': 'commit'},
          }),
        );
      }

      // POST create branch
      if (method == 'POST' && path.contains('git/refs')) {
        if (failOnCreateBranch) {
          return GitHubHttpResponse(
            statusCode: 422,
            body: '{"message":"Reference exists"}',
          );
        }
        return GitHubHttpResponse(
          statusCode: 201,
          body: '{"ref":"refs/heads/new-branch"}',
        );
      }

      // PUT commit file
      if (method == 'PUT' && path.contains('contents/')) {
        if (failOnCommit) {
          return GitHubHttpResponse(
            statusCode: 500,
            body: '{"message":"Commit failed"}',
          );
        }
        return GitHubHttpResponse(
          statusCode: 201,
          body: '{"content":{"path":"test.json"}}',
        );
      }

      // POST create PR
      if (method == 'POST' && path.contains('pulls')) {
        if (failOnCreatePr) {
          return GitHubHttpResponse(
            statusCode: 422,
            body: '{"message":"Validation Failed"}',
          );
        }
        return GitHubHttpResponse(
          statusCode: 201,
          body: jsonEncode({'html_url': prUrl, 'number': 1}),
        );
      }

      return GitHubHttpResponse(
        statusCode: 404,
        body: '{"message":"Not Found"}',
      );
    },
  );
}

void main() {
  group('submitRouter', () {
    late JwtService jwtService;
    late ApiKeyService apiKeyService;
    late String validToken;

    setUp(() {
      jwtService = JwtService(secret: 'test-secret');
      apiKeyService = ApiKeyService();
      validToken = jwtService.createToken('user-1');
    });

    group('POST /api/configs/submit', () {
      test('returns 401 without authentication', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          body: jsonEncode({'patternId': 'test', 'playlist': _validPlaylist()}),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(401));
      });

      test('creates PR successfully with playlist only', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(
            prUrl: 'https://github.com/o/r/pull/42',
          ),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test-podcast',
            'playlist': _validPlaylist(),
            'description': 'Add test podcast playlist',
          }),
        );

        final response = await router.call(request);

        expect(response.statusCode, equals(201));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['prUrl'], equals('https://github.com/o/r/pull/42'));
        expect(body['branch'], contains('smartplaylist/test-podcast-'));
      });

      test('creates PR with pattern meta and playlist', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test-podcast',
            'playlist': _validPlaylist(),
            'patternMeta': _validPatternMeta(),
            'isNewPattern': true,
            'description': 'Add new podcast pattern',
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(201));
      });

      test('uses playlistId when provided', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test-podcast',
            'playlistId': 'custom-id',
            'playlist': _validPlaylist(),
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(201));
      });

      test('accepts API key authentication', () async {
        final keyResult = apiKeyService.generateKey('user-1', 'Test Key');

        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'X-API-Key': keyResult.plaintext,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test-podcast',
            'playlist': _validPlaylist(),
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(201));
      });

      test('returns 400 for empty body', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {'Authorization': 'Bearer $validToken'},
          body: '',
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('empty'));
      });

      test('returns 400 for invalid JSON', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: '{invalid json',
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('Invalid JSON'));
      });

      test('returns 400 for missing patternId', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'playlist': _validPlaylist()}),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('patternId'));
      });

      test('returns 400 for empty patternId', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'patternId': '', 'playlist': _validPlaylist()}),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('patternId'));
      });

      test('returns 400 for missing playlist', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'patternId': 'test'}),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('playlist'));
      });

      test('returns 400 for invalid playlist', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        // Playlist without required fields.
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test',
            'playlist': {'id': 'test'},
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(400));
      });

      test('returns 502 when branch creation fails', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(failOnCreateBranch: true),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test-podcast',
            'playlist': _validPlaylist(),
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(502));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('GitHub API error'));
      });

      test('returns 502 when PR creation fails', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(failOnCreatePr: true),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test-podcast',
            'playlist': _validPlaylist(),
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(502));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('GitHub API error'));
      });

      test('returns 502 when commit fails', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(failOnCommit: true),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test-podcast',
            'playlist': _validPlaylist(),
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(502));
      });

      test('returns 502 when getSha fails', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(failOnGetSha: true),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test-podcast',
            'playlist': _validPlaylist(),
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(502));
      });

      test('uses default description when omitted', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test-podcast',
            'playlist': _validPlaylist(),
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(201));
      });

      test('returns 400 for non-object body', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: '"just a string"',
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('JSON object'));
      });

      test('has JSON content type', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test-podcast',
            'playlist': _validPlaylist(),
          }),
        );

        final response = await router.call(request);
        expect(response.headers['content-type'], equals('application/json'));
      });
    });
  });
}
