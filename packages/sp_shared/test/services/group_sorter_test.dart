import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

SmartPlaylistGroup _group(
  String id, {
  int sortKey = 0,
  List<int> episodeIds = const [],
  String? displayName,
}) {
  return SmartPlaylistGroup(
    id: id,
    displayName: displayName ?? id,
    sortKey: sortKey,
    episodeIds: episodeIds,
  );
}

Map<int, EpisodeData> _episodeMap(Map<int, DateTime?> dates) {
  return {
    for (final entry in dates.entries)
      entry.key: SimpleEpisodeData(
        id: entry.key,
        title: 'Ep${entry.key}',
        publishedAt: entry.value,
      ),
  };
}

void main() {
  group('sortGroups', () {
    test('returns groups unchanged when sortSpec is null', () {
      final groups = [_group('b', sortKey: 2), _group('a', sortKey: 1)];

      final result = sortGroups(groups, null, {});

      expect(result.map((g) => g.id), ['b', 'a']);
    });

    test('returns groups unchanged when list has fewer than two elements', () {
      final groups = [_group('a')];
      const sort = SmartPlaylistSortSpec([
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.playlistNumber,
          order: SortOrder.ascending,
        ),
      ]);

      final result = sortGroups(groups, sort, {});

      expect(result.map((g) => g.id), ['a']);
    });

    group('single-rule sort', () {
      test('sorts by playlistNumber ascending', () {
        final groups = [
          _group('c', sortKey: 3),
          _group('a', sortKey: 1),
          _group('b', sortKey: 2),
        ];
        const sort = SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.playlistNumber,
            order: SortOrder.ascending,
          ),
        ]);

        final result = sortGroups(groups, sort, {});

        expect(result.map((g) => g.id), ['a', 'b', 'c']);
      });

      test('sorts by playlistNumber descending', () {
        final groups = [
          _group('a', sortKey: 1),
          _group('c', sortKey: 3),
          _group('b', sortKey: 2),
        ];
        const sort = SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.playlistNumber,
            order: SortOrder.descending,
          ),
        ]);

        final result = sortGroups(groups, sort, {});

        expect(result.map((g) => g.id), ['c', 'b', 'a']);
      });

      test('sorts by newestEpisodeDate ascending', () {
        final groups = [
          _group('late', episodeIds: [1, 2]),
          _group('early', episodeIds: [3, 4]),
          _group('mid', episodeIds: [5]),
        ];
        final episodes = _episodeMap({
          1: DateTime(2024, 6, 1),
          2: DateTime(2024, 12, 1), // newest in 'late'
          3: DateTime(2024, 1, 1), // newest in 'early'
          4: DateTime(2024, 2, 1),
          5: DateTime(2024, 5, 1), // newest in 'mid'
        });
        const sort = SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.newestEpisodeDate,
            order: SortOrder.ascending,
          ),
        ]);

        final result = sortGroups(groups, sort, episodes);

        expect(result.map((g) => g.id), ['early', 'mid', 'late']);
      });

      test('sorts by newestEpisodeDate descending', () {
        final groups = [
          _group('early', episodeIds: [1]),
          _group('late', episodeIds: [2]),
        ];
        final episodes = _episodeMap({
          1: DateTime(2024, 1, 1),
          2: DateTime(2024, 12, 1),
        });
        const sort = SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.newestEpisodeDate,
            order: SortOrder.descending,
          ),
        ]);

        final result = sortGroups(groups, sort, episodes);

        expect(result.map((g) => g.id), ['late', 'early']);
      });

      test('newestEpisodeDate places null-date groups last', () {
        final groups = [
          _group('no-date', episodeIds: [1]),
          _group('has-date', episodeIds: [2]),
        ];
        final episodes = _episodeMap({1: null, 2: DateTime(2024, 1, 1)});
        const sort = SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.newestEpisodeDate,
            order: SortOrder.ascending,
          ),
        ]);

        final result = sortGroups(groups, sort, episodes);

        expect(result.map((g) => g.id), ['has-date', 'no-date']);
      });

      test('sorts alphabetically ascending', () {
        final groups = [
          _group('c', displayName: 'Charlie'),
          _group('a', displayName: 'Alpha'),
          _group('b', displayName: 'Bravo'),
        ];
        const sort = SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.alphabetical,
            order: SortOrder.ascending,
          ),
        ]);

        final result = sortGroups(groups, sort, {});

        expect(result.map((g) => g.id), ['a', 'b', 'c']);
      });

      test('sorts alphabetically descending', () {
        final groups = [
          _group('a', displayName: 'Alpha'),
          _group('c', displayName: 'Charlie'),
          _group('b', displayName: 'Bravo'),
        ];
        const sort = SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.alphabetical,
            order: SortOrder.descending,
          ),
        ]);

        final result = sortGroups(groups, sort, {});

        expect(result.map((g) => g.id), ['c', 'b', 'a']);
      });

      test('progress sort is a no-op', () {
        final groups = [_group('b', sortKey: 2), _group('a', sortKey: 1)];
        const sort = SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.progress,
            order: SortOrder.ascending,
          ),
        ]);

        final result = sortGroups(groups, sort, {});

        // Order preserved since all comparisons return 0
        expect(result.map((g) => g.id), ['b', 'a']);
      });
    });

    group('multi-rule sort', () {
      test('partitions by SortKeyGreaterThan and sorts each partition', () {
        // Simulates coten_radio: seasons (sortKey > 0) ascending,
        // extras (sortKey <= 0) by newestEpisodeDate ascending.
        final groups = [
          _group('extras-new', sortKey: 0, episodeIds: [10]),
          _group('s3', sortKey: 3),
          _group('extras-old', sortKey: -1, episodeIds: [20]),
          _group('s1', sortKey: 1),
          _group('s2', sortKey: 2),
        ];
        final episodes = _episodeMap({
          10: DateTime(2024, 12, 1),
          20: DateTime(2024, 1, 1),
        });

        final sort = SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.playlistNumber,
            order: SortOrder.ascending,
            condition: const SortKeyGreaterThan(0),
          ),
          const SmartPlaylistSortRule(
            field: SmartPlaylistSortField.newestEpisodeDate,
            order: SortOrder.ascending,
          ),
        ]);

        final result = sortGroups(groups, sort, episodes);

        // Conditional partition (sortKey > 0) sorted ascending: s1, s2, s3
        // Unconditional partition sorted by newestDate ascending: extras-old, extras-new
        expect(result.map((g) => g.id), [
          's1',
          's2',
          's3',
          'extras-old',
          'extras-new',
        ]);
      });

      test('falls back to unconditional rule when no conditional rule', () {
        final groups = [
          _group('c', sortKey: 3),
          _group('a', sortKey: 1),
          _group('b', sortKey: 2),
        ];
        final sort = SmartPlaylistSortSpec([
          const SmartPlaylistSortRule(
            field: SmartPlaylistSortField.playlistNumber,
            order: SortOrder.descending,
          ),
        ]);

        final result = sortGroups(groups, sort, {});

        expect(result.map((g) => g.id), ['c', 'b', 'a']);
      });

      test('returns unchanged when no rules match', () {
        final groups = [_group('b'), _group('a')];
        final sort = SmartPlaylistSortSpec([]);

        final result = sortGroups(groups, sort, {});

        expect(result.map((g) => g.id), ['b', 'a']);
      });

      test('all groups match condition leaves unconditional empty', () {
        final groups = [
          _group('s3', sortKey: 3),
          _group('s1', sortKey: 1),
          _group('s2', sortKey: 2),
        ];
        final sort = SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.playlistNumber,
            order: SortOrder.ascending,
            condition: const SortKeyGreaterThan(0),
          ),
          const SmartPlaylistSortRule(
            field: SmartPlaylistSortField.alphabetical,
            order: SortOrder.ascending,
          ),
        ]);

        final result = sortGroups(groups, sort, {});

        expect(result.map((g) => g.id), ['s1', 's2', 's3']);
      });

      test('no groups match condition puts all in unconditional', () {
        final groups = [
          _group('c', sortKey: -1, displayName: 'Charlie'),
          _group('a', sortKey: 0, displayName: 'Alpha'),
          _group('b', sortKey: -2, displayName: 'Bravo'),
        ];
        final sort = SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.playlistNumber,
            order: SortOrder.ascending,
            condition: const SortKeyGreaterThan(0),
          ),
          const SmartPlaylistSortRule(
            field: SmartPlaylistSortField.alphabetical,
            order: SortOrder.ascending,
          ),
        ]);

        final result = sortGroups(groups, sort, {});

        expect(result.map((g) => g.id), ['a', 'b', 'c']);
      });
    });
  });
}
