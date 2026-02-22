import 'dart:io';

import 'package:sp_mcp_server/src/tools/fetch_feed_tool.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('fetchFeedTool definition', () {
    test('has correct name', () {
      expect(fetchFeedTool.name, 'fetch_feed');
    });

    test('url is required', () {
      final required = fetchFeedTool.inputSchema['required'] as List<dynamic>?;
      expect(required, contains('url'));
    });
  });

  group('executeFetchFeed', () {
    late Directory tempDir;
    late DiskFeedCacheService feedService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('feed_test_');
      feedService = DiskFeedCacheService(
        cacheDir: '${tempDir.path}/cache',
        httpGet: _fakeHttpGet,
      );
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('throws ArgumentError when url is missing', () async {
      expect(
        () => executeFetchFeed(feedService, {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when url is empty', () async {
      expect(
        () => executeFetchFeed(feedService, {'url': ''}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns episodes from feed', () async {
      final result = await executeFetchFeed(
        feedService,
        {'url': 'https://example.com/feed.xml'},
      );

      expect(result['episodes'], isList);
      final episodes = result['episodes'] as List;
      expect(episodes.length, 1);
      expect((episodes[0] as Map)['title'], 'Test Episode');
    });
  });
}

/// Fake HTTP GET that returns a minimal RSS feed.
Future<String> _fakeHttpGet(Uri url) async {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Podcast</title>
    <item>
      <title>Test Episode</title>
      <guid>ep-1</guid>
      <pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';
}
