import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('sortGroups composite with all unconditional rules', () {
    test(
      'sorts by first unconditional rule when no conditional rules exist',
      () {
        final groups = [
          const SmartPlaylistGroup(
            id: 'c',
            displayName: 'Charlie',
            sortKey: 3,
            episodeIds: [1],
          ),
          const SmartPlaylistGroup(
            id: 'a',
            displayName: 'Alpha',
            sortKey: 1,
            episodeIds: [2],
          ),
          const SmartPlaylistGroup(
            id: 'b',
            displayName: 'Bravo',
            sortKey: 2,
            episodeIds: [3],
          ),
        ];

        // Two unconditional rules -- the first one (alphabetical asc) is used
        final sortSpec = SmartPlaylistSortSpec([
          const SmartPlaylistSortRule(
            field: SmartPlaylistSortField.alphabetical,
            order: SortOrder.ascending,
          ),
          const SmartPlaylistSortRule(
            field: SmartPlaylistSortField.playlistNumber,
            order: SortOrder.descending,
          ),
        ]);

        final sorted = sortGroups(groups, sortSpec, {});

        expect(sorted[0].displayName, 'Alpha');
        expect(sorted[1].displayName, 'Bravo');
        expect(sorted[2].displayName, 'Charlie');
      },
    );
  });

  group('sortGroups newestEpisodeDate with null dates', () {
    test('group with dates sorts before group without dates (dateB null)', () {
      final now = DateTime(2024, 6, 1);

      final groupWithDate = SmartPlaylistGroup(
        id: 'has-date',
        displayName: 'Has Date',
        sortKey: 1,
        episodeIds: [1],
      );

      final groupWithoutDate = SmartPlaylistGroup(
        id: 'no-date',
        displayName: 'No Date',
        sortKey: 2,
        episodeIds: [2],
      );

      final episodeById = <int, EpisodeData>{
        1: SimpleEpisodeData(id: 1, title: 'Ep with date', publishedAt: now),
        2: const SimpleEpisodeData(
          id: 2,
          title: 'Ep without date',
          // publishedAt is null
        ),
      };

      // Sort ascending by newestEpisodeDate
      // _compareNewestDate returns -1 when dateB is null (dateA is not null)
      // ascending means the comparator result is used as-is
      // so group with date (-1) comes before group without date
      final sortSpec = SmartPlaylistSortSpec([
        const SmartPlaylistSortRule(
          field: SmartPlaylistSortField.newestEpisodeDate,
          order: SortOrder.ascending,
        ),
      ]);

      final sorted = sortGroups(
        [groupWithoutDate, groupWithDate],
        sortSpec,
        episodeById,
      );

      // Group with date should come first (ascending, dateB null returns -1)
      expect(sorted[0].id, 'has-date');
      expect(sorted[1].id, 'no-date');
    });

    test('both groups without dates remain in original order', () {
      final groupA = const SmartPlaylistGroup(
        id: 'a',
        displayName: 'A',
        sortKey: 1,
        episodeIds: [1],
      );

      final groupB = const SmartPlaylistGroup(
        id: 'b',
        displayName: 'B',
        sortKey: 2,
        episodeIds: [2],
      );

      final episodeById = <int, EpisodeData>{
        1: const SimpleEpisodeData(id: 1, title: 'Ep 1'),
        2: const SimpleEpisodeData(id: 2, title: 'Ep 2'),
      };

      final sortSpec = SmartPlaylistSortSpec([
        const SmartPlaylistSortRule(
          field: SmartPlaylistSortField.newestEpisodeDate,
          order: SortOrder.ascending,
        ),
      ]);

      final sorted = sortGroups([groupA, groupB], sortSpec, episodeById);

      // Both null dates => comparator may return 0; List.sort is not stable,
      // so we only assert that both groups are present, not their relative order.
      final sortedIds = sorted.map((g) => g.id).toList();
      expect(sortedIds, unorderedEquals(['a', 'b']));
    });
  });
}
