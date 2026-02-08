import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistSortField', () {
    test('all enum values exist', () {
      expect(
        SmartPlaylistSortField.values,
        containsAll([
          SmartPlaylistSortField.playlistNumber,
          SmartPlaylistSortField.newestEpisodeDate,
          SmartPlaylistSortField.progress,
          SmartPlaylistSortField.alphabetical,
        ]),
      );
    });
  });

  group('SortOrder', () {
    test('ascending and descending exist', () {
      expect(
        SortOrder.values,
        containsAll([SortOrder.ascending, SortOrder.descending]),
      );
    });
  });

  group('SmartPlaylistSortSpec', () {
    test('simple sort spec holds field and order', () {
      const spec = SimpleSmartPlaylistSort(
        SmartPlaylistSortField.playlistNumber,
        SortOrder.ascending,
      );

      expect(spec.field, SmartPlaylistSortField.playlistNumber);
      expect(spec.order, SortOrder.ascending);
    });

    test('composite sort spec holds multiple rules', () {
      final spec = CompositeSmartPlaylistSort([
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.playlistNumber,
          order: SortOrder.ascending,
        ),
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.newestEpisodeDate,
          order: SortOrder.descending,
        ),
      ]);

      expect(spec.rules.length, 2);
    });

    test('exhaustive switch works on SmartPlaylistSortSpec', () {
      const SmartPlaylistSortSpec spec = SimpleSmartPlaylistSort(
        SmartPlaylistSortField.alphabetical,
        SortOrder.ascending,
      );

      final result = switch (spec) {
        SimpleSmartPlaylistSort() => 'simple',
        CompositeSmartPlaylistSort() => 'composite',
      };

      expect(result, 'simple');
    });
  });
}
