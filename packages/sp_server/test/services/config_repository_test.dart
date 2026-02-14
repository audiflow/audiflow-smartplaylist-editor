import 'dart:convert';

import 'package:test/test.dart';

import 'package:sp_server/src/services/config_repository.dart';

/// Sample root meta.json.
String _rootMeta() => jsonEncode({
  'version': 1,
  'patterns': [
    {
      'id': 'podcast-a',
      'version': 1,
      'displayName': 'Podcast A',
      'feedUrlHint': 'https://example.com/a/feed.xml',
      'playlistCount': 2,
    },
    {
      'id': 'podcast-b',
      'version': 1,
      'displayName': 'Podcast B',
      'feedUrlHint': 'https://example.com/b/feed.xml',
      'playlistCount': 1,
    },
  ],
});

/// Sample pattern meta.json for podcast-a.
String _patternMetaA() => jsonEncode({
  'version': 1,
  'id': 'podcast-a',
  'podcastGuid': 'guid-a',
  'feedUrls': ['https://example.com/a/feed.xml'],
  'playlists': ['seasons', 'by-year'],
});

/// Sample playlist JSON for seasons.
String _playlistSeasons() => jsonEncode({
  'id': 'seasons',
  'displayName': 'Seasons',
  'resolverType': 'rss',
});

/// Sample playlist JSON for by-year.
String _playlistByYear() => jsonEncode({
  'id': 'by-year',
  'displayName': 'By Year',
  'resolverType': 'year',
});

const _baseUrl = 'https://raw.githubusercontent.com/test/repo/main';

/// Creates a repository with a URL-to-response map.
ConfigRepository _createRepo({
  required Map<String, String> responses,
  void Function()? onFetch,
  Duration rootTtl = const Duration(minutes: 5),
  Duration fileTtl = const Duration(minutes: 30),
}) {
  return ConfigRepository(
    httpGet: (Uri url) async {
      onFetch?.call();
      final response = responses[url.toString()];
      if (response == null) {
        throw Exception('No mock response for: $url');
      }
      return response;
    },
    baseUrl: _baseUrl,
    rootTtl: rootTtl,
    fileTtl: fileTtl,
  );
}

