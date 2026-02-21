import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/config_routes.dart';
import 'package:sp_server/src/services/api_key_service.dart';
import 'package:sp_server/src/services/config_repository.dart';
import 'package:sp_server/src/services/feed_cache_service.dart';
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

/// RSS feed with 3 episodes across 2 seasons.
String _sampleRss() => '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <item>
      <title>S1E1 Pilot</title>
      <itunes:season>1</itunes:season>
      <itunes:episode>1</itunes:episode>
    </item>
    <item>
      <title>S1E2 Next</title>
      <itunes:season>1</itunes:season>
      <itunes:episode>2</itunes:episode>
    </item>
    <item>
      <title>S2E1 Return</title>
      <itunes:season>2</itunes:season>
      <itunes:episode>1</itunes:episode>
    </item>
  </channel>
</rss>''';

/// RSS feed with no items.
String _emptyRss() => '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel></channel></rss>''';

/// RSS feed where one episode has a season and one does not.
String _mixedRss() => '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <item>
      <title>Episode with season</title>
      <itunes:season>1</itunes:season>
      <itunes:episode>1</itunes:episode>
    </item>
    <item>
      <title>Episode without season</title>
    </item>
  </channel>
</rss>''';

/// RSS feed with title-encoded season/episode numbers.
String _extractorRss() => '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <item>
      <title>[1-1] Pilot [Series Alpha1]</title>
      <itunes:season>1</itunes:season>
    </item>
    <item>
      <title>[1-2] Episode Two [Series Alpha2]</title>
    </item>
    <item>
      <title>[2-1] New Arc [Series Beta1]</title>
      <itunes:season>2</itunes:season>
    </item>
  </channel>
</rss>''';

/// RSS feed with pubDate for testing publishedAt serialization.
String _enrichedRss() => '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <item>
      <title>S1E1 Pilot</title>
      <pubDate>2024-01-15T10:00:00Z</pubDate>
      <itunes:season>1</itunes:season>
      <itunes:episode>1</itunes:episode>
    </item>
    <item>
      <title>S1E2 Next</title>
      <pubDate>2024-02-01T10:00:00Z</pubDate>
      <itunes:season>1</itunes:season>
      <itunes:episode>2</itunes:episode>
    </item>
    <item>
      <title>S2E1 Return</title>
      <pubDate>2024-06-01T10:00:00Z</pubDate>
      <itunes:season>2</itunes:season>
      <itunes:episode>1</itunes:episode>
    </item>
  </channel>
