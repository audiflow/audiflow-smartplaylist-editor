import 'package:test/test.dart';

import 'package:sp_server/src/services/feed_cache_service.dart';

const _sampleRss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"
     xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Test Podcast</title>
    <item>
      <title>Episode 1</title>
      <description>First episode</description>
      <guid>ep-001</guid>
      <pubDate>Mon, 01 Jan 2024 12:00:00 +0000</pubDate>
      <itunes:season>1</itunes:season>
      <itunes:episode>1</itunes:episode>
      <itunes:image href="https://example.com/ep1.jpg"/>
    </item>
    <item>
      <title>Episode 2</title>
      <description>Second episode</description>
      <guid>ep-002</guid>
      <pubDate>Mon, 08 Jan 2024 12:00:00 +0000</pubDate>
      <itunes:season>1</itunes:season>
      <itunes:episode>2</itunes:episode>
    </item>
  </channel>
</rss>
''';

const _minimalRss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Minimal Podcast</title>
    <item>
      <title>Just a Title</title>
    </item>
  </channel>
</rss>
''';

void main() {
  group('FeedCacheService', () {
    late int fetchCount;

    HttpGetFn mockHttpGet(String response) {
      fetchCount = 0;
      return (Uri url) async {
        fetchCount++;
        return response;
      };
    }

    group('RSS parsing', () {
      test('parses episodes with all fields', () async {
        final service = FeedCacheService(httpGet: mockHttpGet(_sampleRss));

        final episodes = await service.fetchFeed(
          'https://example.com/feed.xml',
        );

        expect(episodes.length, equals(2));

        final ep1 = episodes[0];
        expect(ep1['title'], equals('Episode 1'));
        expect(ep1['description'], equals('First episode'));
        expect(ep1['guid'], equals('ep-001'));
        expect(ep1['seasonNumber'], equals(1));
        expect(ep1['episodeNumber'], equals(1));
        expect(ep1['publishedAt'], isNotNull);
        expect(ep1['imageUrl'], equals('https://example.com/ep1.jpg'));

        final ep2 = episodes[1];
        expect(ep2['title'], equals('Episode 2'));
        expect(ep2['episodeNumber'], equals(2));
        expect(ep2['imageUrl'], isNull);
      });

      test('parses minimal RSS with missing fields', () async {
        final service = FeedCacheService(httpGet: mockHttpGet(_minimalRss));

        final episodes = await service.fetchFeed(
          'https://example.com/minimal.xml',
        );

        expect(episodes.length, equals(1));
        final ep = episodes[0];
        expect(ep['title'], equals('Just a Title'));
        expect(ep['description'], isNull);
        expect(ep['guid'], isNull);
        expect(ep['seasonNumber'], isNull);
        expect(ep['episodeNumber'], isNull);
        expect(ep['imageUrl'], isNull);
      });

      test('returns empty list for invalid XML', () async {
        final service = FeedCacheService(
          httpGet: mockHttpGet('not xml at all'),
        );

        final episodes = await service.fetchFeed('https://example.com/bad.xml');

        expect(episodes, isEmpty);
      });

      test('returns empty list for XML without items', () async {
        const emptyFeed = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel><title>Empty</title></channel>
</rss>
''';
        final service = FeedCacheService(httpGet: mockHttpGet(emptyFeed));

        final episodes = await service.fetchFeed(
          'https://example.com/empty.xml',
        );

        expect(episodes, isEmpty);
      });
    });

    group('caching', () {
      test('returns cached data on second call', () async {
        final service = FeedCacheService(httpGet: mockHttpGet(_sampleRss));
        const url = 'https://example.com/feed.xml';

        await service.fetchFeed(url);
        expect(fetchCount, equals(1));

        await service.fetchFeed(url);
        expect(fetchCount, equals(1));
      });

      test('fetches different URLs independently', () async {
        final service = FeedCacheService(httpGet: mockHttpGet(_sampleRss));

        await service.fetchFeed('https://example.com/feed1.xml');
        await service.fetchFeed('https://example.com/feed2.xml');

        expect(fetchCount, equals(2));
        expect(service.cacheSize, equals(2));
      });

      test('re-fetches after cache expires', () async {
        final service = FeedCacheService(
          httpGet: mockHttpGet(_sampleRss),
          cacheTtl: Duration.zero,
        );
        const url = 'https://example.com/feed.xml';

        await service.fetchFeed(url);
        expect(fetchCount, equals(1));

        // TTL=0 means immediately stale.
        await service.fetchFeed(url);
        expect(fetchCount, equals(2));
      });

      test('clearCache removes all entries', () async {
        final service = FeedCacheService(httpGet: mockHttpGet(_sampleRss));

        await service.fetchFeed('https://example.com/feed.xml');
        expect(service.cacheSize, equals(1));

        service.clearCache();
        expect(service.cacheSize, equals(0));

        // Fetching again triggers a new HTTP call.
        await service.fetchFeed('https://example.com/feed.xml');
        expect(fetchCount, equals(2));
      });
    });

    group('error propagation', () {
      test('propagates HTTP errors', () async {
        final service = FeedCacheService(
          httpGet: (Uri url) async {
            throw Exception('Network error');
          },
        );

        expect(
          () => service.fetchFeed('https://example.com/feed.xml'),
          throwsException,
        );
      });
    });

    group('date parsing', () {
      test('parses RFC 2822 dates', () async {
        const rssWithDate = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title>Dated Episode</title>
      <pubDate>Wed, 15 Mar 2023 10:30:00 GMT</pubDate>
    </item>
  </channel>
</rss>
''';
        final service = FeedCacheService(httpGet: mockHttpGet(rssWithDate));

        final episodes = await service.fetchFeed(
          'https://example.com/dated.xml',
        );

        expect(episodes[0]['publishedAt'], isNotNull);
        final date = DateTime.parse(episodes[0]['publishedAt'] as String);
        expect(date.year, equals(2023));
        expect(date.month, equals(3));
        expect(date.day, equals(15));
      });

      test('handles ISO 8601 dates', () async {
        const rssWithIso = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title>ISO Date</title>
      <pubDate>2024-06-15T14:30:00Z</pubDate>
    </item>
  </channel>
</rss>
''';
        final service = FeedCacheService(httpGet: mockHttpGet(rssWithIso));

        final episodes = await service.fetchFeed('https://example.com/iso.xml');

        expect(episodes[0]['publishedAt'], isNotNull);
      });

      test('returns null for unparseable dates', () async {
        const rssWithBadDate = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title>Bad Date</title>
      <pubDate>not-a-date</pubDate>
    </item>
  </channel>
</rss>
''';
        final service = FeedCacheService(httpGet: mockHttpGet(rssWithBadDate));

        final episodes = await service.fetchFeed(
          'https://example.com/bad-date.xml',
        );

        expect(episodes[0]['publishedAt'], isNull);
      });
    });
  });

  group('CachedFeed', () {
    test('isStale returns false when fresh', () {
      final feed = CachedFeed(
        episodes: [],
        fetchedAt: DateTime.now(),
        ttl: const Duration(hours: 1),
      );
      expect(feed.isStale, isFalse);
    });

    test('isStale returns true when expired', () {
      final feed = CachedFeed(
        episodes: [],
        fetchedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ttl: const Duration(hours: 1),
      );
      expect(feed.isStale, isTrue);
    });

    test('isStale returns true with zero TTL', () {
      final feed = CachedFeed(
        episodes: [],
        fetchedAt: DateTime.now().subtract(const Duration(milliseconds: 1)),
        ttl: Duration.zero,
      );
      expect(feed.isStale, isTrue);
    });
  });
}
