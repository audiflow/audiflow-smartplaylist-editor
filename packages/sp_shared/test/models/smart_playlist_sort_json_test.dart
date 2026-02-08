import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistSortSpec JSON', () {
    test('SimpleSmartPlaylistSort round-trip', () {
      const sort = SimpleSmartPlaylistSort(
        SmartPlaylistSortField.playlistNumber,
        SortOrder.ascending,
      );
      final json = sort.toJson();
      final decoded = SmartPlaylistSortSpec.fromJson(json);

      expect(decoded, isA<SimpleSmartPlaylistSort>());
      final simple = decoded as SimpleSmartPlaylistSort;
      expect(simple.field, SmartPlaylistSortField.playlistNumber);
      expect(simple.order, SortOrder.ascending);
    });

    test('CompositeSmartPlaylistSort round-trip', () {
      const sort = CompositeSmartPlaylistSort([
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.playlistNumber,
          order: SortOrder.ascending,
          condition: SortKeyGreaterThan(0),
        ),
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.newestEpisodeDate,
          order: SortOrder.ascending,
        ),
      ]);
      final json = sort.toJson();
      final decoded = SmartPlaylistSortSpec.fromJson(json);

      expect(decoded, isA<CompositeSmartPlaylistSort>());
      final composite = decoded as CompositeSmartPlaylistSort;
      expect(composite.rules, hasLength(2));
      expect(composite.rules[0].condition, isA<SortKeyGreaterThan>());
      expect((composite.rules[0].condition! as SortKeyGreaterThan).value, 0);
      expect(composite.rules[1].condition, isNull);
    });

    test('fromJson throws on unknown type', () {
      expect(
        () => SmartPlaylistSortSpec.fromJson({'type': 'unknown'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('SmartPlaylistSortCondition.fromJson throws on unknown type', () {
      expect(
        () => SmartPlaylistSortCondition.fromJson({'type': 'unknown'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
