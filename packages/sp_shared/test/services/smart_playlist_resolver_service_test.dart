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
            feedUrls: ['https://example.com/feed.rss'],
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
            feedUrls: ['https://example.com/feed'],
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
            feedUrls: ['https://example.com/feed'],
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
            feedUrls: ['https://example.com/feed'],
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
            feedUrls: ['https://example.com/feed'],
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

    group('episode sorting by publishedAt', () {
      test('sorts episodes in direct playlists (episodes mode)', () {
        final serviceWithConfig = SmartPlaylistResolverService(
          resolvers: [RssMetadataResolver()],
          patterns: [
            SmartPlaylistPatternConfig(
              id: 'test',
              feedUrls: ['https://example.com/feed'],
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

        // Episodes given in reverse chronological order
        final episodes = [
          _makeEpisode(
            1,
            seasonNumber: 1,
            title: 'S1E1',
            publishedAt: DateTime(2024, 3, 1),
          ),
          _makeEpisode(
            2,
            seasonNumber: 1,
            title: 'S1E2',
            publishedAt: DateTime(2024, 1, 1),
          ),
          _makeEpisode(
            3,
            seasonNumber: 1,
            title: 'S1E3',
            publishedAt: DateTime(2024, 2, 1),
          ),
        ];

        final result = serviceWithConfig.resolveSmartPlaylists(
          podcastGuid: null,
          feedUrl: 'https://example.com/feed',
          episodes: episodes,
        );

        expect(result, isNotNull);
        // Sorted ascending: Jan(2), Feb(3), Mar(1)
        expect(result!.playlists.first.episodeIds, [2, 3, 1]);
      });

      test('sorts episodes within groups (groups mode)', () {
        final serviceWithGroups = SmartPlaylistResolverService(
          resolvers: [RssMetadataResolver()],
          patterns: [
            SmartPlaylistPatternConfig(
              id: 'test',
              feedUrls: ['https://example.com/feed'],
              playlists: [
                SmartPlaylistDefinition(
                  id: 'series',
                  displayName: 'Series',
                  resolverType: 'rss',
                  contentType: 'groups',
                ),
              ],
            ),
          ],
        );

        // Season 1 episodes in reverse order, season 2 in reverse order
        final episodes = [
          _makeEpisode(
            1,
            seasonNumber: 1,
            title: 'S1E1',
            publishedAt: DateTime(2024, 3, 1),
          ),
          _makeEpisode(
            2,
            seasonNumber: 1,
            title: 'S1E2',
            publishedAt: DateTime(2024, 1, 1),
          ),
          _makeEpisode(
            3,
            seasonNumber: 2,
            title: 'S2E1',
            publishedAt: DateTime(2024, 6, 1),
          ),
          _makeEpisode(
            4,
            seasonNumber: 2,
            title: 'S2E2',
            publishedAt: DateTime(2024, 4, 1),
          ),
        ];

        final result = serviceWithGroups.resolveSmartPlaylists(
          podcastGuid: null,
          feedUrl: 'https://example.com/feed',
          episodes: episodes,
        );

        expect(result, isNotNull);
        final playlist = result!.playlists.first;
        expect(playlist.groups, isNotNull);

        final season1 = playlist.groups!.firstWhere((g) => g.id == 'season_1');
        final season2 = playlist.groups!.firstWhere((g) => g.id == 'season_2');

        // Season 1: Jan(2), Mar(1)
        expect(season1.episodeIds, [2, 1]);
        // Season 2: Apr(4), Jun(3)
        expect(season2.episodeIds, [4, 3]);
      });

      test('sorts ungrouped episode IDs', () {
        // RssMetadataResolver puts episodes without seasonNumber
        // into ungrouped. Mix seasoned and non-seasoned episodes
        // so the resolver produces both grouped and ungrouped.
        final serviceWithConfig = SmartPlaylistResolverService(
          resolvers: [RssMetadataResolver()],
          patterns: [
            SmartPlaylistPatternConfig(
              id: 'test',
              feedUrls: ['https://example.com/feed'],
              playlists: [
                SmartPlaylistDefinition(
                  id: 'series',
                  displayName: 'Series',
                  resolverType: 'rss',
                  contentType: 'episodes',
                ),
              ],
            ),
          ],
        );

        final episodes = [
          _makeEpisode(
            1,
            seasonNumber: 1,
            title: 'S1E1',
            publishedAt: DateTime(2024, 6, 1),
          ),
          // No season number -- becomes ungrouped
          SimpleEpisodeData(
            id: 2,
            title: 'Bonus A',
            publishedAt: DateTime(2024, 4, 1),
          ),
          SimpleEpisodeData(
            id: 3,
            title: 'Bonus B',
            publishedAt: DateTime(2024, 1, 1),
          ),
          SimpleEpisodeData(
            id: 4,
            title: 'Bonus C',
            publishedAt: DateTime(2024, 2, 1),
          ),
        ];

        final result = serviceWithConfig.resolveSmartPlaylists(
          podcastGuid: null,
          feedUrl: 'https://example.com/feed',
          episodes: episodes,
        );

        expect(result, isNotNull);
        // Ungrouped sorted by publishedAt ascending: Jan(3), Feb(4), Apr(2)
        expect(result!.ungroupedEpisodeIds, [3, 4, 2]);
      });

      test('sorts episodes in fallback resolver path', () {
        // No patterns -- fallback to YearResolver
        final episodes = [
          _makeEpisode(1, publishedAt: DateTime(2024, 12, 1)),
          _makeEpisode(2, publishedAt: DateTime(2023, 3, 1)),
          _makeEpisode(3, publishedAt: DateTime(2024, 1, 1)),
          _makeEpisode(4, publishedAt: DateTime(2023, 9, 1)),
        ];

        final result = service.resolveSmartPlaylists(
          podcastGuid: null,
          feedUrl: 'https://example.com/feed',
          episodes: episodes,
        );

        expect(result, isNotNull);
        expect(result!.resolverType, 'year');

        // Each year playlist should have sorted episode IDs
        for (final playlist in result.playlists) {
          final ids = playlist.episodeIds;
          if (ids.contains(2)) {
            // 2023 playlist: Mar(2), Sep(4)
            expect(ids, [2, 4]);
          } else {
            // 2024 playlist: Jan(3), Dec(1)
            expect(ids, [3, 1]);
          }
        }
      });
    });
  });
}
