import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

SimpleEpisodeData _makeEpisode(
  int id, {
  String? title,
  int? seasonNumber,
  DateTime? publishedAt,
}) {
  return SimpleEpisodeData(
    id: id,
    title: title ?? 'Episode $id',
    seasonNumber: seasonNumber,
    publishedAt: publishedAt ?? DateTime(2024, 1, id),
  );
}

void main() {
  group('SmartPlaylistResolverService', () {
    late SmartPlaylistResolverService service;

    setUp(() {
      service = SmartPlaylistResolverService(
        resolvers: [RssMetadataResolver(), YearResolver()],
        patterns: [],
      );
    });

    test('returns null when no resolver succeeds', () {
      final episodes = [_makeEpisode(1), _makeEpisode(2)];
      // Strip date/season fields so no resolver can group them
      final noDateEpisodes = episodes
          .map((e) => SimpleEpisodeData(id: e.id, title: e.title))
          .toList();

      final result = service.resolveSmartPlaylists(
        podcastGuid: null,
        feedUrl: 'https://example.com/feed',
        episodes: noDateEpisodes,
      );

      expect(result, isNull);
    });

    test('uses first successful resolver (RssMetadataResolver)', () {
      final episodes = [
        _makeEpisode(1, seasonNumber: 1, publishedAt: DateTime(2024, 1, 1)),
        _makeEpisode(2, seasonNumber: 1, publishedAt: DateTime(2024, 2, 1)),
      ];

      final result = service.resolveSmartPlaylists(
        podcastGuid: null,
        feedUrl: 'https://example.com/feed',
        episodes: episodes,
      );

      expect(result, isNotNull);
      expect(result!.resolverType, 'rss');
    });

    test('falls back to next resolver when first fails', () {
      final episodes = [
        _makeEpisode(1, publishedAt: DateTime(2023, 6, 1)),
        _makeEpisode(2, publishedAt: DateTime(2024, 3, 1)),
      ];

      final result = service.resolveSmartPlaylists(
        podcastGuid: null,
        feedUrl: 'https://example.com/feed',
        episodes: episodes,
      );

      expect(result, isNotNull);
      expect(result!.resolverType, 'year');
    });

    test('uses custom pattern config when podcast matches', () {
      final serviceWithPattern = SmartPlaylistResolverService(
        resolvers: [RssMetadataResolver(), YearResolver()],
        patterns: [
          SmartPlaylistPatternConfig(
            id: 'test_pattern',
            feedUrlPatterns: [r'https://example\.com/feed\.rss'],
            playlists: [
              SmartPlaylistDefinition(
                id: 'main',
                displayName: 'Main',
                resolverType: 'rss',
              ),
            ],
          ),
        ],
      );

      final episodes = [
        SimpleEpisodeData(
          id: 1,
          title: 'Ep1 First',
          seasonNumber: 1,
          publishedAt: DateTime(2024, 1, 1),
        ),
        SimpleEpisodeData(
          id: 2,
          title: 'Ep2 Second',
          seasonNumber: 1,
          publishedAt: DateTime(2024, 1, 2),
        ),
      ];

      final result = serviceWithPattern.resolveSmartPlaylists(
        podcastGuid: null,
        feedUrl: 'https://example.com/feed.rss',
        episodes: episodes,
      );

      expect(result, isNotNull);
      expect(result!.resolverType, 'rss');
    });

    test('wraps resolver playlists as groups when contentType is groups', () {
      final serviceWithGroups = SmartPlaylistResolverService(
        resolvers: [RssMetadataResolver()],
        patterns: [
          SmartPlaylistPatternConfig(
            id: 'test',
            feedUrlPatterns: [r'https://example\.com/feed'],
            playlists: [
              SmartPlaylistDefinition(
                id: 'regular',
                displayName: 'Regular Series',
                resolverType: 'rss',
                contentType: 'groups',
                yearHeaderMode: 'firstEpisode',
              ),
            ],
          ),
        ],
      );

      final episodes = [
        _makeEpisode(1, seasonNumber: 1, title: 'S1E1'),
        _makeEpisode(2, seasonNumber: 1, title: 'S1E2'),
        _makeEpisode(3, seasonNumber: 2, title: 'S2E1'),
      ];

      final result = serviceWithGroups.resolveSmartPlaylists(
        podcastGuid: null,
        feedUrl: 'https://example.com/feed',
        episodes: episodes,
      );

      expect(result, isNotNull);
      // One parent playlist, not two separate season playlists
      expect(result!.playlists, hasLength(1));

      final playlist = result.playlists.first;
      expect(playlist.id, 'regular');
      expect(playlist.displayName, 'Regular Series');
      expect(playlist.contentType, SmartPlaylistContentType.groups);
      expect(playlist.yearHeaderMode, YearHeaderMode.firstEpisode);
      expect(playlist.episodeIds, unorderedEquals([1, 2, 3]));

      // Seasons become groups inside the playlist
      expect(playlist.groups, isNotNull);
      expect(playlist.groups, hasLength(2));
      expect(
        playlist.groups!.map((g) => g.id),
        containsAll(['season_1', 'season_2']),
      );
    });

    test('multiple definitions produce separate parent playlists', () {
      final serviceWithMultiple = SmartPlaylistResolverService(
        resolvers: [RssMetadataResolver()],
        patterns: [
          SmartPlaylistPatternConfig(
            id: 'test',
            feedUrlPatterns: [r'https://example\.com/feed'],
            playlists: [
              SmartPlaylistDefinition(
                id: 'main',
                displayName: 'Main',
                resolverType: 'rss',
                contentType: 'groups',
                priority: 10,
                titleFilter: r'Main',
              ),
              SmartPlaylistDefinition(
                id: 'extras',
                displayName: 'Extras',
                resolverType: 'rss',
                contentType: 'groups',
              ),
            ],
          ),
        ],
      );

      final episodes = [
        _makeEpisode(1, seasonNumber: 1, title: 'Main S1E1'),
        _makeEpisode(2, seasonNumber: 1, title: 'Main S1E2'),
        _makeEpisode(3, seasonNumber: 1, title: 'Extra Bonus'),
      ];

      final result = serviceWithMultiple.resolveSmartPlaylists(
        podcastGuid: null,
        feedUrl: 'https://example.com/feed',
        episodes: episodes,
      );

      expect(result, isNotNull);
      // Two parent playlists (Main and Extras)
      expect(result!.playlists, hasLength(2));
      expect(result.playlists[0].displayName, 'Main');
      expect(result.playlists[0].groups, isNotNull);
      expect(result.playlists[1].displayName, 'Extras');
    });

    test('episodes mode keeps resolver playlists as top-level', () {
      final serviceWithEpisodes = SmartPlaylistResolverService(
        resolvers: [RssMetadataResolver()],
        patterns: [
          SmartPlaylistPatternConfig(
            id: 'test',
            feedUrlPatterns: [r'https://example\.com/feed'],
            playlists: [
              SmartPlaylistDefinition(
                id: 'all',
                displayName: 'All',
                resolverType: 'rss',
                contentType: 'episodes',
              ),
            ],
          ),
        ],
      );

      final episodes = [
        _makeEpisode(1, seasonNumber: 1, title: 'S1E1'),
        _makeEpisode(2, seasonNumber: 2, title: 'S2E1'),
      ];

      final result = serviceWithEpisodes.resolveSmartPlaylists(
        podcastGuid: null,
        feedUrl: 'https://example.com/feed',
        episodes: episodes,
      );

      expect(result, isNotNull);
      // Episodes mode: each season is a separate top-level playlist
      expect(result!.playlists, hasLength(2));
      expect(result.playlists.first.groups, isNull);
    });

    test('routes episodes by titleFilter and excludeFilter', () {
      final serviceWithFilters = SmartPlaylistResolverService(
        resolvers: [RssMetadataResolver(), YearResolver()],
        patterns: [
          SmartPlaylistPatternConfig(
            id: 'filter_test',
            feedUrlPatterns: [r'https://example\.com/feed'],
            playlists: [
              SmartPlaylistDefinition(
                id: 'bonus',
                displayName: 'Bonus',
                resolverType: 'year',
                priority: 10,
                requireFilter: r'Bonus',
              ),
              SmartPlaylistDefinition(
                id: 'main',
                displayName: 'Main',
                resolverType: 'year',
                excludeFilter: r'Bonus',
              ),
            ],
          ),
        ],
      );

      final episodes = [
        _makeEpisode(
          1,
          title: 'Ep1 Main Story',
          publishedAt: DateTime(2024, 1, 1),
        ),
        _makeEpisode(
          2,
          title: 'Bonus: Behind the Scenes',
          publishedAt: DateTime(2024, 2, 1),
        ),
        _makeEpisode(
          3,
          title: 'Ep2 Main Story',
          publishedAt: DateTime(2024, 3, 1),
        ),
        _makeEpisode(
          4,
          title: 'Bonus: Outtakes',
          publishedAt: DateTime(2024, 4, 1),
        ),
      ];

      final result = serviceWithFilters.resolveSmartPlaylists(
        podcastGuid: null,
        feedUrl: 'https://example.com/feed',
        episodes: episodes,
      );

      expect(result, isNotNull);

      // All episodes in 2024, so each definition produces one
      // year-based playlist. Bonus (higher priority) is resolved
      // first, then main gets remaining episodes.
      expect(result!.playlists.length, 2);

      // Collect all episode IDs per playlist
      final firstIds = result.playlists[0].episodeIds;
      final secondIds = result.playlists[1].episodeIds;

      // Bonus playlist gets episodes matching requireFilter
      expect(firstIds, unorderedEquals([2, 4]));
      // Main playlist gets episodes not matching excludeFilter
      expect(secondIds, unorderedEquals([1, 3]));
    });
  });
}