void main() {
  group('ConfigRepository', () {
    group('listPatterns', () {
      test('returns pattern summaries from root meta', () async {
        final repo = _createRepo(
          responses: {'$_baseUrl/meta.json': _rootMeta()},
        );

        final patterns = await repo.listPatterns();

        expect(patterns.length, equals(2));
        expect(patterns[0].id, equals('podcast-a'));
        expect(patterns[0].displayName, equals('Podcast A'));
        expect(patterns[0].playlistCount, equals(2));
        expect(patterns[1].id, equals('podcast-b'));
        expect(patterns[1].playlistCount, equals(1));
      });

      test('caches root meta', () async {
        var fetchCount = 0;
        final repo = _createRepo(
          responses: {'$_baseUrl/meta.json': _rootMeta()},
          onFetch: () => fetchCount++,
        );

        await repo.listPatterns();
        await repo.listPatterns();

        expect(fetchCount, equals(1));
      });

      test('respects root TTL', () async {
        var fetchCount = 0;
        final repo = _createRepo(
          responses: {'$_baseUrl/meta.json': _rootMeta()},
          onFetch: () => fetchCount++,
          rootTtl: Duration.zero,
        );

        await repo.listPatterns();
        await repo.listPatterns();

        expect(fetchCount, equals(2));
      });

      test('throws on unsupported version', () async {
        final repo = _createRepo(
          responses: {
            '$_baseUrl/meta.json': jsonEncode({'version': 99, 'patterns': []}),
          },
        );

        expect(() => repo.listPatterns(), throwsA(isA<FormatException>()));
      });

      test('throws on network error', () async {
        final repo = ConfigRepository(
          httpGet: (_) async => throw Exception('Network error'),
          baseUrl: _baseUrl,
        );

        expect(() => repo.listPatterns(), throwsException);
      });

      test('throws on invalid JSON', () async {
        final repo = _createRepo(
          responses: {'$_baseUrl/meta.json': 'not json'},
        );

        expect(() => repo.listPatterns(), throwsA(isA<FormatException>()));
      });
    });

    group('getPatternMeta', () {
      test('returns pattern metadata', () async {
        final repo = _createRepo(
          responses: {'$_baseUrl/podcast-a/meta.json': _patternMetaA()},
        );

        final meta = await repo.getPatternMeta('podcast-a');

        expect(meta.id, equals('podcast-a'));
        expect(meta.podcastGuid, equals('guid-a'));
        expect(meta.feedUrls, hasLength(1));
        expect(meta.playlists, equals(['seasons', 'by-year']));
      });

      test('caches pattern meta with file TTL', () async {
        var fetchCount = 0;
        final repo = _createRepo(
          responses: {'$_baseUrl/podcast-a/meta.json': _patternMetaA()},
          onFetch: () => fetchCount++,
        );

        await repo.getPatternMeta('podcast-a');
        await repo.getPatternMeta('podcast-a');

        expect(fetchCount, equals(1));
      });

      test('throws on network error', () async {
        final repo = ConfigRepository(
          httpGet: (_) async => throw Exception('Network error'),
          baseUrl: _baseUrl,
        );

        expect(() => repo.getPatternMeta('podcast-a'), throwsException);
      });
    });

    group('getPlaylist', () {
      test('returns playlist definition', () async {
        final repo = _createRepo(
          responses: {
            '$_baseUrl/podcast-a/playlists/seasons.json': _playlistSeasons(),
          },
        );

        final playlist = await repo.getPlaylist('podcast-a', 'seasons');

        expect(playlist.id, equals('seasons'));
        expect(playlist.displayName, equals('Seasons'));
        expect(playlist.resolverType, equals('rss'));
      });

      test('caches playlist with file TTL', () async {
        var fetchCount = 0;
        final repo = _createRepo(
          responses: {
            '$_baseUrl/podcast-a/playlists/seasons.json': _playlistSeasons(),
          },
          onFetch: () => fetchCount++,
        );

        await repo.getPlaylist('podcast-a', 'seasons');
        await repo.getPlaylist('podcast-a', 'seasons');

        expect(fetchCount, equals(1));
      });

      test('throws on network error', () async {
        final repo = ConfigRepository(
          httpGet: (_) async => throw Exception('Not found'),
          baseUrl: _baseUrl,
        );

        expect(() => repo.getPlaylist('podcast-a', 'missing'), throwsException);
      });
    });

    group('assembleConfig', () {
      test('assembles full config from meta and playlists', () async {
        final repo = _createRepo(
          responses: {
            '$_baseUrl/podcast-a/meta.json': _patternMetaA(),
            '$_baseUrl/podcast-a/playlists/seasons.json': _playlistSeasons(),
            '$_baseUrl/podcast-a/playlists/by-year.json': _playlistByYear(),
          },
        );

        final config = await repo.assembleConfig('podcast-a');

        expect(config.id, equals('podcast-a'));
        expect(config.podcastGuid, equals('guid-a'));
        expect(config.playlists.length, equals(2));
        expect(config.playlists[0].id, equals('seasons'));
        expect(config.playlists[1].id, equals('by-year'));
      });

      test('preserves playlist order from meta', () async {
        // Meta lists by-year before seasons
        final reversedMeta = jsonEncode({
          'version': 1,
          'id': 'podcast-a',
          'feedUrls': ['https://example.com/a/feed.xml'],
          'playlists': ['by-year', 'seasons'],
        });

        final repo = _createRepo(
          responses: {
            '$_baseUrl/podcast-a/meta.json': reversedMeta,
            '$_baseUrl/podcast-a/playlists/seasons.json': _playlistSeasons(),
            '$_baseUrl/podcast-a/playlists/by-year.json': _playlistByYear(),
          },
        );

        final config = await repo.assembleConfig('podcast-a');

        expect(config.playlists[0].id, equals('by-year'));
        expect(config.playlists[1].id, equals('seasons'));
      });

      test('caches fetched data across calls', () async {
        var fetchCount = 0;
        final repo = _createRepo(
          responses: {
            '$_baseUrl/podcast-a/meta.json': _patternMetaA(),
            '$_baseUrl/podcast-a/playlists/seasons.json': _playlistSeasons(),
            '$_baseUrl/podcast-a/playlists/by-year.json': _playlistByYear(),
          },
          onFetch: () => fetchCount++,
        );

        await repo.assembleConfig('podcast-a');
        // 1 meta + 2 playlists = 3 fetches
        expect(fetchCount, equals(3));

        await repo.assembleConfig('podcast-a');
        // All cached, still 3
        expect(fetchCount, equals(3));
      });

      test('throws when playlist fetch fails', () async {
        final repo = _createRepo(
          responses: {
            '$_baseUrl/podcast-a/meta.json': _patternMetaA(),
            '$_baseUrl/podcast-a/playlists/seasons.json': _playlistSeasons(),
            // Missing by-year.json
          },
        );

        expect(() => repo.assembleConfig('podcast-a'), throwsException);
      });
    });

    group('clearCache', () {
      test('forces re-fetch after clear', () async {
        var fetchCount = 0;
        final repo = _createRepo(
          responses: {'$_baseUrl/meta.json': _rootMeta()},
          onFetch: () => fetchCount++,
        );

        await repo.listPatterns();
        expect(fetchCount, equals(1));

        repo.clearCache();
        await repo.listPatterns();
        expect(fetchCount, equals(2));
      });
    });

    group('cacheSize', () {
      test('tracks cached entries', () async {
        final repo = _createRepo(
          responses: {
            '$_baseUrl/meta.json': _rootMeta(),
            '$_baseUrl/podcast-a/meta.json': _patternMetaA(),
          },
        );

        expect(repo.cacheSize, equals(0));
        await repo.listPatterns();
        expect(repo.cacheSize, equals(1));
        await repo.getPatternMeta('podcast-a');
        expect(repo.cacheSize, equals(2));
      });
    });

    group('CachedConfig', () {
      test('is not stale within TTL', () {
        final cached = CachedConfig(
          data: 'test',
          fetchedAt: DateTime.now(),
          ttl: const Duration(minutes: 5),
        );

        expect(cached.isStale, isFalse);
      });

      test('is stale after TTL expires', () {
        final cached = CachedConfig(
          data: 'test',
          fetchedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          ttl: const Duration(minutes: 5),
        );

        expect(cached.isStale, isTrue);
      });
    });
  });
}
