import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('CategoryResolver', () {
    test('defaultSort returns ascending playlistNumber sort', () {
      final resolver = CategoryResolver();
      final sort = resolver.defaultSort;

      expect(sort.rules, hasLength(1));
      expect(sort.rules.first.field, SmartPlaylistSortField.playlistNumber);
      expect(sort.rules.first.order, SortOrder.ascending);
      expect(sort.rules.first.condition, isNull);
    });
  });

  group('CategoryResolver.parseContentType', () {
    test('returns groups for "groups"', () {
      expect(
        CategoryResolver.parseContentType('groups'),
        SmartPlaylistContentType.groups,
      );
    });

    test('returns episodes for "episodes"', () {
      expect(
        CategoryResolver.parseContentType('episodes'),
        SmartPlaylistContentType.episodes,
      );
    });

    test('returns episodes for null', () {
      expect(
        CategoryResolver.parseContentType(null),
        SmartPlaylistContentType.episodes,
      );
    });

    test('returns episodes for unknown value', () {
      expect(
        CategoryResolver.parseContentType('unknown'),
        SmartPlaylistContentType.episodes,
      );
    });
  });

  group('CategoryResolver.parseYearHeaderMode', () {
    test('returns firstEpisode for "firstEpisode"', () {
      expect(
        CategoryResolver.parseYearHeaderMode('firstEpisode'),
        YearHeaderMode.firstEpisode,
      );
    });

    test('returns perEpisode for "perEpisode"', () {
      expect(
        CategoryResolver.parseYearHeaderMode('perEpisode'),
        YearHeaderMode.perEpisode,
      );
    });

    test('returns none for "none"', () {
      expect(
        CategoryResolver.parseYearHeaderMode('none'),
        YearHeaderMode.none,
      );
    });

    test('returns none for null', () {
      expect(
        CategoryResolver.parseYearHeaderMode(null),
        YearHeaderMode.none,
      );
    });

    test('returns none for unknown value', () {
      expect(
        CategoryResolver.parseYearHeaderMode('weekly'),
        YearHeaderMode.none,
      );
    });
  });
}
