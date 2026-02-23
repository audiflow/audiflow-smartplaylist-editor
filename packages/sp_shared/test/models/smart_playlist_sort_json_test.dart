import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistSortSpec JSON', () {
    test('round-trip with single rule', () {
      final sort = SmartPlaylistSortSpec([
        SmartPlaylistSortRule(
          field: SmartPlaylistSortField.playlistNumber,
          order: SortOrder.ascending,
        ),
      ]);
      final json = sort.toJson();

      expect(json.containsKey('type'), isFalse);
      expect(json['rules'], isList);

      final decoded = SmartPlaylistSortSpec.fromJson(json);
      expect(decoded.rules, hasLength(1));
      expect(decoded.rules[0].field, SmartPlaylistSortField.playlistNumber);
      expect(decoded.rules[0].order, SortOrder.ascending);
    });

    test('round-trip with multiple rules and conditions', () {
      final sort = SmartPlaylistSortSpec([
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

      expect(decoded.rules, hasLength(2));
      expect(decoded.rules[0].condition, isA<SortKeyGreaterThan>());
      expect((decoded.rules[0].condition! as SortKeyGreaterThan).value, 0);
      expect(decoded.rules[1].condition, isNull);
    });

    test('fromJson migrates legacy simple format', () {
      final json = {
        'type': 'simple',
        'field': 'playlistNumber',
        'order': 'ascending',
      };
      final decoded = SmartPlaylistSortSpec.fromJson(json);

      expect(decoded.rules, hasLength(1));
      expect(decoded.rules[0].field, SmartPlaylistSortField.playlistNumber);
      expect(decoded.rules[0].order, SortOrder.ascending);
      expect(decoded.rules[0].condition, isNull);
    });

    test('fromJson migrates legacy composite format', () {
      final json = {
        'type': 'composite',
        'rules': [
          {'field': 'playlistNumber', 'order': 'descending'},
        ],
      };
      final decoded = SmartPlaylistSortSpec.fromJson(json);

      expect(decoded.rules, hasLength(1));
      expect(decoded.rules[0].field, SmartPlaylistSortField.playlistNumber);
      expect(decoded.rules[0].order, SortOrder.descending);
    });

    test('SmartPlaylistSortCondition.fromJson throws on unknown type', () {
      expect(
        () => SmartPlaylistSortCondition.fromJson({'type': 'unknown'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
