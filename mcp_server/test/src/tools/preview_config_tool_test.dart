import 'dart:io';

import 'package:sp_mcp_server/src/tools/preview_config_tool.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('previewConfigTool definition', () {
    test('has correct name', () {
      expect(previewConfigTool.name, 'preview_config');
    });

    test('config and feedUrl are required', () {
      final required =
          previewConfigTool.inputSchema['required'] as List<dynamic>?;
      expect(required, containsAll(['config', 'feedUrl']));
    });
  });

  group('executePreviewConfig', () {
    late Directory tempDir;
    late DiskFeedCacheService feedService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('preview_test_');
      feedService = DiskFeedCacheService(
        cacheDir: '${tempDir.path}/cache',
        httpGet: _fakeHttpGet,
      );
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('throws ArgumentError when config is missing', () async {
      expect(
        () => executePreviewConfig(feedService, {
          'feedUrl': 'https://example.com/feed.xml',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when feedUrl is missing', () async {
      expect(
        () => executePreviewConfig(feedService, {
          'config': {'id': 'test', 'playlists': []},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when feedUrl is empty', () async {
      expect(
        () => executePreviewConfig(feedService, {
          'config': {'id': 'test', 'playlists': []},
          'feedUrl': '',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns preview result with playlists', () async {
      final config = {
        'id': 'test',
        'feedUrls': ['https://example.com/feed.xml'],
        'playlists': [
          {'id': 'seasons', 'displayName': 'Seasons', 'resolverType': 'rss'},
        ],
      };
      final result = await executePreviewConfig(feedService, {
        'config': config,
        'feedUrl': 'https://example.com/feed.xml',
      });

      expect(result['playlists'], isList);
      expect(result.containsKey('ungrouped'), isTrue);
      expect(result.containsKey('resolverType'), isTrue);
    });
  });
}

/// Fake HTTP GET that returns an RSS feed with season metadata.
Future<String> _fakeHttpGet(Uri url) async {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Test Podcast</title>
    <item>
      <title>Episode 1</title>
      <guid>ep-1</guid>
      <pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
      <itunes:season>1</itunes:season>
      <itunes:episode>1</itunes:episode>
    </item>
    <item>
      <title>Episode 2</title>
      <guid>ep-2</guid>
      <pubDate>Tue, 02 Jan 2024 00:00:00 GMT</pubDate>
      <itunes:season>1</itunes:season>
      <itunes:episode>2</itunes:episode>
    </item>
  </channel>
</rss>''';
}
