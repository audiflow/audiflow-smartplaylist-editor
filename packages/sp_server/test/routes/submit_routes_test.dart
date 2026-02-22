import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_shared/sp_shared.dart';
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

/// Records GitHub API calls for assertion.
class _CallLog {
  final String method;
  final String path;
  final Map<String, dynamic>? body;

  _CallLog(this.method, this.path, this.body);
}

/// Builds a mock GitHubAppService that records
/// calls and returns predictable responses.
///
/// [calls] collects every HTTP call for inspection.
GitHubAppService _mockGitHubService({
  String defaultSha = 'abc123',
  String prUrl = 'https://github.com/o/r/pull/1',
  bool failOnGetSha = false,
  bool failOnCreateBranch = false,
  bool failOnCommit = false,
  bool failOnCreatePr = false,
  List<_CallLog>? calls,
}) {
  return GitHubAppService(
    token: 'test-token',
    owner: 'owner',
    repo: 'repo',
    httpFn: (method, url, {headers, body}) async {
      final path = url.path;
      final parsedBody = body is String
          ? jsonDecode(body) as Map<String, dynamic>?
          : null;
      calls?.add(_CallLog(method, path, parsedBody));

      // GET file SHA (contents endpoint with ref query)
      if (method == 'GET' && path.contains('contents/')) {
        return GitHubHttpResponse(
          statusCode: 404,
          body: '{"message":"Not Found"}',
        );
      }

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

/// Extracts committed file content from a PUT call log entry.
String _decodeCommittedContent(_CallLog call) {
  final encoded = call.body!['content'] as String;
  return utf8.decode(base64Decode(encoded));
}

void main() {
  group('submitRouter', () {
    late JwtService jwtService;
    late ApiKeyService apiKeyService;
    late SmartPlaylistValidator validator;
    late String validToken;

    setUp(() {
      jwtService = JwtService(secret: 'test-secret');
      apiKeyService = ApiKeyService();
      validator = SmartPlaylistValidator();
      validToken = jwtService.createToken('user-1');
    });

    group('POST /api/configs/submit', () {
      test('returns 401 without authentication', () async {
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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
          validator: validator,
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

    group('meta.json structure', () {
      test('always commits meta.json even without patternMeta', () async {
        final calls = <_CallLog>[];
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(calls: calls),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
          validator: validator,
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

        // Find the meta.json commit.
        final metaCommits = calls.where(
          (c) => c.method == 'PUT' && c.path.contains('meta.json'),
        );
        expect(metaCommits, hasLength(1));

        final metaContent = _decodeCommittedContent(metaCommits.first);
        final metaJson = jsonDecode(metaContent) as Map<String, dynamic>;
        expect(metaJson['version'], equals(1));
        expect(metaJson['id'], equals('test-podcast'));
        expect(metaJson['feedUrls'], equals([]));
        expect(metaJson['playlists'], equals(['seasons']));
      });

      test('builds complete meta from client patternMeta fields', () async {
        final calls = <_CallLog>[];
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(calls: calls),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
          validator: validator,
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
            'patternMeta': {
              'feedUrls': ['https://example.com/feed.xml'],
              'podcastGuid': 'abc-123',
              'yearGroupedEpisodes': true,
            },
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(201));

        final metaCommit = calls.firstWhere(
          (c) => c.method == 'PUT' && c.path.contains('meta.json'),
        );
        final metaJson =
            jsonDecode(_decodeCommittedContent(metaCommit))
                as Map<String, dynamic>;
        expect(metaJson['version'], equals(1));
        expect(metaJson['id'], equals('test-podcast'));
        expect(metaJson['podcastGuid'], equals('abc-123'));
        expect(metaJson['feedUrls'], equals(['https://example.com/feed.xml']));
        expect(metaJson['yearGroupedEpisodes'], isTrue);
        expect(metaJson['playlists'], equals(['seasons']));
      });

      test('meta playlists field lists all submitted playlist IDs', () async {
        final calls = <_CallLog>[];
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(calls: calls),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
          validator: validator,
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
            'playlists': [
              _validPlaylist(),
              {
                'id': 'bonus',
                'displayName': 'Bonus',
                'resolverType': 'category',
              },
            ],
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(201));

        final metaCommit = calls.firstWhere(
          (c) => c.method == 'PUT' && c.path.contains('meta.json'),
        );
        final metaJson =
            jsonDecode(_decodeCommittedContent(metaCommit))
                as Map<String, dynamic>;
        expect(metaJson['playlists'], equals(['seasons', 'bonus']));
      });
    });

    group('JSON normalization', () {
      test('strips default values from committed playlist JSON', () async {
        final calls = <_CallLog>[];
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(calls: calls),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
          validator: validator,
        );

        // Client sends playlist with explicit defaults
        // (priority=0, groups=[], showDateRange=false).
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/submit'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'patternId': 'test-podcast',
            'playlist': {
              'id': 'seasons',
              'displayName': 'Seasons',
              'resolverType': 'rss',
              'priority': 0,
              'showDateRange': false,
              'episodeYearHeaders': false,
            },
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(201));

        final playlistCommit = calls.firstWhere(
          (c) => c.method == 'PUT' && c.path.contains('playlists/seasons.json'),
        );
        final playlistJson =
            jsonDecode(_decodeCommittedContent(playlistCommit))
                as Map<String, dynamic>;

        // Default values should be stripped.
        expect(playlistJson.containsKey('priority'), isFalse);
        expect(playlistJson.containsKey('showDateRange'), isFalse);
        expect(playlistJson.containsKey('episodeYearHeaders'), isFalse);

        // Required fields remain.
        expect(playlistJson['id'], equals('seasons'));
        expect(playlistJson['displayName'], equals('Seasons'));
        expect(playlistJson['resolverType'], equals('rss'));
      });

      test('preserves non-default values in committed JSON', () async {
        final calls = <_CallLog>[];
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(calls: calls),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
          validator: validator,
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
            'playlist': {
              'id': 'seasons',
              'displayName': 'Seasons',
              'resolverType': 'rss',
              'priority': 5,
              'showDateRange': true,
              'titleFilter': r'S\d+',
            },
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(201));

        final playlistCommit = calls.firstWhere(
          (c) => c.method == 'PUT' && c.path.contains('playlists/seasons.json'),
        );
        final playlistJson =
            jsonDecode(_decodeCommittedContent(playlistCommit))
                as Map<String, dynamic>;

        expect(playlistJson['priority'], equals(5));
        expect(playlistJson['showDateRange'], isTrue);
        expect(playlistJson['titleFilter'], equals(r'S\d+'));
      });

      test('meta.json omits yearGroupedEpisodes when false', () async {
        final calls = <_CallLog>[];
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(calls: calls),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
          validator: validator,
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
            'patternMeta': {
              'feedUrls': ['https://example.com/feed.xml'],
              'yearGroupedEpisodes': false,
            },
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(201));

        final metaCommit = calls.firstWhere(
          (c) => c.method == 'PUT' && c.path.contains('meta.json'),
        );
        final metaJson =
            jsonDecode(_decodeCommittedContent(metaCommit))
                as Map<String, dynamic>;
        expect(metaJson.containsKey('yearGroupedEpisodes'), isFalse);
      });
    });

    group('update existing PR', () {
      test('appends commits to existing branch without creating PR', () async {
        final calls = <_CallLog>[];
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(calls: calls),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
          validator: validator,
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
            'branch': 'smartplaylist/test-podcast-12345',
          }),
        );

        final response = await router.call(request);
        expect(response.statusCode, equals(200));

        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['branch'], equals('smartplaylist/test-podcast-12345'));
        expect(body.containsKey('prUrl'), isFalse);

        // Should NOT have called getDefaultBranchSha or createBranch.
        final branchCreations = calls.where(
          (c) => c.method == 'POST' && c.path.contains('git/refs'),
        );
        expect(branchCreations, isEmpty);

        // Should NOT have called createPullRequest.
        final prCreations = calls.where(
          (c) => c.method == 'POST' && c.path.contains('pulls'),
        );
        expect(prCreations, isEmpty);

        // Should have committed files.
        final commits = calls.where(
          (c) => c.method == 'PUT' && c.path.contains('contents/'),
        );
        expect(commits.length, equals(2)); // playlist + meta
      });

      test('new submission creates branch and PR', () async {
        final calls = <_CallLog>[];
        final router = submitRouter(
          gitHubAppService: _mockGitHubService(
            calls: calls,
            prUrl: 'https://github.com/o/r/pull/99',
          ),
          jwtService: jwtService,
          apiKeyService: apiKeyService,
          validator: validator,
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

        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['prUrl'], equals('https://github.com/o/r/pull/99'));
        expect(body['branch'], contains('smartplaylist/test-podcast-'));

        // Should have called createBranch.
        final branchCreations = calls.where(
          (c) => c.method == 'POST' && c.path.contains('git/refs'),
        );
        expect(branchCreations, hasLength(1));

        // Should have called createPullRequest.
        final prCreations = calls.where(
          (c) => c.method == 'POST' && c.path.contains('pulls'),
        );
        expect(prCreations, hasLength(1));
      });
    });
  });
}
