import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_shared/sp_shared.dart';
import 'package:sp_server/src/routes/config_routes.dart';
import 'package:sp_server/src/services/local_config_repository.dart';

/// Creates root meta.json content.
String _rootMeta() => const JsonEncoder.withIndent('  ').convert({
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

/// Pattern meta for podcast-a.
String _patternMetaA() => const JsonEncoder.withIndent('  ').convert({
  'version': 1,
  'id': 'podcast-a',
  'podcastGuid': 'guid-a',
  'feedUrls': ['https://example.com/a/feed.xml'],
  'playlists': ['seasons'],
});

/// Pattern meta for podcast-b.
String _patternMetaB() => const JsonEncoder.withIndent('  ').convert({
  'version': 1,
  'id': 'podcast-b',
  'feedUrls': ['https://example.com/b/feed.xml'],
  'playlists': ['by-year', 'categories'],
});

/// Sample playlists.
String _playlistSeasons() => const JsonEncoder.withIndent(
  '  ',
).convert({'id': 'seasons', 'displayName': 'Seasons', 'resolverType': 'rss'});

String _playlistByYear() => const JsonEncoder.withIndent(
  '  ',
).convert({'id': 'by-year', 'displayName': 'By Year', 'resolverType': 'year'});

String _playlistCategories() => const JsonEncoder.withIndent('  ').convert({
  'id': 'categories',
  'displayName': 'Categories',
  'resolverType': 'category',
  'groups': [
    {'id': 'main', 'displayName': 'Main', 'pattern': '^Main'},
    {'id': 'bonus', 'displayName': 'Bonus'},
  ],
});

/// Writes the full test fixture tree into a temp directory.
Future<String> _createTestDataDir() async {
  final tmpDir = await Directory.systemTemp.createTemp('config_routes_test_');
  final dataDir = tmpDir.path;
  final patternsDir = '$dataDir/patterns';

  // Root meta.json
  await _writeFile('$patternsDir/meta.json', _rootMeta());

  // podcast-a
  await _writeFile('$patternsDir/podcast-a/meta.json', _patternMetaA());
  await _writeFile(
    '$patternsDir/podcast-a/playlists/seasons.json',
    _playlistSeasons(),
  );

  // podcast-b
  await _writeFile('$patternsDir/podcast-b/meta.json', _patternMetaB());
  await _writeFile(
    '$patternsDir/podcast-b/playlists/by-year.json',
    _playlistByYear(),
  );
  await _writeFile(
    '$patternsDir/podcast-b/playlists/categories.json',
    _playlistCategories(),
  );

  return dataDir;
}

Future<void> _writeFile(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
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

/// Creates a DiskFeedCacheService backed by a temp directory
/// that routes URLs to fake RSS responses via httpGet.
Future<DiskFeedCacheService> _createFeedCacheService() async {
  final cacheDir = await Directory.systemTemp.createTemp('feed_cache_test_');
  return DiskFeedCacheService(
    cacheDir: cacheDir.path,
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
    late LocalConfigRepository configRepository;
    late DiskFeedCacheService feedCacheService;
    late SmartPlaylistValidator validator;
    late Handler handler;
    late String dataDir;

    setUp(() async {
      dataDir = await _createTestDataDir();
      configRepository = LocalConfigRepository(dataDir: dataDir);
      feedCacheService = await _createFeedCacheService();
      validator = SmartPlaylistValidator();

      final router = configRouter(
        configRepository: configRepository,
        feedCacheService: feedCacheService,
        validator: validator,
      );
      handler = router.call;
    });

    tearDown(() async {
      await Directory(dataDir).delete(recursive: true);
    });

    group('GET /api/configs/patterns', () {
      test('returns pattern summaries as array', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/patterns'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body = jsonDecode(await response.readAsString()) as List;
        expect(body.length, equals(2));
        expect((body[0] as Map)['id'], equals('podcast-a'));
      });

      test('returns 502 on failure', () async {
        // Point to non-existent data dir
        final failRepo = LocalConfigRepository(
          dataDir:
              '/tmp/nonexistent-dir-${DateTime.now().millisecondsSinceEpoch}',
        );
        final failRouter = configRouter(
          configRepository: failRepo,
          feedCacheService: feedCacheService,
          validator: validator,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/patterns'),
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
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['id'], equals('podcast-a'));
        expect(body['podcastGuid'], equals('guid-a'));
        expect(body['playlists'], equals(['seasons']));
      });

      test('returns 502 on fetch failure', () async {
        final failRepo = LocalConfigRepository(
          dataDir:
              '/tmp/nonexistent-dir-${DateTime.now().millisecondsSinceEpoch}',
        );
        final failRouter = configRouter(
          configRepository: failRepo,
          feedCacheService: feedCacheService,
          validator: validator,
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a'),
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
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['id'], equals('seasons'));
        expect(body['displayName'], equals('Seasons'));
        expect(body['resolverType'], equals('rss'));
      });

      test('returns 502 on fetch failure', () async {
        final failRepo = LocalConfigRepository(
          dataDir:
              '/tmp/nonexistent-dir-${DateTime.now().millisecondsSinceEpoch}',
        );
        final failRouter = configRouter(
          configRepository: failRepo,
          feedCacheService: feedCacheService,
          validator: validator,
        );

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/seasons',
          ),
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

      test('returns 502 on failure', () async {
        final failRepo = LocalConfigRepository(
          dataDir:
              '/tmp/nonexistent-dir-${DateTime.now().millisecondsSinceEpoch}',
        );
        final failRouter = configRouter(
          configRepository: failRepo,
          feedCacheService: feedCacheService,
          validator: validator,
        );

        final request = Request(
          'GET',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/assembled',
          ),
        );

        final response = await failRouter.call(request);
        expect(response.statusCode, equals(502));
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
          headers: {'Content-Type': 'application/json'},
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
          headers: {'Content-Type': 'application/json'},
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
          headers: {'Content-Type': 'application/json'},
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
          headers: {'Content-Type': 'application/json'},
          body: previewBody,
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        final playlists = body['playlists'] as List;
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
          headers: {'Content-Type': 'application/json'},
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
          body: '',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('returns 400 for missing config', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          headers: {'Content-Type': 'application/json'},
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
          headers: {'Content-Type': 'application/json'},
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
          headers: {'Content-Type': 'application/json'},
          body: '{invalid json',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('returns 400 for feed fetch failure', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          headers: {'Content-Type': 'application/json'},
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
          headers: {'Content-Type': 'application/json'},
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
        // DiskFeedCacheService assigns 0-based IDs; episode without
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
          headers: {'Content-Type': 'application/json'},
          body: previewBody,
        );

        final response = await handler(request);

        expect(response.headers['content-type'], equals('application/json'));
      });

      test('enriches episodes with smartPlaylistEpisodeExtractor', () async {
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
          headers: {'Content-Type': 'application/json'},
          body: previewBody,
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        final playlists = body['playlists'] as List;

        expect(playlists.length, equals(1));

        final playlist = playlists[0] as Map<String, dynamic>;
        expect(playlist['id'], equals('regular'));
        expect(playlist['episodeCount'], equals(3));

        final groups = playlist['groups'] as List;
        expect(groups.length, equals(2));

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
          headers: {'Content-Type': 'application/json'},
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
            headers: {'Content-Type': 'application/json'},
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

          // Season 2 group
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
          headers: {'Content-Type': 'application/json'},
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

    group('PUT /api/configs/patterns/<id>/playlists/<pid>', () {
      test('saves valid playlist and returns 200', () async {
        final playlistJson = {
          'id': 'seasons',
          'displayName': 'Updated Seasons',
          'resolverType': 'rss',
        };

        final request = Request(
          'PUT',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/seasons',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(playlistJson),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['ok'], isTrue);

        // Verify file was written to disk
        final file = File('$dataDir/patterns/podcast-a/playlists/seasons.json');
        final content =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(content['displayName'], equals('Updated Seasons'));
      });

      test('returns 400 with validation errors for invalid playlist', () async {
        final invalidJson = {
          'id': 'seasons',
          // Missing required 'displayName' and 'resolverType'
        };

        final request = Request(
          'PUT',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/seasons',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(invalidJson),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], isNotNull);
        expect(body['errors'], isNotEmpty);
      });

      test('returns 400 for empty body', () async {
        final request = Request(
          'PUT',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/seasons',
          ),
          body: '',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('returns 400 for invalid JSON syntax', () async {
        final request = Request(
          'PUT',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/seasons',
          ),
          headers: {'Content-Type': 'application/json'},
          body: '{not valid json',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('normalizes playlist JSON via model round-trip', () async {
        // Send fields in non-canonical order to verify normalization
        final playlistJson = {
          'resolverType': 'rss',
          'id': 'seasons',
          'displayName': 'Normalized Test',
        };

        final request = Request(
          'PUT',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/seasons',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(playlistJson),
        );

        final response = await handler(request);
        expect(response.statusCode, equals(200));

        // Verify file has canonical field order from model toJson()
        final file = File('$dataDir/patterns/podcast-a/playlists/seasons.json');
        final content =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final keys = content.keys.toList();
        // SmartPlaylistDefinition.toJson() outputs 'id' first
        expect(keys.first, equals('id'));
        expect(content['displayName'], equals('Normalized Test'));
      });

      test('returns 400 for invalid resolverType', () async {
        final invalidJson = {
          'id': 'seasons',
          'displayName': 'Seasons',
          'resolverType': 'invalidType',
        };

        final request = Request(
          'PUT',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/seasons',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(invalidJson),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['errors'], isNotEmpty);
      });
    });

    group('PUT /api/configs/patterns/<id>/meta', () {
      test('saves pattern meta and returns 200', () async {
        final metaJson = {
          'version': 1,
          'id': 'podcast-a',
          'podcastGuid': 'guid-a-updated',
          'feedUrls': ['https://example.com/a/feed.xml'],
          'playlists': ['seasons'],
        };

        final request = Request(
          'PUT',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a/meta'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(metaJson),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['ok'], isTrue);

        // Verify file was written to disk
        final file = File('$dataDir/patterns/podcast-a/meta.json');
        final content =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(content['podcastGuid'], equals('guid-a-updated'));
      });

      test('preserves existing version via read-modify-write', () async {
        // First set version to 5 on disk to simulate sp_cli bump
        final metaFile = File('$dataDir/patterns/podcast-a/meta.json');
        final existing =
            jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        existing['version'] = 5;
        await metaFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(existing),
        );

        // Client sends version: 1 (stale), should be ignored
        final metaJson = {
          'version': 1,
          'id': 'podcast-a',
          'feedUrls': ['https://example.com/a/updated-feed.xml'],
          'playlists': ['seasons'],
        };

        final request = Request(
          'PUT',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a/meta'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(metaJson),
        );

        final response = await handler(request);
        expect(response.statusCode, equals(200));

        // Verify version preserved from disk, other fields updated
        final content =
            jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        expect(content['version'], equals(5));
        expect(
          content['feedUrls'],
          equals(['https://example.com/a/updated-feed.xml']),
        );
      });

      test('preserves existing fields not sent by client', () async {
        // Client sends only feedUrls and playlists (no podcastGuid)
        final metaJson = {
          'id': 'podcast-a',
          'feedUrls': ['https://example.com/a/feed.xml'],
          'playlists': ['seasons'],
        };

        final request = Request(
          'PUT',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a/meta'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(metaJson),
        );

        final response = await handler(request);
        expect(response.statusCode, equals(200));

        final file = File('$dataDir/patterns/podcast-a/meta.json');
        final content =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        // podcastGuid from disk should be preserved
        expect(content['podcastGuid'], equals('guid-a'));
      });

      test('returns 400 for empty body', () async {
        final request = Request(
          'PUT',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a/meta'),
          body: '',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('returns 400 for invalid JSON syntax', () async {
        final request = Request(
          'PUT',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a/meta'),
          headers: {'Content-Type': 'application/json'},
          body: '{bad json',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });
    });

    group('POST /api/configs/patterns', () {
      test('creates new pattern and returns 201', () async {
        final body = {
          'id': 'podcast-new',
          'meta': {
            'version': 1,
            'id': 'podcast-new',
            'feedUrls': ['https://example.com/new/feed.xml'],
            'playlists': [],
          },
        };

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/patterns'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(201));
        final responseBody =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(responseBody['ok'], isTrue);
        expect(responseBody['id'], equals('podcast-new'));

        // Verify directory and meta.json were created
        final dir = Directory('$dataDir/patterns/podcast-new');
        expect(await dir.exists(), isTrue);

        final metaFile = File('$dataDir/patterns/podcast-new/meta.json');
        expect(await metaFile.exists(), isTrue);

        final content =
            jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        expect(content['id'], equals('podcast-new'));

        // Verify playlists subdirectory was created
        final playlistsDir = Directory(
          '$dataDir/patterns/podcast-new/playlists',
        );
        expect(await playlistsDir.exists(), isTrue);
      });

      test('returns 400 for missing id', () async {
        final body = {
          'meta': {'version': 1, 'id': 'x', 'playlists': []},
        };

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/patterns'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('returns 400 for missing meta', () async {
        final body = {'id': 'podcast-new'};

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/patterns'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('returns 400 for empty body', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/patterns'),
          body: '',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });
    });

    group('DELETE /api/configs/patterns/<id>/playlists/<pid>', () {
      test('deletes playlist file and returns 200', () async {
        // Verify file exists before delete
        final file = File('$dataDir/patterns/podcast-a/playlists/seasons.json');
        expect(await file.exists(), isTrue);

        final request = Request(
          'DELETE',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/seasons',
          ),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['ok'], isTrue);

        // Verify file was deleted
        expect(await file.exists(), isFalse);
      });

      test('returns 404 for non-existent playlist', () async {
        final request = Request(
          'DELETE',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a/playlists/nonexistent',
          ),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(404));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('not found'));
      });
    });

    group('DELETE /api/configs/patterns/<id>', () {
      test('deletes pattern directory and returns 200', () async {
        // Verify directory exists before delete
        final dir = Directory('$dataDir/patterns/podcast-a');
        expect(await dir.exists(), isTrue);

        final request = Request(
          'DELETE',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['ok'], isTrue);

        // Verify directory was deleted
        expect(await dir.exists(), isFalse);
      });

      test('returns 404 for non-existent pattern', () async {
        final request = Request(
          'DELETE',
          Uri.parse('http://localhost/api/configs/patterns/nonexistent'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(404));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('not found'));
      });
    });
  });
}
