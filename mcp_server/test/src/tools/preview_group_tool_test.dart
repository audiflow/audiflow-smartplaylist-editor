import 'dart:io';

import 'package:sp_mcp_server/src/tools/preview_group_tool.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('previewGroupTool definition', () {
    test('has correct name', () {
      expect(previewGroupTool.name, 'preview_group');
    });

    test('all four parameters are required', () {
      final required =
          previewGroupTool.inputSchema['required'] as List<dynamic>?;
      expect(
        required,
        containsAll(['config', 'feedUrl', 'playlistId', 'groupId']),
      );
    });
  });

  group('executePreviewGroup', () {
    late Directory tempDir;
    late DiskFeedCacheService feedService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('preview_group_test_');
      feedService = DiskFeedCacheService(
        cacheDir: '${tempDir.path}/cache',
        httpGet: _fakeHttpGet,
      );
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('throws ArgumentError when config is missing', () async {
      expect(
        () => executePreviewGroup(feedService, {
          'feedUrl': 'https://example.com/feed.xml',
          'playlistId': 'extras',
          'groupId': 'extra',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when feedUrl is missing', () async {
      expect(
        () => executePreviewGroup(feedService, {
          'config': _categoryConfig(),
          'playlistId': 'extras',
          'groupId': 'extra',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when playlistId is missing', () async {
      expect(
        () => executePreviewGroup(feedService, {
          'config': _categoryConfig(),
          'feedUrl': 'https://example.com/feed.xml',
          'groupId': 'extra',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when groupId is missing', () async {
      expect(
        () => executePreviewGroup(feedService, {
          'config': _categoryConfig(),
          'feedUrl': 'https://example.com/feed.xml',
          'playlistId': 'extras',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for unknown playlistId', () async {
      expect(
        () => executePreviewGroup(feedService, {
          'config': _categoryConfig(),
          'feedUrl': 'https://example.com/feed.xml',
          'playlistId': 'nonexistent',
          'groupId': 'extra',
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('not found'),
          ),
        ),
      );
    });

    test('throws ArgumentError for unknown groupId', () async {
      expect(
        () => executePreviewGroup(feedService, {
          'config': _categoryConfig(),
          'feedUrl': 'https://example.com/feed.xml',
          'playlistId': 'extras',
          'groupId': 'nonexistent',
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('not found'),
          ),
        ),
      );
    });

    test('returns episodes for a specific group', () async {
      final result = await executePreviewGroup(feedService, {
        'config': _categoryConfig(),
        'feedUrl': 'https://example.com/feed.xml',
        'playlistId': 'extras',
        'groupId': 'extra',
      });

      expect(result['group'], isMap);
      final group = result['group'] as Map<String, dynamic>;
      expect(group['id'], 'extra');
      expect(group['displayName'], 'Extra');

      expect(result['episodes'], isList);
      final episodes = result['episodes'] as List;
      expect(episodes, isNotEmpty);

      final ep = episodes[0] as Map<String, dynamic>;
      expect(ep.containsKey('id'), isTrue);
      expect(ep.containsKey('title'), isTrue);
      expect(ep.containsKey('publishedAt'), isTrue);
      expect((ep['title'] as String), contains('Extra'));
    });

    test('does not include episodes from other groups', () async {
      final result = await executePreviewGroup(feedService, {
        'config': _categoryConfig(),
        'feedUrl': 'https://example.com/feed.xml',
        'playlistId': 'extras',
        'groupId': 'extra',
      });

      final episodes = result['episodes'] as List;
      for (final ep in episodes) {
        final title = (ep as Map<String, dynamic>)['title'] as String;
        expect(title, contains('Extra'));
      }
    });
  });
}

/// Config with a category resolver containing two groups.
Map<String, dynamic> _categoryConfig() {
  return {
    'id': 'test',
    'feedUrls': ['https://example.com/feed.xml'],
    'playlists': [
      {
        'id': 'extras',
        'displayName': 'Extras',
        'resolverType': 'category',
        'contentType': 'groups',
        'groups': [
          {'id': 'extra', 'displayName': 'Extra', 'pattern': 'Extra'},
          {'id': 'other', 'displayName': 'Other', 'pattern': ''},
        ],
      },
    ],
  };
}

/// Fake HTTP GET returning a feed with categorizable episodes.
Future<String> _fakeHttpGet(Uri url) async {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Test Podcast</title>
    <item>
      <title>Extra Episode 1</title>
      <guid>ep-1</guid>
      <pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Extra Episode 2</title>
      <guid>ep-2</guid>
      <pubDate>Tue, 02 Jan 2024 00:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Regular Episode</title>
      <guid>ep-3</guid>
      <pubDate>Wed, 03 Jan 2024 00:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';
}
