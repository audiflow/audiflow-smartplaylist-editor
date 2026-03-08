import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_shared/sp_shared.dart';
import 'package:sp_server/src/routes/config_routes.dart';
import 'package:sp_server/src/services/local_config_repository.dart';

/// Creates root meta.json content.
String _rootMeta() => const JsonEncoder.withIndent('  ').convert({
  'dataVersion': 1,
  'schemaVersion': 1,
  'patterns': [
    {
      'id': 'podcast-a',
      'dataVersion': 1,
      'displayName': 'Podcast A',
      'feedUrlHint': 'https://example.com/a/feed.xml',
      'playlistCount': 1,
    },
  ],
});

/// Pattern meta for podcast-a.
String _patternMetaA() => const JsonEncoder.withIndent('  ').convert({
  'dataVersion': 1,
  'id': 'podcast-a',
  'podcastGuid': 'guid-a',
  'feedUrls': ['https://example.com/a/feed.xml'],
  'playlists': ['seasons'],
});

/// Sample playlist.
String _playlistSeasons() => const JsonEncoder.withIndent('  ').convert({
  'id': 'seasons',
  'displayName': 'Seasons',
  'resolverType': 'rss',
  'playlistStructure': 'split',
});

/// RSS feed with episodes that produce claimedByOthers when two definitions
/// overlap. Two episodes, both matching `.` title filter.
String _claimingRss() => '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <item>
      <title>Episode 1</title>
      <pubDate>2024-01-15T10:00:00Z</pubDate>
    </item>
    <item>
      <title>Episode 2</title>
      <pubDate>2024-02-01T10:00:00Z</pubDate>
    </item>
  </channel>
