import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/config_routes.dart';
import 'package:sp_server/src/services/api_key_service.dart';
import 'package:sp_server/src/services/config_repository.dart';
import 'package:sp_server/src/services/jwt_service.dart';

const _baseUrl = 'https://raw.githubusercontent.com/test/repo/main';

/// Sample root meta.json.
String _rootMeta() => jsonEncode({
  'version': 1,
  'patterns': [
    {
      'id': 'podcast-a',
      'version': 1,
      'displayName': 'Podcast A',
      'feedUrlHint': 'https://example.com/a/feed.xml',
      'playlistCount': 1,
    },
    {
      'id': 'podcast-b',
      'version': 1,
      'displayName': 'Podcast B',
      'feedUrlHint': 'https://example.com/b/feed.xml',
      'playlistCount': 2,
    },
  ],
});

/// Sample pattern meta for podcast-a.
String _patternMetaA() => jsonEncode({
  'version': 1,
  'id': 'podcast-a',
  'podcastGuid': 'guid-a',
  'feedUrls': ['https://example.com/a/feed.xml'],
  'playlists': ['seasons'],
});

/// Sample pattern meta for podcast-b.
String _patternMetaB() => jsonEncode({
  'version': 1,
  'id': 'podcast-b',
  'feedUrls': ['https://example.com/b/feed.xml'],
  'playlists': ['by-year', 'categories'],
});

/// Sample playlists.
String _playlistSeasons() => jsonEncode({
  'id': 'seasons',
  'displayName': 'Seasons',
  'resolverType': 'rss',
});

String _playlistByYear() => jsonEncode({
  'id': 'by-year',
  'displayName': 'By Year',
  'resolverType': 'year',
});

String _playlistCategories() => jsonEncode({
  'id': 'categories',
  'displayName': 'Categories',
  'resolverType': 'category',
  'groups': [
    {'id': 'main', 'displayName': 'Main', 'pattern': '^Main'},
    {'id': 'bonus', 'displayName': 'Bonus'},
  ],
});

/// All mock responses for a complete test repo.
Map<String, String> _allResponses() => {
  '$_baseUrl/meta.json': _rootMeta(),
  '$_baseUrl/podcast-a/meta.json': _patternMetaA(),
  '$_baseUrl/podcast-b/meta.json': _patternMetaB(),
  '$_baseUrl/podcast-a/playlists/seasons.json': _playlistSeasons(),
  '$_baseUrl/podcast-b/playlists/by-year.json': _playlistByYear(),
  '$_baseUrl/podcast-b/playlists/categories.json': _playlistCategories(),
};

ConfigRepository _createRepo({
  Map<String, String>? responses,
  bool failAll = false,
}) {
  return ConfigRepository(
    httpGet: (Uri url) async {
      if (failAll) throw Exception('Network error');
      final resp = (responses ?? _allResponses())[url.toString()];
      if (resp == null) throw Exception('No mock: $url');
      return resp;
    },
    baseUrl: _baseUrl,
  );
}

