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
    test('single-rule sort spec holds one rule', () {
      final spec = SmartPlaylistSortSpec([
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.playlistNumber,
          order: SortOrder.ascending,
        ),
      ]);

      expect(spec.rules, hasLength(1));
      expect(spec.rules[0].field, SmartPlaylistSortField.playlistNumber);
      expect(spec.rules[0].order, SortOrder.ascending);
    });

    test('multi-rule sort spec holds multiple rules', () {
      final spec = SmartPlaylistSortSpec([
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
  });
}
