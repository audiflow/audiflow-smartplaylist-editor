import 'dart:convert';
import 'dart:io';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

/// Minimal RSS feed for testing.
const _rssXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Test Podcast</title>
    <item>
      <title>Episode 1</title>
      <description>First episode</description>
      <guid>ep-001</guid>
      <pubDate>Mon, 01 Jan 2024 12:00:00 +0000</pubDate>
      <itunes:season>1</itunes:season>
      <itunes:episode>1</itunes:episode>
      <itunes:image href="https://example.com/ep1.jpg" />
    </item>
    <item>
      <title>Episode 2</title>
      <guid>ep-002</guid>
      <pubDate>Tue, 02 Jan 2024 12:00:00 +0000</pubDate>
      <itunes:season>1</itunes:season>
      <itunes:episode>2</itunes:episode>
    </item>
  </channel>
</rss>
''';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('disk_feed_cache_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DiskFeedCacheService', () {
    test('fetches and caches feed to disk; second call uses cache', () async {
      var fetchCount = 0;
      Future<String> httpGet(Uri url) async {
        fetchCount++;
        return _rssXml;
      }

      final service = DiskFeedCacheService(
        cacheDir: tempDir.path,
        httpGet: httpGet,
      );

      // First call: fetches from network
      final episodes1 = await service.fetchFeed('https://example.com/feed.xml');
      expect(fetchCount, 1);
      expect(episodes1, hasLength(2));
      expect(episodes1[0]['title'], 'Episode 1');
      expect(episodes1[0]['guid'], 'ep-001');
      expect(episodes1[0]['seasonNumber'], 1);
      expect(episodes1[0]['episodeNumber'], 1);
      expect(episodes1[0]['imageUrl'], 'https://example.com/ep1.jpg');
      expect(episodes1[0]['description'], 'First episode');
      expect(episodes1[0]['publishedAt'], isNotNull);

      expect(episodes1[1]['title'], 'Episode 2');
      expect(episodes1[1]['description'], isNull);
      expect(episodes1[1]['imageUrl'], isNull);

      // Second call: served from cache, no additional fetch
      final episodes2 = await service.fetchFeed('https://example.com/feed.xml');
      expect(fetchCount, 1);
      expect(episodes2, hasLength(2));
      expect(episodes2[0]['title'], 'Episode 1');
    });

    test('refetches when cache is stale', () async {
      var fetchCount = 0;
      Future<String> httpGet(Uri url) async {
        fetchCount++;
        return _rssXml;
      }

      final service = DiskFeedCacheService(
        cacheDir: tempDir.path,
        httpGet: httpGet,
        cacheTtl: Duration.zero,
      );

      await service.fetchFeed('https://example.com/feed.xml');
      expect(fetchCount, 1);

      // TTL is zero so cache is immediately stale
      await service.fetchFeed('https://example.com/feed.xml');
      expect(fetchCount, 2);
    });

    test('creates cache directory if missing', () async {
      final nestedDir = '${tempDir.path}/nested/deep/cache';
      expect(Directory(nestedDir).existsSync(), isFalse);

      final service = DiskFeedCacheService(
        cacheDir: nestedDir,
        httpGet: (_) async => _rssXml,
      );

      final episodes = await service.fetchFeed('https://example.com/feed.xml');
      expect(episodes, hasLength(2));
      expect(Directory(nestedDir).existsSync(), isTrue);
    });

    test('shared cache between instances', () async {
      var fetchCount = 0;
      Future<String> httpGet(Uri url) async {
        fetchCount++;
        return _rssXml;
      }

      final service1 = DiskFeedCacheService(
        cacheDir: tempDir.path,
        httpGet: httpGet,
      );

      // First instance fetches and caches to disk
      await service1.fetchFeed('https://example.com/feed.xml');
      expect(fetchCount, 1);

      // Second instance points at the same directory
      final service2 = DiskFeedCacheService(
        cacheDir: tempDir.path,
        httpGet: httpGet,
      );

      // Should read from disk cache, no additional fetch
      final episodes = await service2.fetchFeed('https://example.com/feed.xml');
      expect(fetchCount, 1);
      expect(episodes, hasLength(2));
      expect(episodes[0]['title'], 'Episode 1');
    });

    test('caches to disk with meta and json files', () async {
      final service = DiskFeedCacheService(
        cacheDir: tempDir.path,
        httpGet: (_) async => _rssXml,
      );

      await service.fetchFeed('https://example.com/feed.xml');

      // Verify files exist on disk
      final files = tempDir.listSync().whereType<File>().toList();
      final metaFiles = files.where((f) => f.path.endsWith('.meta')).toList();
      final jsonFiles = files
          .where((f) => f.path.endsWith('.json'))
          .toList();

      expect(metaFiles, hasLength(1));
      expect(jsonFiles, hasLength(1));

      // Verify meta file content
      final metaContent =
          jsonDecode(metaFiles.first.readAsStringSync()) as Map<String, dynamic>;
      expect(metaContent['url'], 'https://example.com/feed.xml');
      expect(metaContent['fetchedAt'], isA<String>());
    });

    test('handles invalid RSS XML gracefully', () async {
      final service = DiskFeedCacheService(
        cacheDir: tempDir.path,
        httpGet: (_) async => 'not valid xml <<>',
      );

      final episodes = await service.fetchFeed('https://example.com/bad.xml');
      expect(episodes, isEmpty);
    });

    test('parses RFC 2822 dates from RSS', () async {
      final service = DiskFeedCacheService(
        cacheDir: tempDir.path,
        httpGet: (_) async => _rssXml,
      );

      final episodes = await service.fetchFeed('https://example.com/feed.xml');
      // "Mon, 01 Jan 2024 12:00:00 +0000" should parse to ISO 8601
      final publishedAt = episodes[0]['publishedAt'] as String;
      expect(publishedAt, contains('2024-01-01'));
    });
  });
}