</rss>''';

/// Writes the test fixture tree into a temp directory.
Future<String> _createTestDataDir() async {
  final tmpDir = await Directory.systemTemp.createTemp(
    'config_routes_extra_test_',
  );
  final dataDir = tmpDir.path;
  final patternsDir = '$dataDir/patterns';

  await _writeFile('$patternsDir/meta.json', _rootMeta());
  await _writeFile('$patternsDir/podcast-a/meta.json', _patternMetaA());
  await _writeFile(
    '$patternsDir/podcast-a/playlists/seasons.json',
    _playlistSeasons(),
  );

  return dataDir;
}

Future<void> _writeFile(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

/// Creates a DiskFeedCacheService backed by a temp directory.
/// Returns both the service and the cache directory path for cleanup.
Future<(DiskFeedCacheService, String)> _createFeedCacheService() async {
  final cacheDir = await Directory.systemTemp.createTemp(
    'feed_cache_extra_test_',
  );
  final service = DiskFeedCacheService(
    cacheDir: cacheDir.path,
    httpGet: (Uri url) async {
      final responses = {'https://example.com/claiming.xml': _claimingRss()};
      final body = responses[url.toString()];
      if (body != null) return body;
      throw Exception('Unknown feed: $url');
    },
  );
  return (service, cacheDir.path);
}

void main() {
  group('configRouter extra coverage', () {
    late LocalConfigRepository configRepository;
    late DiskFeedCacheService feedCacheService;
    late SmartPlaylistValidator validator;
    late Handler handler;
    late String dataDir;
    late String cacheDir;

    setUp(() async {
      dataDir = await _createTestDataDir();
      configRepository = LocalConfigRepository(dataDir: dataDir);
      final (service, cachePath) = await _createFeedCacheService();
      feedCacheService = service;
      cacheDir = cachePath;
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
      await Directory(cacheDir).delete(recursive: true);
    });

    group('POST /api/configs/validate type variants', () {
      test('validates patternMeta type', () async {
        final validMeta = jsonEncode({
          'dataVersion': 1,
          'id': 'podcast-a',
          'feedUrls': ['https://example.com/a/feed.xml'],
          'playlists': ['seasons'],
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/validate?type=patternMeta'),
          headers: {'Content-Type': 'application/json'},
          body: validMeta,
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['valid'], isTrue);
        expect(body['errors'], isEmpty);
      });

      test('validates patternIndex type', () async {
        final validIndex = jsonEncode({
          'dataVersion': 1,
          'schemaVersion': 1,
          'patterns': [],
        });

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/validate?type=patternIndex'),
          headers: {'Content-Type': 'application/json'},
          body: validIndex,
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['valid'], isTrue);
        expect(body['errors'], isEmpty);
      });

      test('returns 400 for invalid type parameter', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/validate?type=invalid'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': 'test'}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('Invalid type'));
      });
    });

    group('POST /api/configs/preview edge cases', () {
      test('returns 400 for non-JSON-object body', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/preview'),
          headers: {'Content-Type': 'application/json'},
          body: '"not an object"',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('JSON object'));
      });

      test(
        'includes claimedByOthers in preview when definitions overlap',
        () async {
          // Two year-resolver definitions with overlapping episodeFilters.
          // Lower priority number wins, so priority-b claims episodes first.
          // priority-a sees them as claimedByOthers.
          final previewBody = jsonEncode({
            'config': {
              'id': 'test',
              'feedUrls': ['https://example.com/claiming.xml'],
              'playlists': [
                {
                  'id': 'priority-a',
                  'displayName': 'Priority A',
                  'resolverType': 'year',
                  'playlistStructure': 'split',
                  'priority': 10,
                  'episodeFilters': {
                    'require': [
                      {'title': '.'},
                    ],
                  },
                },
                {
                  'id': 'priority-b',
                  'displayName': 'Priority B',
                  'resolverType': 'year',
                  'playlistStructure': 'split',
                  'priority': 5,
                  'episodeFilters': {
                    'require': [
                      {'title': '.'},
                    ],
                  },
                },
              ],
            },
            'feedUrl': 'https://example.com/claiming.xml',
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
          expect(playlists.length, equals(2));

          // Find the lower-priority definition (priority-a) which should
          // have claimedByOthers populated.
          final priorityA =
              playlists.firstWhere(
                    (p) => (p as Map<String, dynamic>)['id'] == 'priority-a',
                  )
                  as Map<String, dynamic>;
          expect(priorityA.containsKey('claimedByOthers'), isTrue);
          final claimed = priorityA['claimedByOthers'] as List;
          expect(claimed, isNotEmpty);

          // Each claimed entry should have 'claimedBy' field
          for (final entry in claimed) {
            final map = entry as Map<String, dynamic>;
            expect(map['claimedBy'], equals('priority-b'));
            expect(map.containsKey('title'), isTrue);
          }

          // priority-a debug should reflect claimed count
          final debugA = priorityA['debug'] as Map<String, dynamic>;
          expect(0, lessThan(debugA['claimedByOthersCount'] as int));
        },
      );
    });

    group('PUT /api/configs/patterns/<id>/playlists/<pid> sanitization', () {
      test('strips null values in nested structures with lists', () async {
        // Groups with null values should be stripped so schema validation
        // passes (JSON Schema rejects null for typed fields).
        final playlistJson = {
          'id': 'seasons',
          'displayName': 'Seasons',
          'resolverType': 'category',
          'playlistStructure': 'grouped',
          'groups': [
            {
              'id': 'main',
              'displayName': 'Main',
              'pattern': '^Main',
              'sortKey': null,
            },
            {'id': 'bonus', 'displayName': 'Bonus'},
          ],
        };

        final request = Request(
          'PUT',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a'
            '/playlists/seasons',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(playlistJson),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['ok'], isTrue);
      });

      test(
        'returns 500 when save fails due to file blocking directory',
        () async {
          // Replace the playlists directory with a file to force a write failure
          final playlistsDir = Directory(
            '$dataDir/patterns/podcast-a/playlists',
          );
          await playlistsDir.delete(recursive: true);
          // Create a file where the directory should be, blocking writes
          await File(
            '$dataDir/patterns/podcast-a/playlists',
          ).writeAsString('blocker');

          final playlistJson = {
            'id': 'seasons',
            'displayName': 'Seasons',
            'resolverType': 'rss',
            'playlistStructure': 'split',
          };

          final request = Request(
            'PUT',
            Uri.parse(
              'http://localhost/api/configs/patterns/podcast-a'
              '/playlists/seasons',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(playlistJson),
          );

          final response = await handler(request);

          expect(response.statusCode, equals(500));
          final body =
              jsonDecode(await response.readAsString()) as Map<String, dynamic>;
          expect(body['error'], contains('Failed to save playlist'));
        },
      );

      test('returns 400 for non-object body', () async {
        final request = Request(
          'PUT',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a'
            '/playlists/seasons',
          ),
          headers: {'Content-Type': 'application/json'},
          body: '"just a string"',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('JSON object'));
      });
    });

    group('PUT /api/configs/patterns/<id>/meta edge cases', () {
      test('removes displayName from root meta when empty string', () async {
        final metaJson = {
          'id': 'podcast-a',
          'displayName': '',
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

        final rootFile = File('$dataDir/patterns/meta.json');
        final rootMeta =
            jsonDecode(await rootFile.readAsString()) as Map<String, dynamic>;
        final patterns = rootMeta['patterns'] as List<dynamic>;
        final entry =
            patterns.firstWhere(
                  (p) => (p as Map<String, dynamic>)['id'] == 'podcast-a',
                )
                as Map<String, dynamic>;
        expect(entry.containsKey('displayName'), isFalse);
      });

      test('returns 400 for non-string displayName', () async {
        final metaJson = {
          'id': 'podcast-a',
          'displayName': 123,
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
        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('displayName'));
      });

      test('returns 400 for non-object body', () async {
        final request = Request(
          'PUT',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a/meta'),
          headers: {'Content-Type': 'application/json'},
          body: '"just a string"',
        );

        final response = await handler(request);
        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('JSON object'));
      });

      test('returns 400 for validation errors in merged meta', () async {
        // Send meta with invalid feedUrls type to trigger validation failure
        final metaJson = {
          'id': 'podcast-a',
          'feedUrls': 'not-a-list',
          'playlists': ['seasons'],
        };

        final request = Request(
          'PUT',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a/meta'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(metaJson),
        );

        final response = await handler(request);
        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('Validation failed'));
        expect(body['errors'], isNotEmpty);
      });

      test('returns 500 when save fails', () async {
        // Delete the pattern directory to cause a write failure
        await Directory('$dataDir/patterns/podcast-a').delete(recursive: true);
        // Re-create it without meta.json so getPatternMetaJson fails
        // Actually, just remove the whole directory so the read-modify-write
        // step throws when reading the existing meta.
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
        expect(response.statusCode, equals(500));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('Failed to save pattern meta'));
      });
    });

    group('POST /api/configs/patterns edge cases', () {
      test('returns 400 for missing meta field', () async {
        final body = {'id': 'podcast-new'};

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/patterns'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final responseBody =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(responseBody['error'], contains('meta'));
      });

      test('uses id as displayName when displayName is non-string', () async {
        final body = {
          'id': 'podcast-fallback',
          'displayName': 42,
          'meta': {
            'id': 'podcast-fallback',
            'feedUrls': ['https://example.com/fallback/feed.xml'],
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

        // Verify displayName falls back to id in root meta
        final rootFile = File('$dataDir/patterns/meta.json');
        final rootMeta =
            jsonDecode(await rootFile.readAsString()) as Map<String, dynamic>;
        final patterns = rootMeta['patterns'] as List<dynamic>;
        final entry =
            patterns.firstWhere(
                  (p) =>
                      (p as Map<String, dynamic>)['id'] == 'podcast-fallback',
                )
                as Map<String, dynamic>;
        expect(entry['displayName'], equals('podcast-fallback'));
      });

      test('returns 400 for non-object body', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/patterns'),
          headers: {'Content-Type': 'application/json'},
          body: '"just a string"',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final responseBody =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(responseBody['error'], contains('JSON object'));
      });

      test('returns 400 for invalid JSON syntax', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/configs/patterns'),
          headers: {'Content-Type': 'application/json'},
          body: '{not valid json',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final responseBody =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(responseBody['error'], contains('Invalid JSON'));
      });

      test('returns 500 when create fails on broken directory', () async {
        // Create a file where the pattern directory should be created,
        // blocking directory creation.
        await File(
          '$dataDir/patterns/podcast-blocked',
        ).writeAsString('blocker');

        final body = {
          'id': 'podcast-blocked',
          'meta': {
            'id': 'podcast-blocked',
            'feedUrls': ['https://example.com/blocked/feed.xml'],
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

        expect(response.statusCode, equals(500));
        final responseBody =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(responseBody['error'], contains('Failed to create pattern'));
      });
    });

    group('DELETE routes error handling', () {
      test('DELETE playlist returns 404 for non-existent file', () async {
        final request = Request(
          'DELETE',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a'
            '/playlists/nonexistent',
          ),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(404));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('not found'));
      });

      test('DELETE pattern returns 404 for non-existent pattern', () async {
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

      test('DELETE playlist returns 404 on non-existent directory', () async {
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
          'DELETE',
          Uri.parse(
            'http://localhost/api/configs/patterns/podcast-a'
            '/playlists/seasons',
          ),
        );

        final response = await failRouter.call(request);

        // deletePlaylist on non-existent dir throws FileSystemException -> 404
        expect(response.statusCode, equals(404));
      });

      test('DELETE pattern returns 404 on non-existent directory', () async {
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
          'DELETE',
          Uri.parse('http://localhost/api/configs/patterns/podcast-a'),
        );

        final response = await failRouter.call(request);

        // deletePattern on non-existent dir throws FileSystemException -> 404
        expect(response.statusCode, equals(404));
      });
    });
  });
}
