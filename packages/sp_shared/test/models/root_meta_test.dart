import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('RootMeta', () {
    test('deserializes from JSON', () {
      final json = {
        'dataVersion': 1,
        'schemaVersion': 1,
        'patterns': [
          {
            'id': 'coten_radio',
            'dataVersion': 1,
            'displayName': 'Coten Radio',
            'feedUrlHint': 'anchor.fm/s/8c2088c',
            'playlistCount': 3,
          },
        ],
      };
      final meta = RootMeta.fromJson(json);
      expect(meta.dataVersion, 1);
      expect(meta.patterns, hasLength(1));
      expect(meta.patterns[0].id, 'coten_radio');
    });

    test('serializes to JSON', () {
      final meta = RootMeta(
        dataVersion: 1,
        schemaVersion: 1,
        patterns: [
          PatternSummary(
            id: 'test',
            dataVersion: 1,
            displayName: 'Test',
            feedUrlHint: 'test.com',
            playlistCount: 2,
          ),
        ],
      );
      final json = meta.toJson();
      expect(json['dataVersion'], 1);
      expect((json['patterns'] as List), hasLength(1));
    });

    test('parses from JSON string', () {
      final jsonString = jsonEncode({
        'dataVersion': 1,
        'schemaVersion': 1,
        'patterns': [
          {
            'id': 'p1',
            'dataVersion': 1,
            'displayName': 'P1',
            'feedUrlHint': 'example.com',
            'playlistCount': 1,
          },
        ],
      });
      final meta = RootMeta.parseJson(jsonString);
      expect(meta.patterns, hasLength(1));
    });

    test('parses any dataVersion number without rejection', () {
      final jsonString = jsonEncode({
        'dataVersion': 99,
        'schemaVersion': 1,
        'patterns': [],
      });
      final meta = RootMeta.parseJson(jsonString);
      expect(meta.dataVersion, 99);
    });

    test('throws FormatException for missing dataVersion', () {
      final jsonString = jsonEncode({'schemaVersion': 1, 'patterns': []});
      expect(
        () => RootMeta.parseJson(jsonString),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for missing schemaVersion', () {
      final jsonString = jsonEncode({'dataVersion': 1, 'patterns': []});
      expect(
        () => RootMeta.parseJson(jsonString),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