/// Creates a repo that returns malformed JSON to trigger
/// TypeError (Error, not Exception) during parsing.
ConfigRepository _createMalformedRepo() {
  return ConfigRepository(
    httpGet: (Uri url) async {
      // Return valid JSON that is missing required fields,
      // causing a TypeError when fromJson casts null as int.
      return '{"unexpected": true}';
    },
    baseUrl: _baseUrl,
  );
}

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
      configRepository = _createRepo();

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

      test('returns list of pattern summaries', () async {
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
        expect(first['displayName'], equals('Podcast A'));
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
        final failingRepo = _createRepo(failAll: true);

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

      test('returns 502 on malformed upstream data', () async {
        final malformedRepo = _createMalformedRepo();
        final malformedRouter = configRouter(
          configRepository: malformedRepo,
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await malformedRouter.call(request);

        expect(response.statusCode, equals(502));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], isNotNull);
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

    group('GET /api/configs/patterns', () {
      test('returns pattern summaries as array', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/patterns'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body = jsonDecode(await response.readAsString()) as List;
        expect(body.length, equals(2));
        expect((body[0] as Map)['id'], equals('podcast-a'));
      });

      test('returns 401 without auth', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/patterns'),
        );

        final response = await handler(request);
        expect(response.statusCode, equals(401));
      });

      test('returns 502 on failure', () async {
        final failingRepo = _createRepo(failAll: true);
        final failRouter = configRouter(
          configRepository: failingRepo,
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/patterns'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await failRouter.call(request);
        expect(response.statusCode, equals(502));
      });
    });

    group('GET /api/configs/patterns/<id>', () {
      test('returns pattern metadata', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['id'], equals('podcast-a'));
        expect(body['podcastGuid'], equals('guid-a'));
        expect(body['playlists'], equals(['seasons']));
      });

      test('returns 401 without auth', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a'),
        );

        final response = await handler(request);
        expect(response.statusCode, equals(401));
      });

      test('returns 502 on fetch failure', () async {
        final failingRepo = _createRepo(failAll: true);
        final failRouter = configRouter(
          configRepository: failingRepo,
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await failRouter.call(request);
        expect(response.statusCode, equals(502));
      });
    });

    group('GET /api/configs/patterns/<id>/playlists/<pid>', () {
      test('returns playlist definition', () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/seasons',
          ),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['id'], equals('seasons'));
        expect(body['displayName'], equals('Seasons'));
        expect(body['resolverType'], equals('rss'));
      });

      test('returns 401 without auth', () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/seasons',
          ),
        );

        final response = await handler(request);
        expect(response.statusCode, equals(401));
      });

      test('returns 502 on fetch failure', () async {
        final failingRepo = _createRepo(failAll: true);
        final failRouter = configRouter(
          configRepository: failingRepo,
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/seasons',
          ),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await failRouter.call(request);
        expect(response.statusCode, equals(502));
      });
    });

    group('GET /api/configs/patterns/<id>/assembled', () {
      test('returns assembled config', () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/assembled',
          ),
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
        expect((playlists[0] as Map)['id'], equals('seasons'));
      });

      test('returns 401 without auth', () async {
        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/assembled',
          ),
        );

        final response = await handler(request);
        expect(response.statusCode, equals(401));
      });

      test('returns 502 on failure', () async {
        final failingRepo = _createRepo(failAll: true);
        final failRouter = configRouter(
          configRepository: failingRepo,
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/assembled',
          ),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await failRouter.call(request);
        expect(response.statusCode, equals(502));
      });

      test('returns 502 on malformed upstream data', () async {
        final malformedRepo = _createMalformedRepo();
        final malformedRouter = configRouter(
          configRepository: malformedRepo,
          jwtService: jwtService,
          apiKeyService: apiKeyService,
        );

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/assembled',
          ),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await malformedRouter.call(request);

        expect(response.statusCode, equals(502));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('Failed to assemble config'));
      });
    });

    group('GET /api/configs/<id>', () {
      test('returns assembled config by ID (legacy)', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/podcast-b'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['id'], equals('podcast-b'));
        final playlists = body['playlists'] as List;
        expect(playlists.length, equals(2));
      });

      test('returns 502 for unknown ID', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/nonexistent'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(502));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('Failed to fetch config'));
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
        final validConfig = jsonEncode({
          'version': 1,
          'patterns': [
            {
              'id': 'test',
              'playlists': [
                {
                  'id': 'seasons',
                  'displayName': 'Seasons',
                  'resolverType': 'rss',
                },
              ],
            },
          ],
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/validate'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: validConfig,
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
        expect(season1['episodeCount'], equals(2));
        expect(season1['resolverType'], equals('rss'));

        final season2 = playlists[1] as Map<String, dynamic>;
        expect(season2['displayName'], equals('Season 2'));
        expect(season2['episodeCount'], equals(1));

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
        final ungrouped = body['ungrouped'] as List;
        final ungroupedIds = ungrouped
            .map((e) => (e as Map<String, dynamic>)['id'])
            .toList();
        expect(ungroupedIds, contains(2));
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

      test('enriches episodes with smartPlaylistEpisodeExtractor', () async {
        // Episodes have null seasonNumber (as in real RSS feed)
        // but titles encode season-episode: 【62-2】 and 【15-8】
        final previewBody = jsonEncode({
          'config': {
            'id': 'test',
            'playlists': [
              {
                'id': 'regular',
                'displayName': 'Regular',
                'resolverType': 'rss',
                'nullSeasonGroupKey': 0,
                'titleExtractor': {
                  'source': 'title',
                  'pattern': r'Series (\w+)',
                  'group': 1,
                  'fallbackValue': 'Extras',
                },
                'smartPlaylistEpisodeExtractor': {
                  'source': 'title',
                  'pattern': r'\[(\d+)-(\d+)\]',
                  'seasonGroup': 1,
                  'episodeGroup': 2,
                },
              },
            ],
          },
          'episodes': [
            {
              'id': 1,
              'title': '[1-1] Pilot [Series Alpha1]',
              'seasonNumber': 1,
            },
            {
              'id': 2,
              'title': '[1-2] Episode Two [Series Alpha2]',
              // null seasonNumber in RSS, but title encodes season 1
            },
            {
              'id': 3,
              'title': '[2-1] New Arc [Series Beta1]',
              'seasonNumber': 2,
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

        // Episode 2 should be enriched to season 1 (from title),
        // NOT end up in the nullSeasonGroupKey=0 / "Extras" group.
        expect(playlists.length, equals(2));

        final season1 = playlists[0] as Map<String, dynamic>;
        expect(season1['sortKey'], equals(1));
        expect(season1['episodeCount'], equals(2));

        final season2 = playlists[1] as Map<String, dynamic>;
        expect(season2['sortKey'], equals(2));
        expect(season2['episodeCount'], equals(1));

        // No ungrouped episodes
        final ungrouped = body['ungrouped'] as List;
        expect(ungrouped, isEmpty);
      });
    });
  });
}
