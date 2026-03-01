import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('RootMeta', () {
    test('deserializes from JSON', () {
      final json = {
        'version': 1,
        'patterns': [
          {
            'id': 'coten_radio',
            'version': 1,
            'displayName': 'Coten Radio',
            'feedUrlHint': 'anchor.fm/s/8c2088c',
            'playlistCount': 3,
          },
        ],
      };
      final meta = RootMeta.fromJson(json);
      expect(meta.version, 1);
      expect(meta.patterns, hasLength(1));
      expect(meta.patterns[0].id, 'coten_radio');
    });

    test('serializes to JSON', () {
      final meta = RootMeta(
        version: 1,
        patterns: [
          PatternSummary(
            id: 'test',
            version: 1,
            displayName: 'Test',
            feedUrlHint: 'test.com',
            playlistCount: 2,
          ),
        ],
      );
      final json = meta.toJson();
      expect(json['version'], 1);
      expect((json['patterns'] as List), hasLength(1));
    });

    test('parses from JSON string', () {
      final jsonString = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'p1',
            'version': 1,
            'displayName': 'P1',
            'feedUrlHint': 'example.com',
            'playlistCount': 1,
          },
        ],
      });
      final meta = RootMeta.parseJson(jsonString);
      expect(meta.patterns, hasLength(1));
    });

    test('parses any version number without rejection', () {
      final jsonString = jsonEncode({'version': 99, 'patterns': []});
      final meta = RootMeta.parseJson(jsonString);
      expect(meta.version, 99);
    });

    test('throws FormatException for missing version', () {
      final jsonString = jsonEncode({'patterns': []});
      expect(
        () => RootMeta.parseJson(jsonString),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
