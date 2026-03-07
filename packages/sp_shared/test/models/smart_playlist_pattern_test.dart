import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistPattern', () {
    test('constructor creates instance with required fields', () {
      const pattern = SmartPlaylistPattern(
        id: 'test-pattern',
        resolverType: 'rss',
        config: {'key': 'value'},
      );

      expect(pattern.id, 'test-pattern');
      expect(pattern.resolverType, 'rss');
      expect(pattern.config, {'key': 'value'});
      expect(pattern.podcastGuid, isNull);
      expect(pattern.feedUrls, isNull);
      expect(pattern.priority, 0);
      expect(pattern.customSort, isNull);
      expect(pattern.titleExtractor, isNull);
      expect(pattern.smartPlaylistEpisodeExtractor, isNull);
      expect(pattern.yearGroupedEpisodes, false);
    });

    test('constructor creates instance with all fields', () {
      const sort = SmartPlaylistSortSpec([
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.playlistNumber,
          order: SortOrder.ascending,
        ),
      ]);
      const extractor = SmartPlaylistTitleExtractor(source: 'title');
      const episodeExtractor = SmartPlaylistEpisodeExtractor(
        source: 'title',
        pattern: r'(\d+)',
      );

      const pattern = SmartPlaylistPattern(
        id: 'full-pattern',
        podcastGuid: 'guid-123',
        feedUrls: ['https://example.com/feed'],
        resolverType: 'category',
        config: {},
        priority: 5,
        customSort: sort,
        titleExtractor: extractor,
        smartPlaylistEpisodeExtractor: episodeExtractor,
        yearGroupedEpisodes: true,
      );

      expect(pattern.podcastGuid, 'guid-123');
      expect(pattern.feedUrls, ['https://example.com/feed']);
      expect(pattern.priority, 5);
      expect(pattern.customSort, isNotNull);
      expect(pattern.titleExtractor, isNotNull);
      expect(pattern.smartPlaylistEpisodeExtractor, isNotNull);
      expect(pattern.yearGroupedEpisodes, true);
    });

    group('matchesPodcast', () {
      test('matches by podcastGuid when guid matches', () {
        const pattern = SmartPlaylistPattern(
          id: 'p1',
          podcastGuid: 'guid-abc',
          feedUrls: ['https://other.com/feed'],
          resolverType: 'rss',
          config: {},
        );

        expect(pattern.matchesPodcast('guid-abc', 'https://unrelated.com'), true);
      });

      test('does not match when guid differs', () {
        const pattern = SmartPlaylistPattern(
          id: 'p1',
          podcastGuid: 'guid-abc',
          resolverType: 'rss',
          config: {},
        );

        expect(pattern.matchesPodcast('guid-xyz', 'https://example.com'), false);
      });

      test('matches by feedUrl when guid is null', () {
        const pattern = SmartPlaylistPattern(
          id: 'p1',
          feedUrls: ['https://example.com/feed'],
          resolverType: 'rss',
          config: {},
        );

        expect(pattern.matchesPodcast(null, 'https://example.com/feed'), true);
      });

      test('matches by feedUrl when guid does not match', () {
        const pattern = SmartPlaylistPattern(
          id: 'p1',
          podcastGuid: 'guid-abc',
          feedUrls: ['https://example.com/feed'],
          resolverType: 'rss',
          config: {},
        );

        expect(
          pattern.matchesPodcast('guid-wrong', 'https://example.com/feed'),
          true,
        );
      });

      test('returns false when neither guid nor feedUrl matches', () {
        const pattern = SmartPlaylistPattern(
          id: 'p1',
          podcastGuid: 'guid-abc',
          feedUrls: ['https://example.com/feed'],
          resolverType: 'rss',
          config: {},
        );

        expect(
          pattern.matchesPodcast('guid-wrong', 'https://other.com/feed'),
          false,
        );
      });

      test('returns false when both podcastGuid and feedUrls are null', () {
        const pattern = SmartPlaylistPattern(
          id: 'p1',
          resolverType: 'rss',
          config: {},
        );

        expect(pattern.matchesPodcast('any-guid', 'https://any.com'), false);
      });

      test('prefers guid match over feedUrl match', () {
        const pattern = SmartPlaylistPattern(
          id: 'p1',
          podcastGuid: 'guid-abc',
          feedUrls: ['https://example.com/feed'],
          resolverType: 'rss',
          config: {},
        );

        // Matches by guid even with wrong feedUrl
        expect(
          pattern.matchesPodcast('guid-abc', 'https://wrong.com/feed'),
          true,
        );
      });
    });
  });
}
