import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistEpisodeResult.toString', () {
    test('formats with both values', () {
      const result = SmartPlaylistEpisodeResult(
        seasonNumber: 3,
        episodeNumber: 12,
      );

      expect(
        result.toString(),
        'SmartPlaylistEpisodeResult(season: 3, episode: 12)',
      );
    });

    test('formats with null values', () {
      const result = SmartPlaylistEpisodeResult();

      expect(
        result.toString(),
        'SmartPlaylistEpisodeResult(season: null, episode: null)',
      );
    });

    test('formats with only seasonNumber', () {
      const result = SmartPlaylistEpisodeResult(seasonNumber: 5);

      expect(
        result.toString(),
        'SmartPlaylistEpisodeResult(season: 5, episode: null)',
      );
    });

    test('formats with only episodeNumber', () {
      const result = SmartPlaylistEpisodeResult(episodeNumber: 42);

      expect(
        result.toString(),
        'SmartPlaylistEpisodeResult(season: null, episode: 42)',
      );
    });
  });

  group('SmartPlaylistEpisodeExtractor.toJson with fallbackEpisodeCaptureGroup',
      () {
    test('omits fallbackEpisodeCaptureGroup when it equals 1 (default)', () {
      const extractor = SmartPlaylistEpisodeExtractor(
        source: 'title',
        pattern: r'\[(\d+)-(\d+)\]',
        fallbackEpisodePattern: r'#(\d+)',
        fallbackEpisodeCaptureGroup: 1,
      );

      final json = extractor.toJson();
      expect(json.containsKey('fallbackEpisodeCaptureGroup'), false);
    });

    test('includes fallbackEpisodeCaptureGroup when it differs from 1', () {
      const extractor = SmartPlaylistEpisodeExtractor(
        source: 'title',
        pattern: r'\[(\d+)-(\d+)\]',
        fallbackEpisodePattern: r'special-(\w+)-(\d+)',
        fallbackEpisodeCaptureGroup: 2,
      );

      final json = extractor.toJson();
      expect(json.containsKey('fallbackEpisodeCaptureGroup'), true);
      expect(json['fallbackEpisodeCaptureGroup'], 2);
    });

    test('includes fallbackEpisodeCaptureGroup when it is 0', () {
      const extractor = SmartPlaylistEpisodeExtractor(
        source: 'title',
        pattern: r'\[(\d+)-(\d+)\]',
        fallbackEpisodePattern: r'ep(\d+)',
        fallbackEpisodeCaptureGroup: 0,
      );

      final json = extractor.toJson();
      expect(json.containsKey('fallbackEpisodeCaptureGroup'), true);
      expect(json['fallbackEpisodeCaptureGroup'], 0);
    });
  });
}
