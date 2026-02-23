import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

SimpleEpisodeData _makeEpisode({
  required int id,
  required String title,
  int? seasonNumber,
  int? episodeNumber,
  DateTime? publishedAt,
}) {
  return SimpleEpisodeData(
    id: id,
    title: title,
    seasonNumber: seasonNumber,
    episodeNumber: episodeNumber,
    publishedAt: publishedAt ?? DateTime(2024, 1, 1),
  );
}

void main() {
  group('RssMetadataResolver', () {
    late RssMetadataResolver resolver;

    setUp(() {
      resolver = RssMetadataResolver();
    });

    test('type is "rss"', () {
      expect(resolver.type, 'rss');
    });

    test('returns null when no episodes have season numbers', () {
      final episodes = [
        _makeEpisode(id: 1, title: 'Ep1'),
        _makeEpisode(id: 2, title: 'Ep2'),
        _makeEpisode(id: 3, title: 'Ep3'),
      ];

      final result = resolver.resolve(episodes, null);
      expect(result, isNull);
    });

    test('groups episodes by seasonNumber', () {
      final episodes = [
        _makeEpisode(id: 1, title: 'Ep1', seasonNumber: 1, episodeNumber: 1),
        _makeEpisode(id: 2, title: 'Ep2', seasonNumber: 1, episodeNumber: 2),
        _makeEpisode(id: 3, title: 'Ep3', seasonNumber: 2, episodeNumber: 1),
      ];

      final result = resolver.resolve(episodes, null);

      expect(result, isNotNull);
      expect(result!.playlists, hasLength(2));

      final playlist1 = result.playlists.firstWhere((s) => s.id == 'season_1');
      final playlist2 = result.playlists.firstWhere((s) => s.id == 'season_2');
      expect(playlist1.episodeIds, [1, 2]);
      expect(playlist2.episodeIds, [3]);
    });

    test('treats null seasonNumber as ungrouped by default', () {
      final episodes = [
        _makeEpisode(id: 1, title: 'Ep1', seasonNumber: 1, episodeNumber: 1),
        _makeEpisode(
          id: 2,
          title: 'Ep2',
          seasonNumber: null,
          episodeNumber: 100,
        ),
      ];

      final result = resolver.resolve(episodes, null);

      expect(result, isNotNull);
      expect(result!.playlists, hasLength(1));
      expect(result.ungroupedEpisodeIds, [2]);
    });

    test(
      'groups null/zero seasonNumber when nullSeasonGroupKey is configured',
      () {
        final definition = SmartPlaylistDefinition(
          id: 'test',
          displayName: 'Test',
          resolverType: 'rss',
          nullSeasonGroupKey: 0,
        );
        final episodes = [
          _makeEpisode(id: 1, title: 'Ep1', seasonNumber: 62, episodeNumber: 1),
          _makeEpisode(
            id: 2,
            title: 'Bangai1',
            seasonNumber: null,
            episodeNumber: 100,
          ),
          _makeEpisode(
            id: 3,
            title: 'Bangai2',
            seasonNumber: 0,
            episodeNumber: 101,
          ),
        ];

        final result = resolver.resolve(episodes, definition);

        expect(result, isNotNull);
        expect(result!.playlists, hasLength(2));
        expect(result.ungroupedEpisodeIds, isEmpty);

        final playlist0 = result.playlists.firstWhere(
          (s) => s.id == 'season_0',
        );
        expect(playlist0.episodeIds, containsAll([2, 3]));
      },
    );

    test('uses season number as sortKey', () {
      final episodes = [
        _makeEpisode(id: 1, title: 'Ep1', seasonNumber: 1, episodeNumber: 5),
        _makeEpisode(id: 2, title: 'Ep2', seasonNumber: 1, episodeNumber: 10),
        _makeEpisode(id: 3, title: 'Ep3', seasonNumber: 2, episodeNumber: 3),
      ];

      final result = resolver.resolve(episodes, null);

      expect(result, isNotNull);
      final playlist1 = result!.playlists.firstWhere((s) => s.id == 'season_1');
      final playlist2 = result.playlists.firstWhere((s) => s.id == 'season_2');

      expect(playlist1.sortKey, 1);
      expect(playlist2.sortKey, 2);
    });

    test('default sort is season number ascending', () {
      expect(resolver.defaultSort, isA<SmartPlaylistSortSpec>());
      final sort = resolver.defaultSort;
      expect(sort.rules, hasLength(1));
      expect(sort.rules[0].field, SmartPlaylistSortField.playlistNumber);
      expect(sort.rules[0].order, SortOrder.ascending);
    });

    test('sortKey is season number regardless of episodeNumber', () {
      final episodes = [
        _makeEpisode(id: 1, title: 'Ep1', seasonNumber: 1),
        _makeEpisode(id: 2, title: 'Ep2', seasonNumber: 1),
      ];

      final result = resolver.resolve(episodes, null);

      expect(result, isNotNull);
      expect(result!.playlists[0].sortKey, 1); // season number
    });

    test('sortKey is season number even with mixed episodeNumber values', () {
      final episodes = [
        _makeEpisode(id: 1, title: 'Ep1', seasonNumber: 1, episodeNumber: null),
        _makeEpisode(id: 2, title: 'Ep2', seasonNumber: 1, episodeNumber: 7),
        _makeEpisode(id: 3, title: 'Ep3', seasonNumber: 1, episodeNumber: 3),
      ];

      final result = resolver.resolve(episodes, null);

      expect(result, isNotNull);
      expect(result!.playlists[0].sortKey, 1); // season number
    });

    test('seasons are sorted by season number', () {
      final episodes = [
        _makeEpisode(id: 1, title: 'Ep1', seasonNumber: 3, episodeNumber: 1),
        _makeEpisode(id: 2, title: 'Ep2', seasonNumber: 1, episodeNumber: 1),
        _makeEpisode(id: 3, title: 'Ep3', seasonNumber: 2, episodeNumber: 1),
      ];

      final result = resolver.resolve(episodes, null);

      expect(result, isNotNull);
      expect(result!.playlists.length, 3);
      expect(result.playlists[0].sortKey, 1);
      expect(result.playlists[1].sortKey, 2);
      expect(result.playlists[2].sortKey, 3);
    });

    test('uses titleExtractor for display names', () {
      final definition = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'rss',
        titleExtractor: const SmartPlaylistTitleExtractor(
          source: 'title',
          pattern: r'(.+?) \d+$',
          group: 1,
        ),
      );
      final episodes = [
        _makeEpisode(id: 1, title: 'Topic A 1', seasonNumber: 1),
        _makeEpisode(id: 2, title: 'Topic A 2', seasonNumber: 1),
      ];

      final result = resolver.resolve(episodes, definition);

      expect(result, isNotNull);
      expect(result!.playlists.first.displayName, 'Topic A');
    });
  });
}
