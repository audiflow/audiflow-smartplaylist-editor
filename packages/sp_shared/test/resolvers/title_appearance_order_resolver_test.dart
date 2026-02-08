import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

SimpleEpisodeData _makeEpisode(int id, String title, DateTime publishedAt) {
  return SimpleEpisodeData(id: id, title: title, publishedAt: publishedAt);
}

void main() {
  group('TitleAppearanceOrderResolver', () {
    late TitleAppearanceOrderResolver resolver;

    setUp(() {
      resolver = TitleAppearanceOrderResolver();
    });

    test('type is "title_appearance"', () {
      expect(resolver.type, 'title_appearance');
    });

    test('returns null when no definition provided', () {
      final episodes = [
        _makeEpisode(1, '[Rome 1] First', DateTime(2024, 1, 1)),
      ];

      final result = resolver.resolve(episodes, null);
      expect(result, isNull);
    });

    test('groups by first appearance order using group pattern', () {
      const definition = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'title_appearance',
        groups: [
          SmartPlaylistGroupDef(
            id: 'extract',
            displayName: 'Extract',
            pattern: r'\[(\w+)\s+\d+\]',
          ),
        ],
      );

      // Episodes in feed order (newest first typically)
      final episodes = [
        _makeEpisode(6, '[Firenze 1] Renaissance', DateTime(2024, 3, 1)),
        _makeEpisode(5, '[Venezia 2] Canals', DateTime(2024, 2, 15)),
        _makeEpisode(4, '[Venezia 1] Arrival', DateTime(2024, 2, 1)),
        _makeEpisode(3, '[Rome 3] Colosseum', DateTime(2024, 1, 20)),
        _makeEpisode(2, '[Rome 2] Vatican', DateTime(2024, 1, 10)),
        _makeEpisode(1, '[Rome 1] First Steps', DateTime(2024, 1, 1)),
      ];

      final result = resolver.resolve(episodes, definition);

      expect(result, isNotNull);
      expect(result!.playlists.length, 3);

      // Rome appeared first chronologically, so it's season 1
      expect(result.playlists[0].displayName, 'Rome');
      expect(result.playlists[0].sortKey, 1);
      expect(result.playlists[0].episodeIds, containsAll([1, 2, 3]));

      // Venezia appeared second
      expect(result.playlists[1].displayName, 'Venezia');
      expect(result.playlists[1].sortKey, 2);

      // Firenze appeared third
      expect(result.playlists[2].displayName, 'Firenze');
      expect(result.playlists[2].sortKey, 3);
    });

    test('non-matching episodes go to ungrouped', () {
      const definition = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'title_appearance',
        groups: [
          SmartPlaylistGroupDef(
            id: 'extract',
            displayName: 'Extract',
            pattern: r'\[(\w+)\s+\d+\]',
          ),
        ],
      );

      final episodes = [
        _makeEpisode(1, '[Rome 1] First', DateTime(2024, 1, 1)),
        _makeEpisode(2, 'Bonus Episode', DateTime(2024, 1, 5)),
      ];

      final result = resolver.resolve(episodes, definition);

      expect(result, isNotNull);
      expect(result!.ungroupedEpisodeIds, [2]);
    });

    test('returns null when no matches found', () {
      const definition = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'title_appearance',
        groups: [
          SmartPlaylistGroupDef(
            id: 'extract',
            displayName: 'Extract',
            pattern: r'\[(\w+)\s+\d+\]',
          ),
        ],
      );

      final episodes = [
        _makeEpisode(1, 'No Pattern Here', DateTime(2024, 1, 1)),
        _makeEpisode(2, 'Another One', DateTime(2024, 1, 2)),
      ];

      final result = resolver.resolve(episodes, definition);
      expect(result, isNull);
    });
  });
}
