import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

Map<int, EpisodeData> _buildMap(List<SimpleEpisodeData> episodes) {
  return {for (final e in episodes) e.id: e};
}

void main() {
  group('sortEpisodeIdsByPublishedAt', () {
    test('sorts by publishedAt ascending (oldest first)', () {
      final episodes = [
        SimpleEpisodeData(
          id: 1,
          title: 'Ep1',
          publishedAt: DateTime(2024, 3, 1),
        ),
        SimpleEpisodeData(
          id: 2,
          title: 'Ep2',
          publishedAt: DateTime(2024, 1, 1),
        ),
        SimpleEpisodeData(
          id: 3,
          title: 'Ep3',
          publishedAt: DateTime(2024, 2, 1),
        ),
      ];
      final map = _buildMap(episodes);

      final result = sortEpisodeIdsByPublishedAt([1, 2, 3], map);

      expect(result, [2, 3, 1]);
    });

    test('places null dates after non-null dates', () {
      final episodes = [
        SimpleEpisodeData(
          id: 1,
          title: 'Ep1',
          publishedAt: DateTime(2024, 2, 1),
        ),
        SimpleEpisodeData(id: 2, title: 'Ep2'),
        SimpleEpisodeData(
          id: 3,
          title: 'Ep3',
          publishedAt: DateTime(2024, 1, 1),
        ),
      ];
      final map = _buildMap(episodes);

      final result = sortEpisodeIdsByPublishedAt([1, 2, 3], map);

      expect(result, [3, 1, 2]);
    });

    test('places unknown IDs after all known episodes', () {
      final episodes = [
        SimpleEpisodeData(
          id: 1,
          title: 'Ep1',
          publishedAt: DateTime(2024, 1, 1),
        ),
      ];
      final map = _buildMap(episodes);

      final result = sortEpisodeIdsByPublishedAt([99, 1, 50], map);

      expect(result, [1, 99, 50]);
    });

    test('handles all null dates preserving input order', () {
      final episodes = [
        SimpleEpisodeData(id: 1, title: 'Ep1'),
        SimpleEpisodeData(id: 2, title: 'Ep2'),
        SimpleEpisodeData(id: 3, title: 'Ep3'),
      ];
      final map = _buildMap(episodes);

      final result = sortEpisodeIdsByPublishedAt([3, 1, 2], map);

      expect(result, [3, 1, 2]);
    });

    test('returns copy of single-element list', () {
      final episodes = [
        SimpleEpisodeData(
          id: 1,
          title: 'Ep1',
          publishedAt: DateTime(2024, 1, 1),
        ),
      ];
      final map = _buildMap(episodes);

      final input = [1];
      final result = sortEpisodeIdsByPublishedAt(input, map);

      expect(result, [1]);
      expect(identical(result, input), isFalse);
    });

    test('returns empty list for empty input', () {
      final result = sortEpisodeIdsByPublishedAt([], {});

      expect(result, isEmpty);
    });

    test('preserves order for episodes with same publishedAt', () {
      final date = DateTime(2024, 1, 1);
      final episodes = [
        SimpleEpisodeData(id: 1, title: 'Ep1', publishedAt: date),
        SimpleEpisodeData(id: 2, title: 'Ep2', publishedAt: date),
        SimpleEpisodeData(id: 3, title: 'Ep3', publishedAt: date),
      ];
      final map = _buildMap(episodes);

      final result = sortEpisodeIdsByPublishedAt([3, 1, 2], map);

      expect(result, [3, 1, 2]);
    });

    test('handles mix of dated, null-dated, and unknown IDs', () {
      final episodes = [
        SimpleEpisodeData(
          id: 1,
          title: 'Ep1',
          publishedAt: DateTime(2024, 6, 1),
        ),
        SimpleEpisodeData(id: 2, title: 'Ep2'),
        SimpleEpisodeData(
          id: 3,
          title: 'Ep3',
          publishedAt: DateTime(2024, 1, 1),
        ),
      ];
      final map = _buildMap(episodes);

      final result = sortEpisodeIdsByPublishedAt([99, 2, 1, 3], map);

      // dated (3, 1), then null-dated (2), then unknown (99)
      expect(result, [3, 1, 2, 99]);
    });
  });
}
