import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistTitleExtractor unknown source', () {
    test('returns null when source is unrecognized and no fallback', () {
      const extractor = SmartPlaylistTitleExtractor(source: 'unknown_source');

      const episode = SimpleEpisodeData(
        id: 1,
        title: 'Test Episode',
        seasonNumber: 3,
        episodeNumber: 5,
      );

      final result = extractor.extract(episode);
      expect(result, isNull);
    });

    test('tries fallback when source is unrecognized', () {
      const extractor = SmartPlaylistTitleExtractor(
        source: 'unknown_source',
        fallback: SmartPlaylistTitleExtractor(
          source: 'seasonNumber',
          template: 'Season {value}',
        ),
      );

      const episode = SimpleEpisodeData(
        id: 1,
        title: 'Test Episode',
        seasonNumber: 7,
      );

      final result = extractor.extract(episode);
      expect(result, 'Season 7');
    });

    test(
      'returns null when source is unrecognized and fallback also fails',
      () {
        const extractor = SmartPlaylistTitleExtractor(
          source: 'invalid',
          fallback: SmartPlaylistTitleExtractor(source: 'also_invalid'),
        );

        const episode = SimpleEpisodeData(id: 1, title: 'Test');

        final result = extractor.extract(episode);
        expect(result, isNull);
      },
    );
  });
}
