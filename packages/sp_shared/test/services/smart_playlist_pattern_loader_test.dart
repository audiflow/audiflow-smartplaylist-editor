import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistPatternLoader', () {
    test('parses valid JSON with dataVersion 1', () {
      final json = jsonEncode({
        'dataVersion': 1,
        'patterns': [
          {
            'id': 'test',
            'feedUrls': ['https://example.com/feed'],
            'playlists': [
              {'id': 'main', 'displayName': 'Main', 'resolverType': 'rss'},
            ],
          },
        ],
      });
      final result = SmartPlaylistPatternLoader.parse(json);
      expect(result, hasLength(1));
      expect(result[0].id, 'test');
      expect(result[0].playlists, hasLength(1));
    });

    test('parses any dataVersion number without rejection', () {
      final json = jsonEncode({'dataVersion': 99, 'patterns': []});
      final result = SmartPlaylistPatternLoader.parse(json);
      expect(result, isEmpty);
    });

    test('throws FormatException on missing version', () {
      final json = jsonEncode({'patterns': []});
      expect(
        () => SmartPlaylistPatternLoader.parse(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('returns empty list for empty patterns', () {
      final json = jsonEncode({'dataVersion': 1, 'patterns': []});
      final result = SmartPlaylistPatternLoader.parse(json);
      expect(result, isEmpty);
    });
  });
}
