import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('YearResolver with titleExtractor', () {
    final resolver = YearResolver();

    test(
      'uses titleExtractor result as displayName when extraction succeeds',
      () {
        const definition = SmartPlaylistDefinition(
          id: 'test',
          displayName: 'Test',
          resolverType: 'year',
          titleExtractor: SmartPlaylistTitleExtractor(
            source: 'title',
            pattern: r'Season (\d+)',
            group: 1,
          ),
        );

        final episodes = [
          SimpleEpisodeData(
            id: 1,
            title: 'Season 5 Episode 1',
            publishedAt: DateTime(2024, 3, 1),
          ),
          SimpleEpisodeData(
            id: 2,
            title: 'Season 5 Episode 2',
            publishedAt: DateTime(2024, 6, 1),
          ),
        ];

        final result = resolver.resolve(episodes, definition);

        expect(result, isNotNull);
        expect(result!.playlists, hasLength(1));
        // titleExtractor extracts "5" from "Season 5 Episode 1"
        expect(result.playlists.first.displayName, '5');
      },
    );

    test('falls back to year string when titleExtractor returns null', () {
      const definition = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'year',
        titleExtractor: SmartPlaylistTitleExtractor(
          source: 'title',
          pattern: r'NoMatch (\d+)',
          group: 1,
        ),
      );

      final episodes = [
        SimpleEpisodeData(
          id: 1,
          title: 'Regular Episode',
          publishedAt: DateTime(2023, 1, 15),
        ),
      ];

      final result = resolver.resolve(episodes, definition);

      expect(result, isNotNull);
      expect(result!.playlists, hasLength(1));
      expect(result.playlists.first.displayName, '2023');
    });

    test('uses year when titleExtractor is null', () {
      const definition = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'year',
      );

      final episodes = [
        SimpleEpisodeData(
          id: 1,
          title: 'Episode 1',
          publishedAt: DateTime(2022, 5, 10),
        ),
      ];

      final result = resolver.resolve(episodes, definition);

      expect(result, isNotNull);
      expect(result!.playlists.first.displayName, '2022');
    });

    test('uses year as displayName when definition is null', () {
      // When no definition is provided, titleExtractor is null
      final episodes = [
        SimpleEpisodeData(
          id: 1,
          title: 'Ep 1',
          publishedAt: DateTime(2021, 1, 1),
        ),
      ];

      final result = resolver.resolve(episodes, null);

      expect(result, isNotNull);
      expect(result!.playlists.first.displayName, '2021');
    });
  });
}