</rss>''';

/// Creates a FeedCacheService that routes URLs to fake RSS responses.
FeedCacheService _createFeedCacheService() {
  return FeedCacheService(
    httpGet: (Uri url) async {
      final responses = {
        'https://example.com/feed.xml': _sampleRss(),
        'https://example.com/empty.xml': _emptyRss(),
        'https://example.com/mixed.xml': _mixedRss(),
        'https://example.com/extractor.xml': _extractorRss(),
        'https://example.com/enriched.xml': _enrichedRss(),
      };
      final body = responses[url.toString()];
      if (body != null) return body;
      throw Exception('Unknown feed: $url');
    },
  );
}

void main() {
  group('configRouter', () {
    late JwtService jwtService;
    late ApiKeyService apiKeyService;
    late ConfigRepository configRepository;
    late FeedCacheService feedCacheService;
    late Handler handler;
    late String validToken;

    setUp(() {
      jwtService = JwtService(secret: 'test-secret');
      apiKeyService = ApiKeyService();
      validToken = jwtService.createToken('user-1');
      configRepository = _createRepo();
      feedCacheService = _createFeedCacheService();

      final router = configRouter(
        configRepository: configRepository,
        feedCacheService: feedCacheService,
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
          feedCacheService: feedCacheService,
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
          feedCacheService: feedCacheService,
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
          feedCacheService: feedCacheService,
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
          feedCacheService: feedCacheService,
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
          feedCacheService: feedCacheService,
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
          feedCacheService: feedCacheService,
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
          feedCacheService: feedCacheService,
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
            'feedUrls': ['https://example.com/feed.xml'],
            'playlists': [
              {
                'id': 'seasons',
                'displayName': 'Seasons',
                'resolverType': 'rss',
              },
            ],
          },
          'feedUrl': 'https://example.com/feed.xml',
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
        // resolveForPreview returns 1 entry per definition,
        // with seasons as groups inside
        expect(playlists.length, equals(1));

        final playlist = playlists[0] as Map<String, dynamic>;
        expect(playlist['id'], equals('seasons'));
        expect(playlist['displayName'], equals('Seasons'));
        expect(playlist['episodeCount'], equals(3));
        expect(playlist['resolverType'], equals('rss'));

        final groups = playlist['groups'] as List;
        expect(groups.length, equals(2));

        final season1 = groups[0] as Map<String, dynamic>;
        expect(season1['displayName'], equals('Season 1'));
        expect(season1['episodeCount'], equals(2));

        final season2 = groups[1] as Map<String, dynamic>;
        expect(season2['displayName'], equals('Season 2'));
        expect(season2['episodeCount'], equals(1));

        expect(body['resolverType'], equals('rss'));

        final debug = body['debug'] as Map<String, dynamic>;
        expect(debug['totalEpisodes'], equals(3));
        expect(debug['groupedEpisodes'], equals(3));
        expect(debug['ungroupedEpisodes'], equals(0));

        // Per-playlist debug fields
        final playlistDebug = playlist['debug'] as Map<String, dynamic>;
        expect(playlistDebug['filterMatched'], equals(3));
        expect(playlistDebug['episodeCount'], equals(3));
        expect(playlistDebug['claimedByOthersCount'], equals(0));
      });

      test('returns empty result with no episodes', () async {
        final previewBody = jsonEncode({
          'config': {
            'id': 'test',
            'feedUrls': ['https://example.com/empty.xml'],
            'playlists': [
              {
                'id': 'seasons',
                'displayName': 'Seasons',
                'resolverType': 'rss',
              },
            ],
          },
          'feedUrl': 'https://example.com/empty.xml',
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
          body: jsonEncode({'feedUrl': 'https://example.com/feed.xml'}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('config'));
      });

      test('returns 400 for missing feedUrl', () async {
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
        expect(body['error'], contains('feedUrl'));
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

      test('returns 400 for feed fetch failure', () async {
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
            'feedUrl': 'https://example.com/unknown-feed.xml',
          }),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('Preview failed'));
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
            'feedUrls': ['https://example.com/mixed.xml'],
            'playlists': [
              {
                'id': 'seasons',
                'displayName': 'Seasons',
                'resolverType': 'rss',
              },
            ],
          },
          'feedUrl': 'https://example.com/mixed.xml',
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
        // FeedCacheService assigns 0-based IDs; episode without
        // season is at index 1.
        expect(ungroupedIds, contains(1));
      });

      test('has JSON content type', () async {
        final previewBody = jsonEncode({
          'config': {
            'id': 'test',
            'playlists': [
              {'id': 's', 'displayName': 'S', 'resolverType': 'rss'},
            ],
          },
          'feedUrl': 'https://example.com/empty.xml',
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
        // The extractor RSS feed has episodes with title-encoded
        // season/episode numbers: [1-1], [1-2], [2-1].
        // Episode at index 1 has no itunes:season in RSS, but the
        // extractor should derive season 1 from the title pattern.
        final previewBody = jsonEncode({
          'config': {
            'id': 'test',
            'feedUrls': ['https://example.com/extractor.xml'],
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
          'feedUrl': 'https://example.com/extractor.xml',
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

        // resolveForPreview returns 1 entry per definition,
        // with seasons as groups inside.
        expect(playlists.length, equals(1));

        final playlist = playlists[0] as Map<String, dynamic>;
        expect(playlist['id'], equals('regular'));
        expect(playlist['episodeCount'], equals(3));

        final groups = playlist['groups'] as List;
        expect(groups.length, equals(2));

        // Episode 2 should be enriched to season 1 (from title),
        // NOT end up in the nullSeasonGroupKey=0 / "Extras" group.
        final season1 = groups[0] as Map<String, dynamic>;
        expect(season1['sortKey'], equals(1));
        expect(season1['episodeCount'], equals(2));

        final season2 = groups[1] as Map<String, dynamic>;
        expect(season2['sortKey'], equals(2));
        expect(season2['episodeCount'], equals(1));

        // No ungrouped episodes
        final ungrouped = body['ungrouped'] as List;
        expect(ungrouped, isEmpty);
      });

      test('includes enriched episode fields in group episodes', () async {
        final previewBody = jsonEncode({
          'config': {
            'id': 'test',
            'feedUrls': ['https://example.com/enriched.xml'],
            'playlists': [
              {
                'id': 'seasons',
                'displayName': 'Seasons',
                'resolverType': 'rss',
              },
            ],
          },
          'feedUrl': 'https://example.com/enriched.xml',
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
        expect(playlists.length, equals(1));

        final playlist = playlists[0] as Map<String, dynamic>;
        final groups = playlist['groups'] as List;
        expect(groups.length, equals(2));

        // Season 1 has 2 episodes
        final season1 = groups[0] as Map<String, dynamic>;
        final episodes = season1['episodes'] as List;
        expect(episodes.length, equals(2));

        // Verify first episode has enriched fields
        final firstEpisode = episodes[0] as Map<String, dynamic>;
        expect(firstEpisode['id'], equals(0));
        expect(firstEpisode['title'], equals('S1E1 Pilot'));
        expect(firstEpisode['publishedAt'], equals('2024-01-15T10:00:00.000Z'));
        expect(firstEpisode['seasonNumber'], equals(1));
        expect(firstEpisode['episodeNumber'], equals(1));

        // Verify second episode
        final secondEpisode = episodes[1] as Map<String, dynamic>;
        expect(secondEpisode['seasonNumber'], equals(1));
        expect(secondEpisode['episodeNumber'], equals(2));
        expect(
          secondEpisode['publishedAt'],
          equals('2024-02-01T10:00:00.000Z'),
        );

        // No extractedDisplayName when no titleExtractor configured
        expect(firstEpisode.containsKey('extractedDisplayName'), isFalse);
      });

      test(
        'includes extractedDisplayName when titleExtractor is configured',
        () async {
          final previewBody = jsonEncode({
            'config': {
              'id': 'test',
              'feedUrls': ['https://example.com/extractor.xml'],
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
            'feedUrl': 'https://example.com/extractor.xml',
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
          expect(playlists.length, equals(1));

          final playlist = playlists[0] as Map<String, dynamic>;
          final groups = playlist['groups'] as List;
          expect(groups.length, equals(2));

          // Season 1 group: episodes with titles containing
          // "Series Alpha1" and "Series Alpha2"
          final season1 = groups[0] as Map<String, dynamic>;
          final season1Episodes = season1['episodes'] as List;

          // Each episode should have extractedDisplayName from
          // the titleExtractor pattern "Series (\w+)"
          for (final ep in season1Episodes) {
            final episode = ep as Map<String, dynamic>;
            expect(
              episode.containsKey('extractedDisplayName'),
              isTrue,
              reason:
                  'Episode ${episode['id']} should have '
                  'extractedDisplayName',
            );
            expect(
              (episode['extractedDisplayName'] as String).startsWith('Alpha'),
              isTrue,
              reason:
                  'extractedDisplayName should match "Series (\\w+)" '
                  'group 1',
            );
          }

          // Season 2 group: episode with title "[2-1] New Arc
          // [Series Beta1]"
          final season2 = groups[1] as Map<String, dynamic>;
          final season2Episodes = season2['episodes'] as List;
          final beta = season2Episodes[0] as Map<String, dynamic>;
          expect(beta['extractedDisplayName'], equals('Beta1'));
        },
      );

      test('includes per-playlist debug fields', () async {
        final previewBody = jsonEncode({
          'config': {
            'id': 'test',
            'feedUrls': ['https://example.com/feed.xml'],
            'playlists': [
              {
                'id': 'seasons',
                'displayName': 'Seasons',
                'resolverType': 'rss',
              },
            ],
          },
          'feedUrl': 'https://example.com/feed.xml',
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
        expect(playlists.length, equals(1));

        final playlist = playlists[0] as Map<String, dynamic>;
        final debug = playlist['debug'] as Map<String, dynamic>;
        expect(debug, containsPair('filterMatched', 3));
        expect(debug, containsPair('episodeCount', 3));
        expect(debug, containsPair('claimedByOthersCount', 0));

        // No claimedByOthers field when empty
        expect(playlist.containsKey('claimedByOthers'), isFalse);
      });
    });
  });
}
