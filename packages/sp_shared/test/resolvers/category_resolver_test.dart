import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

SimpleEpisodeData _makeEpisode(int id, String title) {
  return SimpleEpisodeData(id: id, title: title);
}

void main() {
  group('CategoryResolver', () {
    late CategoryResolver resolver;

    setUp(() {
      resolver = CategoryResolver();
    });

    test('type is "category"', () {
      expect(resolver.type, 'category');
    });

    test('returns null without definition', () {
      final episodes = [_makeEpisode(1, 'Episode 1')];
      final result = resolver.resolve(episodes, null);
      expect(result, isNull);
    });

    test('returns null without groups', () {
      const definition = SmartPlaylistDefinition(
        id: 'empty',
        displayName: 'Empty',
        resolverType: 'category',
      );
      final episodes = [_makeEpisode(1, 'Episode 1')];
      final result = resolver.resolve(episodes, definition);
      expect(result, isNull);
    });

    test('groups episodes by pattern', () {
      const definition = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'category',
        groups: [
          SmartPlaylistGroupDef(
            id: 'saturday',
            displayName: 'Saturday',
            pattern: r'【土曜版',
          ),
          SmartPlaylistGroupDef(
            id: 'news_talk',
            displayName: 'News Talk',
            pattern: r'【ニュース小話',
          ),
          SmartPlaylistGroupDef(id: 'other', displayName: 'Other'),
        ],
      );

      final episodes = [
        _makeEpisode(1, '【土曜版 #62】topic'),
        _makeEpisode(2, '【ニュース小話 #200】bonds'),
        _makeEpisode(3, '【1月29日】EU news'),
      ];

      final result = resolver.resolve(episodes, definition);

      expect(result, isNotNull);
      // Each category becomes a separate playlist
      expect(result!.playlists, hasLength(3));
      expect(result.playlists[0].id, 'saturday');
      expect(result.playlists[0].episodeIds, [1]);
      expect(result.playlists[1].id, 'news_talk');
      expect(result.playlists[1].episodeIds, [2]);
      expect(result.playlists[2].id, 'other');
      expect(result.playlists[2].episodeIds, [3]);
    });

    test('ungrouped when no fallback group', () {
      const definition = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'category',
        groups: [
          SmartPlaylistGroupDef(
            id: 'saturday',
            displayName: 'Saturday',
            pattern: r'【土曜版',
          ),
        ],
      );

      final episodes = [
        _makeEpisode(1, '【土曜版 #62】topic'),
        _makeEpisode(2, 'No match'),
      ];

      final result = resolver.resolve(episodes, definition);

      expect(result, isNotNull);
      expect(result!.ungroupedEpisodeIds, [2]);
    });

    test('first match wins when multiple patterns could match', () {
      const definition = SmartPlaylistDefinition(
        id: 'overlap',
        displayName: 'Overlap',
        resolverType: 'category',
        groups: [
          SmartPlaylistGroupDef(
            id: 'first',
            displayName: 'First',
            pattern: r'Hello',
          ),
          SmartPlaylistGroupDef(
            id: 'second',
            displayName: 'Second',
            pattern: r'Hello World',
          ),
        ],
      );
      final episodes = [_makeEpisode(1, 'Hello World')];

      final result = resolver.resolve(episodes, definition);

      expect(result, isNotNull);
      expect(result!.playlists, hasLength(1));
      expect(result.playlists.first.id, 'first');
    });

    test('returns null when groups list is empty', () {
      const definition = SmartPlaylistDefinition(
        id: 'empty',
        displayName: 'Empty',
        resolverType: 'category',
        groups: [],
      );

      final episodes = [_makeEpisode(1, 'Episode 1')];

      final result = resolver.resolve(episodes, definition);
      expect(result, isNull);
    });

    test('assigns incrementing sortKeys to groups', () {
      const definition = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'category',
        groups: [
          SmartPlaylistGroupDef(
            id: 'alpha',
            displayName: 'Alpha',
            pattern: r'AAA',
          ),
          SmartPlaylistGroupDef(
            id: 'beta',
            displayName: 'Beta',
            pattern: r'BBB',
          ),
          SmartPlaylistGroupDef(id: 'other', displayName: 'Other'),
        ],
      );

      final episodes = [
        _makeEpisode(1, 'AAA episode'),
        _makeEpisode(2, 'BBB episode'),
        _makeEpisode(3, 'CCC episode'),
      ];

      final result = resolver.resolve(episodes, definition);

      expect(result, isNotNull);
      expect(result!.playlists, hasLength(3));
      expect(result.playlists[0].sortKey, 1);
      expect(result.playlists[1].sortKey, 2);
      expect(result.playlists[2].sortKey, 3);
    });

    test('fallback group collects unmatched episodes', () {
      const definition = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'category',
        groups: [
          SmartPlaylistGroupDef(
            id: 'matched',
            displayName: 'Matched',
            pattern: r'AAA',
          ),
          SmartPlaylistGroupDef(id: 'fallback', displayName: 'Fallback'),
        ],
      );

      final episodes = [
        _makeEpisode(1, 'AAA episode'),
        _makeEpisode(2, 'BBB episode'),
      ];

      final result = resolver.resolve(episodes, definition);

      expect(result, isNotNull);
      expect(result!.playlists, hasLength(2));
      expect(result.playlists[0].id, 'matched');
      expect(result.playlists[0].episodeIds, [1]);
      expect(result.playlists[1].id, 'fallback');
      expect(result.playlists[1].episodeIds, [2]);
    });
  });
}
