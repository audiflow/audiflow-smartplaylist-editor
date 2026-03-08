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
                playlistStructure: 'split',
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

    test(
      'wraps resolver playlists as groups when playlistStructure is grouped',
      () {
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
                  playlistStructure: 'grouped',
                  groupList: const GroupListSettings(yearBinding: 'pinToYear'),
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
        expect(playlist.playlistStructure, PlaylistStructure.grouped);
        expect(playlist.yearBinding, YearBinding.pinToYear);
        expect(playlist.episodeIds, unorderedEquals([1, 2, 3]));

        // Seasons become groups inside the playlist
        expect(playlist.groups, isNotNull);
        expect(playlist.groups, hasLength(2));
        expect(
          playlist.groups!.map((g) => g.id),
          containsAll(['season_1', 'season_2']),
        );
      },
    );

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
                playlistStructure: 'grouped',
                priority: 10,
                episodeFilters: const EpisodeFilters(
                  require: [EpisodeFilterEntry(title: r'Main')],
                ),
              ),
              SmartPlaylistDefinition(
                id: 'extras',
                displayName: 'Extras',
                resolverType: 'rss',
                playlistStructure: 'grouped',
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

    test('split mode keeps resolver playlists as top-level', () {
      final serviceWithSplit = SmartPlaylistResolverService(
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
                playlistStructure: 'split',
              ),
            ],
          ),
        ],
      );

      final episodes = [
        _makeEpisode(1, seasonNumber: 1, title: 'S1E1'),
        _makeEpisode(2, seasonNumber: 2, title: 'S2E1'),
      ];

      final result = serviceWithSplit.resolveSmartPlaylists(
        podcastGuid: null,
        feedUrl: 'https://example.com/feed',
        episodes: episodes,
      );

      expect(result, isNotNull);
      // Split mode: each season is a separate top-level playlist
      expect(result!.playlists, hasLength(2));
      expect(result.playlists.first.groups, isNull);
    });

    test('routes episodes by episodeFilters', () {
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
                playlistStructure: 'split',
                priority: 10,
                episodeFilters: const EpisodeFilters(
                  require: [EpisodeFilterEntry(title: r'Bonus')],
                ),
              ),
              SmartPlaylistDefinition(
                id: 'main',
                displayName: 'Main',
                resolverType: 'year',
                playlistStructure: 'split',
                episodeFilters: const EpisodeFilters(
                  exclude: [EpisodeFilterEntry(title: r'Bonus')],
                ),
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

      expect(result!.playlists.length, 2);

      final firstIds = result.playlists[0].episodeIds;
      final secondIds = result.playlists[1].episodeIds;

      // Main playlist gets episodes not matching exclude filter
      expect(firstIds, unorderedEquals([1, 3]));
      // Bonus playlist gets episodes matching require filter
      expect(secondIds, unorderedEquals([2, 4]));
    });

    test('definitions without episodeFilters act as fallbacks', () {
      final serviceWithFallback = SmartPlaylistResolverService(
        resolvers: [YearResolver()],
        patterns: [
          SmartPlaylistPatternConfig(
            id: 'test',
            feedUrls: ['https://example.com/feed'],
            playlists: [
              SmartPlaylistDefinition(
                id: 'main',
                displayName: 'Main',
                resolverType: 'year',
                playlistStructure: 'split',
              ),
            ],
          ),
        ],
      );

      final episodes = [
        _makeEpisode(1, title: 'Ep 1', publishedAt: DateTime(2024, 1, 1)),
        _makeEpisode(2, title: 'Ep 2', publishedAt: DateTime(2024, 2, 1)),
      ];

      final result = serviceWithFallback.resolveSmartPlaylists(
        podcastGuid: null,
        feedUrl: 'https://example.com/feed',
        episodes: episodes,
      );

      expect(result, isNotNull);
      final allIds = result!.playlists.expand((p) => p.episodeIds).toList();
      expect(allIds, unorderedEquals([1, 2]));
    });

    group('episode sorting by publishedAt', () {
      test('sorts episodes in direct playlists (split mode)', () {
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
                  playlistStructure: 'split',
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

      test('sorts episodes within groups (grouped mode)', () {
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
                  playlistStructure: 'grouped',
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
                  playlistStructure: 'split',
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

    group('resolveForPreview', () {
      test('returns PreviewGrouping with single playlist result', () {
        final serviceWithPattern = SmartPlaylistResolverService(
          resolvers: [RssMetadataResolver()],
          patterns: [
            SmartPlaylistPatternConfig(
              id: 'test',
              feedUrls: ['https://example.com/feed'],
              playlists: [
                SmartPlaylistDefinition(
                  id: 'seasons',
                  displayName: 'Seasons',
                  resolverType: 'rss',
                  playlistStructure: 'grouped',
                ),
              ],
            ),
          ],
        );

        final episodes = [
          _makeEpisode(1, seasonNumber: 1, publishedAt: DateTime(2024, 1, 1)),
          _makeEpisode(2, seasonNumber: 1, publishedAt: DateTime(2024, 2, 1)),
          _makeEpisode(3, seasonNumber: 2, publishedAt: DateTime(2024, 3, 1)),
        ];

        final result = serviceWithPattern.resolveForPreview(
          podcastGuid: null,
          feedUrl: 'https://example.com/feed',
          episodes: episodes,
        );

        expect(result, isNotNull);
        expect(result!.playlistResults, hasLength(1));
        expect(result.playlistResults.first.definitionId, 'seasons');
        expect(result.playlistResults.first.claimedByOthers, isEmpty);
        expect(result.resolverType, 'rss');
      });

      test('returns null for empty episodes', () {
        final result = service.resolveForPreview(
          podcastGuid: null,
          feedUrl: 'https://example.com/feed',
          episodes: [],
        );
        expect(result, isNull);
      });

      test('tracks claimedByOthers between two filtered definitions', () {
        final serviceWithClaiming = SmartPlaylistResolverService(
          resolvers: [YearResolver()],
          patterns: [
            SmartPlaylistPatternConfig(
              id: 'test',
              feedUrls: ['https://example.com/feed'],
              playlists: [
                SmartPlaylistDefinition(
                  id: 'priority-a',
                  displayName: 'Priority A',
                  resolverType: 'year',
                  playlistStructure: 'split',
                  priority: 10,
                  episodeFilters: const EpisodeFilters(
                    require: [EpisodeFilterEntry(title: r'.')],
                  ),
                ),
                SmartPlaylistDefinition(
                  id: 'priority-b',
                  displayName: 'Priority B',
                  resolverType: 'year',
                  playlistStructure: 'split',
                  priority: 5,
                  episodeFilters: const EpisodeFilters(
                    require: [EpisodeFilterEntry(title: r'.')],
                  ),
                ),
              ],
            ),
          ],
        );

        final episodes = [
          _makeEpisode(1, title: 'Ep 1', publishedAt: DateTime(2024, 1, 1)),
          _makeEpisode(2, title: 'Ep 2', publishedAt: DateTime(2024, 2, 1)),
        ];

        final result = serviceWithClaiming.resolveForPreview(
          podcastGuid: null,
          feedUrl: 'https://example.com/feed',
          episodes: episodes,
        );

        expect(result, isNotNull);
        expect(result!.playlistResults, hasLength(2));

        // Priority B (lower number = higher precedence) gets both episodes
        final bResult = result.playlistResults.firstWhere(
          (r) => r.definitionId == 'priority-b',
        );
        expect(bResult.playlist.episodeIds, unorderedEquals([1, 2]));
        expect(bResult.claimedByOthers, isEmpty);

        // Priority A: all candidates were claimed by B
        final aResult = result.playlistResults.firstWhere(
          (r) => r.definitionId == 'priority-a',
        );
        expect(aResult.playlist.episodeIds, isEmpty);
        expect(aResult.claimedByOthers, {1: 'priority-b', 2: 'priority-b'});
      });

      test('sorts episode IDs by publishedAt ascending', () {
        final serviceWithPattern = SmartPlaylistResolverService(
          resolvers: [RssMetadataResolver()],
          patterns: [
            SmartPlaylistPatternConfig(
              id: 'test',
              feedUrls: ['https://example.com/feed'],
              playlists: [
                SmartPlaylistDefinition(
                  id: 'seasons',
                  displayName: 'Seasons',
                  resolverType: 'rss',
                  playlistStructure: 'grouped',
                ),
              ],
            ),
          ],
        );

        // Episodes in reverse chronological order
        final episodes = [
          _makeEpisode(1, seasonNumber: 1, publishedAt: DateTime(2024, 3, 1)),
          _makeEpisode(2, seasonNumber: 1, publishedAt: DateTime(2024, 1, 1)),
          _makeEpisode(3, seasonNumber: 1, publishedAt: DateTime(2024, 2, 1)),
        ];

        final result = serviceWithPattern.resolveForPreview(
          podcastGuid: null,
          feedUrl: 'https://example.com/feed',
          episodes: episodes,
        );

        expect(result, isNotNull);
        // Sorted ascending: Jan(2), Feb(3), Mar(1)
        expect(result!.playlistResults.first.playlist.episodeIds, [2, 3, 1]);
      });

      test('fallback definition without filters has empty claimedByOthers', () {
        final serviceWithFallback = SmartPlaylistResolverService(
          resolvers: [YearResolver()],
          patterns: [
            SmartPlaylistPatternConfig(
              id: 'test',
              feedUrls: ['https://example.com/feed'],
              playlists: [
                SmartPlaylistDefinition(
                  id: 'bonus',
                  displayName: 'Bonus',
                  resolverType: 'year',
                  playlistStructure: 'split',
                  priority: 10,
                  episodeFilters: const EpisodeFilters(
                    require: [EpisodeFilterEntry(title: r'Bonus')],
                  ),
                ),
                SmartPlaylistDefinition(
                  id: 'all',
                  displayName: 'All',
                  resolverType: 'year',
                  playlistStructure: 'split',
                  // no filters = fallback
                ),
              ],
            ),
          ],
        );

        final episodes = [
          _makeEpisode(
            1,
            title: 'Main Ep 1',
            publishedAt: DateTime(2024, 1, 1),
          ),
          _makeEpisode(
            2,
            title: 'Bonus: Extra',
            publishedAt: DateTime(2024, 2, 1),
          ),
          _makeEpisode(
            3,
            title: 'Main Ep 2',
            publishedAt: DateTime(2024, 3, 1),
          ),
        ];

        final result = serviceWithFallback.resolveForPreview(
          podcastGuid: null,
          feedUrl: 'https://example.com/feed',
          episodes: episodes,
        );

        expect(result, isNotNull);
        expect(result!.playlistResults, hasLength(2));

        // Bonus (with filters) claims episode 2
        final bonusResult = result.playlistResults.firstWhere(
          (r) => r.definitionId == 'bonus',
        );
        expect(bonusResult.playlist.episodeIds, [2]);
        expect(bonusResult.claimedByOthers, isEmpty);

        // All (fallback, no filters) gets all unclaimed
        final allResult = result.playlistResults.firstWhere(
          (r) => r.definitionId == 'all',
        );
        expect(allResult.claimedByOthers, isEmpty);
      });
    });
  });
}
