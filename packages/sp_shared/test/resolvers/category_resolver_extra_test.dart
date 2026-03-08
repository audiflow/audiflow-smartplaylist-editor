import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('CategoryResolver', () {
    test('defaultSort returns ascending playlistNumber sort', () {
      final resolver = CategoryResolver();
      final sort = resolver.defaultSort;

      expect(sort.field, SmartPlaylistSortField.playlistNumber);
      expect(sort.order, SortOrder.ascending);
    });
  });

  group('CategoryResolver.parsePlaylistStructure', () {
    test('returns grouped for "grouped"', () {
      expect(
        CategoryResolver.parsePlaylistStructure('grouped'),
        PlaylistStructure.grouped,
      );
    });

    test('returns split for "split"', () {
      expect(
        CategoryResolver.parsePlaylistStructure('split'),
        PlaylistStructure.split,
      );
    });

    test('returns split for null', () {
      expect(
        CategoryResolver.parsePlaylistStructure(null),
        PlaylistStructure.split,
      );
    });

    test('returns split for unknown value', () {
      expect(
        CategoryResolver.parsePlaylistStructure('unknown'),
        PlaylistStructure.split,
      );
    });
  });

  group('CategoryResolver.parseYearBinding', () {
    test('returns pinToYear for "pinToYear"', () {
      expect(
        CategoryResolver.parseYearBinding('pinToYear'),
        YearBinding.pinToYear,
      );
    });

    test('returns splitByYear for "splitByYear"', () {
      expect(
        CategoryResolver.parseYearBinding('splitByYear'),
        YearBinding.splitByYear,
      );
    });

    test('returns none for "none"', () {
      expect(
        CategoryResolver.parseYearBinding('none'),
        YearBinding.none,
      );
    });

    test('returns none for null', () {
      expect(
        CategoryResolver.parseYearBinding(null),
        YearBinding.none,
      );
    });

    test('returns none for unknown value', () {
      expect(
        CategoryResolver.parseYearBinding('weekly'),
        YearBinding.none,
      );
    });
  });
}
