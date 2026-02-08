import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistPatternConfig', () {
    test('round-trip with feedUrlPatterns and playlists', () {
      final config = SmartPlaylistPatternConfig(
        id: 'test-podcast',
        feedUrlPatterns: [r'https://example\.com/feed.*'],
        playlists: const [
          SmartPlaylistDefinition(
            id: 'main',
            displayName: 'Main',
            resolverType: 'rssSeason',
          ),
        ],
      );

      final jsonString = jsonEncode(config.toJson());
      final decoded = SmartPlaylistPatternConfig.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(decoded.id, 'test-podcast');
      expect(decoded.feedUrlPatterns, hasLength(1));
      expect(decoded.playlists, hasLength(1));
      expect(decoded.playlists.first.id, 'main');
      expect(decoded.yearGroupedEpisodes, isFalse);
    });

    test('matchesPodcast by feed URL - match', () {
      final config = SmartPlaylistPatternConfig(
        id: 'test',
        feedUrlPatterns: [r'https://example\.com/feed.*'],
        playlists: const [
          SmartPlaylistDefinition(
            id: 'p1',
            displayName: 'P1',
            resolverType: 'flat',
          ),
        ],
      );

      expect(
        config.matchesPodcast(null, 'https://example.com/feed/rss'),
        isTrue,
      );
    });

    test('matchesPodcast by feed URL - no match', () {
      final config = SmartPlaylistPatternConfig(
        id: 'test',
        feedUrlPatterns: [r'https://example\.com/feed.*'],
        playlists: const [
          SmartPlaylistDefinition(
            id: 'p1',
            displayName: 'P1',
            resolverType: 'flat',
          ),
        ],
      );

      expect(config.matchesPodcast(null, 'https://other.com/feed'), isFalse);
    });

    test('matchesPodcast by GUID - match', () {
      final config = SmartPlaylistPatternConfig(
        id: 'test',
        podcastGuid: 'abc-123',
        playlists: const [
          SmartPlaylistDefinition(
            id: 'p1',
            displayName: 'P1',
            resolverType: 'flat',
          ),
        ],
      );

      expect(config.matchesPodcast('abc-123', 'https://any.com/feed'), isTrue);
    });

    test('matchesPodcast by GUID - no match', () {
      final config = SmartPlaylistPatternConfig(
        id: 'test',
        podcastGuid: 'abc-123',
        playlists: const [
          SmartPlaylistDefinition(
            id: 'p1',
            displayName: 'P1',
            resolverType: 'flat',
          ),
        ],
      );

      expect(config.matchesPodcast('xyz-999', 'https://any.com/feed'), isFalse);
    });
  });
}
