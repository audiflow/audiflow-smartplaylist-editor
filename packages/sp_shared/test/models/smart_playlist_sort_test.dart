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
          SmartPlaylistSortField.alphabetical,
        ]),
      );
    });
  });

  group('EpisodeSortField', () {
    test('all enum values exist', () {
      expect(
        EpisodeSortField.values,
        containsAll([
          EpisodeSortField.publishedAt,
          EpisodeSortField.episodeNumber,
          EpisodeSortField.title,
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

  group('SmartPlaylistSortRule', () {
    test('holds field and order', () {
      const rule = SmartPlaylistSortRule(
        field: SmartPlaylistSortField.playlistNumber,
        order: SortOrder.ascending,
      );

      expect(rule.field, SmartPlaylistSortField.playlistNumber);
      expect(rule.order, SortOrder.ascending);
    });
  });

  group('EpisodeSortRule', () {
    test('holds field and order', () {
      const rule = EpisodeSortRule(
        field: EpisodeSortField.publishedAt,
        order: SortOrder.descending,
      );

      expect(rule.field, EpisodeSortField.publishedAt);
      expect(rule.order, SortOrder.descending);
    });
  });
}
