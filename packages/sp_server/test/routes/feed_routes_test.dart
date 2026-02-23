import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_shared/sp_shared.dart';
import 'package:sp_server/src/routes/feed_routes.dart';

const _sampleRss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"
     xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Test Podcast</title>
    <item>
      <title>Episode One</title>
      <guid>ep-001</guid>
      <itunes:season>1</itunes:season>
      <itunes:episode>1</itunes:episode>
    </item>
    <item>
      <title>Episode Two</title>
      <guid>ep-002</guid>
      <itunes:season>1</itunes:season>
      <itunes:episode>2</itunes:episode>
    </item>
  </channel>
</rss>
''';

void main() {
  group('feedRouter', () {
    late DiskFeedCacheService feedCacheService;
    late Handler handler;
    late Directory cacheDir;

    setUp(() async {
      cacheDir = await Directory.systemTemp.createTemp('feed_routes_test_');
      feedCacheService = DiskFeedCacheService(
        cacheDir: cacheDir.path,
        httpGet: (Uri url) async => _sampleRss,
      );

      final router = feedRouter(feedCacheService: feedCacheService);
      handler = router.call;
    });

    tearDown(() async {
      await cacheDir.delete(recursive: true);
    });

    test('returns 400 when url param is missing', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/feeds'));

      final response = await handler(request);

      expect(response.statusCode, equals(400));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('url'));
    });

    test('returns 400 when url param is empty', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/feeds?url='),
      );

      final response = await handler(request);

      expect(response.statusCode, equals(400));
    });

    test('returns 400 for invalid URL', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/feeds?url=not-a-url'),
      );

      final response = await handler(request);

      expect(response.statusCode, equals(400));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('Invalid'));
    });

    test('returns episodes for valid feed URL', () async {
      final request = Request(
        'GET',
        Uri.parse(
          'http://localhost/api/feeds'
          '?url=https://example.com/feed.xml',
        ),
      );

      final response = await handler(request);

      expect(response.statusCode, equals(200));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      final episodes = body['episodes'] as List;
      expect(episodes.length, equals(2));
      expect(episodes[0]['title'], equals('Episode One'));
      expect(episodes[1]['title'], equals('Episode Two'));
    });

    test('returns 502 when feed fetch fails', () async {
      final failDir = await Directory.systemTemp.createTemp('feed_fail_test_');
      final failingService = DiskFeedCacheService(
        cacheDir: failDir.path,
        httpGet: (Uri url) async {
          throw Exception('Connection refused');
        },
      );

      final router = feedRouter(feedCacheService: failingService);
      final failHandler = router.call;

      final request = Request(
        'GET',
        Uri.parse(
          'http://localhost/api/feeds'
          '?url=https://example.com/fail.xml',
        ),
      );

      final response = await failHandler(request);

      expect(response.statusCode, equals(502));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('Failed'));

      await failDir.delete(recursive: true);
    });

    test('response has JSON content type', () async {
      final request = Request(
        'GET',
        Uri.parse(
          'http://localhost/api/feeds'
          '?url=https://example.com/feed.xml',
        ),
      );

      final response = await handler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });
  });
}
