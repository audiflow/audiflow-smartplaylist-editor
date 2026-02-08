import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistPatternLoader', () {
    test('parses valid JSON with version 1', () {
      final json = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'feedUrlPatterns': [r'https://example\.com/feed'],
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

    test('throws FormatException on unsupported version', () {
      final json = jsonEncode({'version': 99, 'patterns': []});
      expect(
        () => SmartPlaylistPatternLoader.parse(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on missing version', () {
      final json = jsonEncode({'patterns': []});
      expect(
        () => SmartPlaylistPatternLoader.parse(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('returns empty list for empty patterns', () {
      final json = jsonEncode({'version': 1, 'patterns': []});
      final result = SmartPlaylistPatternLoader.parse(json);
      expect(result, isEmpty);
    });
  });
}
