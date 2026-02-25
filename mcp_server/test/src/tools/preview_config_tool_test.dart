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

    test('includes groups in response for category resolver', () async {
      final config = {
        'id': 'test',
        'feedUrls': ['https://example.com/feed.xml'],
        'playlists': [
          {
            'id': 'extras',
            'displayName': 'Extras',
            'resolverType': 'category',
            'contentType': 'groups',
            'groups': [
              {
                'id': 'season1',
                'displayName': 'Season 1',
                'pattern': 'Season 1',
              },
              {'id': 'other', 'displayName': 'Other', 'pattern': ''},
            ],
          },
        ],
      };
      final result = await executePreviewConfig(feedService, {
        'config': config,
        'feedUrl': 'https://example.com/feed.xml',
      });

      final playlists = result['playlists'] as List;
      expect(playlists, isNotEmpty);

      final playlist = playlists[0] as Map<String, dynamic>;
      expect(playlist.containsKey('groups'), isTrue);

      final groups = playlist['groups'] as List;
      expect(groups, isNotEmpty);

      final group = groups[0] as Map<String, dynamic>;
      expect(group.containsKey('id'), isTrue);
      expect(group.containsKey('displayName'), isTrue);
      expect(group.containsKey('episodeCount'), isTrue);
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
