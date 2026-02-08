import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/config_routes.dart';
import 'package:sp_server/src/services/api_key_service.dart';
import 'package:sp_server/src/services/config_repository.dart';
import 'package:sp_server/src/services/jwt_service.dart';

const _sampleConfigJson = '''
{
  "version": 1,
  "patterns": [
    {
      "id": "podcast-a",
      "podcastGuid": "guid-a",
      "feedUrlPatterns": ["https://example\\\\.com/feed\\\\.xml"],
      "playlists": [
        {
          "id": "seasons",
          "displayName": "Seasons",
          "resolverType": "rss"
        }
      ]
    },
    {
      "id": "podcast-b",
      "playlists": [
        {
          "id": "by-year",
          "displayName": "By Year",
          "resolverType": "year"
        },
        {
          "id": "categories",
          "displayName": "Categories",
          "resolverType": "category",
          "groups": [
            {
              "id": "main",
              "displayName": "Main",
              "pattern": "^Main"
            },
            {
              "id": "bonus",
              "displayName": "Bonus"
            }
          ]
        }
      ]
    }
  ]
}
''';

void main() {
  group('configRouter', () {
    late JwtService jwtService;
    late ApiKeyService apiKeyService;
    late ConfigRepository configRepository;
    late Handler handler;
    late String validToken;

    setUp(() {
      jwtService = JwtService(secret: 'test-secret');
      apiKeyService = ApiKeyService();
      validToken = jwtService.createToken('user-1');

      configRepository = ConfigRepository(
        httpGet: (_) async => _sampleConfigJson,
        configRepoUrl: 'https://example.com/configs.json',
      );

      final router = configRouter(
        configRepository: configRepository,
        jwtService: jwtService,
        apiKeyService: apiKeyService,
      );
      handler = router.call;
    });

    group('GET /api/configs', () {
      test('returns 401 without authentication', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns list of config summaries', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        final configs = body['configs'] as List;
        expect(configs.length, equals(2));

        final first = configs[0] as Map<String, dynamic>;
        expect(first['id'], equals('podcast-a'));
        expect(first['podcastGuid'], equals('guid-a'));
        expect(first['playlistCount'], equals(1));

        final second = configs[1] as Map<String, dynamic>;
        expect(second['id'], equals('podcast-b'));
        expect(second['playlistCount'], equals(2));
      });

      test('accepts API key authentication', () async {
        final keyResult = apiKeyService.generateKey('user-1', 'Test Key');

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs'),
          headers: {'X-API-Key': keyResult.plaintext},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
      });

      test('returns 502 on fetch failure', () async {
        final failingRepo = ConfigRepository(
          httpGet: (_) async {
            throw Exception('Network error');
          },
          configRepoUrl: 'https://example.com/fail',
        );

        final failRouter = configRouter(
          configRepository: failingRepo,
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await failRouter.call(request);

        expect(response.statusCode, equals(502));
      });

      test('has JSON content type', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.headers['content-type'], equals('application/json'));
      });
    });

    group('GET /api/configs/<id>', () {
      test('returns config by ID', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/podcast-a'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['id'], equals('podcast-a'));
        expect(body['podcastGuid'], equals('guid-a'));
        final playlists = body['playlists'] as List;
        expect(playlists.length, equals(1));
      });

      test('returns 404 for unknown ID', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/nonexistent'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(404));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('not found'));
      });

      test('returns 401 without authentication', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/podcast-a'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });
    });

    group('POST /api/configs/validate', () {
      test('accepts valid config', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/validate'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: _sampleConfigJson,
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['valid'], isTrue);
        expect(body['errors'], isEmpty);
      });

      test('returns errors for invalid config', () async {
        final invalidJson = jsonEncode({
          'version': 99,
          'patterns': 'not-an-array',
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/validate'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: invalidJson,
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['valid'], isFalse);
        final errors = body['errors'] as List;
        expect(errors, isNotEmpty);
      });

      test('returns error for empty body', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/validate'),
          headers: {'Authorization': 'Bearer $validToken'},
          body: '',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('empty'));
      });

      test('returns errors for missing fields', () async {
        final invalidJson = jsonEncode({
          'version': 1,
          'patterns': [
            {'playlists': []},
          ],
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/validate'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: invalidJson,
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['valid'], isFalse);
        final errors = body['errors'] as List;
        expect(errors, contains(contains('id')));
      });
    });

    group('POST /api/configs/preview', () {
      test('returns grouping results', () async {
        final previewBody = jsonEncode({
          'config': {
            'id': 'test',
            'playlists': [
              {
                'id': 'seasons',
                'displayName': 'Seasons',
                'resolverType': 'rss',
              },
            ],
          },
          'episodes': [
            {
              'id': 1,
              'title': 'S1E1 Pilot',
              'seasonNumber': 1,
              'episodeNumber': 1,
            },
            {
              'id': 2,
              'title': 'S1E2 Next',
              'seasonNumber': 1,
              'episodeNumber': 2,
            },
            {
              'id': 3,
              'title': 'S2E1 Return',
              'seasonNumber': 2,
              'episodeNumber': 1,
            },
          ],
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: previewBody,
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        final playlists = body['playlists'] as List;
        expect(playlists.length, equals(2));

        final season1 = playlists[0] as Map<String, dynamic>;
        expect(season1['displayName'], equals('Season 1'));
        expect((season1['episodeIds'] as List).length, equals(2));

        final season2 = playlists[1] as Map<String, dynamic>;
        expect(season2['displayName'], equals('Season 2'));
        expect((season2['episodeIds'] as List).length, equals(1));

        expect(body['resolverType'], equals('rss'));
      });

      test('returns empty result with no episodes', () async {
        final previewBody = jsonEncode({
          'config': {
            'id': 'test',
            'playlists': [
              {
                'id': 'seasons',
                'displayName': 'Seasons',
                'resolverType': 'rss',
              },
            ],
          },
          'episodes': <Map<String, dynamic>>[],
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: previewBody,
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        final playlists = body['playlists'] as List;
        expect(playlists, isEmpty);
        expect(body['resolverType'], isNull);
      });

      test('returns 400 for empty body', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          headers: {'Authorization': 'Bearer $validToken'},
          body: '',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('returns 400 for missing config', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'episodes': []}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('config'));
      });

      test('returns 400 for missing episodes', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'config': {
              'id': 'test',
              'playlists': [
                {'id': 's', 'displayName': 'S', 'resolverType': 'rss'},
              ],
            },
          }),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('episodes'));
      });

      test('returns 400 for invalid JSON', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: '{invalid json',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('returns 401 without auth', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          body: '{}',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });

      test('handles ungrouped episodes', () async {
        final previewBody = jsonEncode({
          'config': {
            'id': 'test',
            'playlists': [
              {
                'id': 'seasons',
                'displayName': 'Seasons',
                'resolverType': 'rss',
              },
            ],
          },
          'episodes': [
            {
              'id': 1,
              'title': 'Episode with season',
              'seasonNumber': 1,
              'episodeNumber': 1,
            },
            {'id': 2, 'title': 'Episode without season'},
          ],
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: previewBody,
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        final ungrouped = body['ungroupedEpisodeIds'] as List;
        expect(ungrouped, contains(2));
      });

      test('has JSON content type', () async {
        final previewBody = jsonEncode({
          'config': {
            'id': 'test',
            'playlists': [
              {'id': 's', 'displayName': 'S', 'resolverType': 'rss'},
            ],
          },
          'episodes': [],
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: previewBody,
        );

        final response = await handler(request);

        expect(response.headers['content-type'], equals('application/json'));
      });
    });
  });
}
