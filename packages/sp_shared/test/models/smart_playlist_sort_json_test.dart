import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistSortRule JSON', () {
    test('round-trip', () {
      const rule = SmartPlaylistSortRule(
        field: SmartPlaylistSortField.playlistNumber,
        order: SortOrder.ascending,
      );
      final json = rule.toJson();

      expect(json['field'], 'playlistNumber');
      expect(json['order'], 'ascending');

      final decoded = SmartPlaylistSortRule.fromJson(json);
      expect(decoded.field, SmartPlaylistSortField.playlistNumber);
      expect(decoded.order, SortOrder.ascending);
    });

    test('round-trip with newestEpisodeDate descending', () {
      const rule = SmartPlaylistSortRule(
        field: SmartPlaylistSortField.newestEpisodeDate,
        order: SortOrder.descending,
      );
      final json = rule.toJson();
      final decoded = SmartPlaylistSortRule.fromJson(json);

      expect(decoded.field, SmartPlaylistSortField.newestEpisodeDate);
      expect(decoded.order, SortOrder.descending);
    });
  });

  group('EpisodeSortRule JSON', () {
    test('round-trip', () {
      const rule = EpisodeSortRule(
        field: EpisodeSortField.publishedAt,
        order: SortOrder.ascending,
      );
      final json = rule.toJson();

      expect(json['field'], 'publishedAt');
      expect(json['order'], 'ascending');

      final decoded = EpisodeSortRule.fromJson(json);
      expect(decoded.field, EpisodeSortField.publishedAt);
      expect(decoded.order, SortOrder.ascending);
    });

    test('round-trip with episodeNumber descending', () {
      const rule = EpisodeSortRule(
        field: EpisodeSortField.episodeNumber,
        order: SortOrder.descending,
      );
      final json = rule.toJson();
      final decoded = EpisodeSortRule.fromJson(json);

      expect(decoded.field, EpisodeSortField.episodeNumber);
      expect(decoded.order, SortOrder.descending);
    });
  });
}
