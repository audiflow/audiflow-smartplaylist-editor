import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('sortGroups alphabetical', () {
    test('sorts by alphabetical ascending', () {
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

      const sortRule = SmartPlaylistSortRule(
        field: SmartPlaylistSortField.alphabetical,
        order: SortOrder.ascending,
      );

      final sorted = sortGroups(groups, sortRule, {});

      expect(sorted[0].displayName, 'Alpha');
      expect(sorted[1].displayName, 'Bravo');
      expect(sorted[2].displayName, 'Charlie');
    });
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
        ),
      };

      const sortRule = SmartPlaylistSortRule(
        field: SmartPlaylistSortField.newestEpisodeDate,
        order: SortOrder.ascending,
      );

      final sorted = sortGroups(
        [groupWithoutDate, groupWithDate],
        sortRule,
        episodeById,
      );

      expect(sorted[0].id, 'has-date');
      expect(sorted[1].id, 'no-date');
    });

    test('both groups without dates are present (order not guaranteed)', () {
      const groupA = SmartPlaylistGroup(
        id: 'a',
        displayName: 'A',
        sortKey: 1,
        episodeIds: [1],
      );

      const groupB = SmartPlaylistGroup(
        id: 'b',
        displayName: 'B',
        sortKey: 2,
        episodeIds: [2],
      );

      final episodeById = <int, EpisodeData>{
        1: const SimpleEpisodeData(id: 1, title: 'Ep 1'),
        2: const SimpleEpisodeData(id: 2, title: 'Ep 2'),
      };

      const sortRule = SmartPlaylistSortRule(
        field: SmartPlaylistSortField.newestEpisodeDate,
        order: SortOrder.ascending,
      );

      final sorted = sortGroups([groupA, groupB], sortRule, episodeById);

      final sortedIds = sorted.map((g) => g.id).toList();
      expect(sortedIds, unorderedEquals(['a', 'b']));
    });
  });
}
