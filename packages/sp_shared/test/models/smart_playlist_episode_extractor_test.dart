import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistEpisodeResult', () {
    test('hasValues returns true when seasonNumber is set', () {
      const result = SmartPlaylistEpisodeResult(seasonNumber: 5);
      expect(result.hasValues, isTrue);
    });

    test('hasValues returns true when episodeNumber is set', () {
      const result = SmartPlaylistEpisodeResult(episodeNumber: 10);
      expect(result.hasValues, isTrue);
    });

    test('hasValues returns true when both are set', () {
      const result = SmartPlaylistEpisodeResult(
        seasonNumber: 5,
        episodeNumber: 10,
      );
      expect(result.hasValues, isTrue);
    });

    test('hasValues returns false when both are null', () {
      const result = SmartPlaylistEpisodeResult();
      expect(result.hasValues, isFalse);
    });
  });

  group('SmartPlaylistEpisodeExtractor', () {
    EpisodeData makeEpisode({
      String title = 'Test Episode',
      int? seasonNumber,
      int? episodeNumber,
      String? description,
    }) {
      return SimpleEpisodeData(
        id: 0,
        title: title,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        description: description,
      );
    }

    group('fromJson/toJson', () {
      test('creates from JSON config', () {
        final json = {
          'source': 'title',
          'pattern': r'【(\d+)-(\d+)】',
          'seasonGroup': 1,
          'episodeGroup': 2,
          'fallbackSeasonNumber': 0,
          'fallbackEpisodePattern': r'【番外編[＃#](\d+)】',
          'fallbackEpisodeCaptureGroup': 1,
        };

        final extractor = SmartPlaylistEpisodeExtractor.fromJson(json);

        expect(extractor.source, 'title');
        expect(extractor.pattern, r'【(\d+)-(\d+)】');
        expect(extractor.seasonGroup, 1);
        expect(extractor.episodeGroup, 2);
        expect(extractor.fallbackSeasonNumber, 0);
        expect(extractor.fallbackEpisodePattern, r'【番外編[＃#](\d+)】');
        expect(extractor.fallbackEpisodeCaptureGroup, 1);
      });

      test('uses default values when not specified', () {
        final json = {'source': 'title', 'pattern': r'S(\d+)E(\d+)'};

        final extractor = SmartPlaylistEpisodeExtractor.fromJson(json);

        expect(extractor.seasonGroup, 1);
        expect(extractor.episodeGroup, 2);
        expect(extractor.fallbackEpisodeCaptureGroup, 1);
        expect(extractor.fallbackSeasonNumber, isNull);
        expect(extractor.fallbackEpisodePattern, isNull);
      });

      test('converts to JSON', () {
        const extractor = SmartPlaylistEpisodeExtractor(
          source: 'title',
          pattern: r'【(\d+)-(\d+)】',
          seasonGroup: 1,
          episodeGroup: 2,
          fallbackSeasonNumber: 0,
          fallbackEpisodePattern: r'【番外編[＃#](\d+)】',
        );

        final json = extractor.toJson();

        expect(json['source'], 'title');
        expect(json['pattern'], r'【(\d+)-(\d+)】');
        expect(json['seasonGroup'], 1);
        expect(json['episodeGroup'], 2);
        expect(json['fallbackSeasonNumber'], 0);
        expect(json['fallbackEpisodePattern'], r'【番外編[＃#](\d+)】');
      });

      test('omits default values in JSON', () {
        const extractor = SmartPlaylistEpisodeExtractor(
          source: 'title',
          pattern: r'【(\d+)-(\d+)】',
        );

        final json = extractor.toJson();

        expect(json.containsKey('fallbackSeasonNumber'), isFalse);
        expect(json.containsKey('fallbackEpisodePattern'), isFalse);
      });
    });

    group('extract', () {
      test('extracts season and episode from primary pattern', () {
        const extractor = SmartPlaylistEpisodeExtractor(
          source: 'title',
          pattern: r'【(\d+)-(\d+)】',
        );

        final episode = makeEpisode(
          title:
              '【62-15】何が変わった？'
              '【COTEN RADIO リンカン編15】',
        );
        final result = extractor.extract(episode);

        expect(result.seasonNumber, 62);
        expect(result.episodeNumber, 15);
        expect(result.hasValues, isTrue);
      });

      test('uses fallback pattern when primary does not match', () {
        const extractor = SmartPlaylistEpisodeExtractor(
          source: 'title',
          pattern: r'【(\d+)-(\d+)】',
          fallbackSeasonNumber: 0,
          fallbackEpisodePattern: r'【番外編[＃#](\d+)】',
        );

        final episode = makeEpisode(title: '【番外編＃135】仏教のこと');
        final result = extractor.extract(episode);

        expect(result.seasonNumber, 0);
        expect(result.episodeNumber, 135);
        expect(result.hasValues, isTrue);
      });

      test('handles half-width hash in fallback pattern', () {
        const extractor = SmartPlaylistEpisodeExtractor(
          source: 'title',
          pattern: r'【(\d+)-(\d+)】',
          fallbackSeasonNumber: 0,
          fallbackEpisodePattern: r'【番外編[＃#](\d+)】',
        );

        final episode = makeEpisode(title: '【番外編#100】Something');
        final result = extractor.extract(episode);

        expect(result.seasonNumber, 0);
        expect(result.episodeNumber, 100);
      });

      test('returns empty result when no pattern matches', () {
        const extractor = SmartPlaylistEpisodeExtractor(
          source: 'title',
          pattern: r'【(\d+)-(\d+)】',
        );

        final episode = makeEpisode(title: 'Random title without pattern');
        final result = extractor.extract(episode);

        expect(result.seasonNumber, isNull);
        expect(result.episodeNumber, isNull);
        expect(result.hasValues, isFalse);
      });

      test('returns empty result when source field is null', () {
        const extractor = SmartPlaylistEpisodeExtractor(
          source: 'description',
          pattern: r'S(\d+)E(\d+)',
        );

        final episode = makeEpisode(title: 'Title here', description: null);
        final result = extractor.extract(episode);

        expect(result.hasValues, isFalse);
      });

      test('extracts from description when source is '
          'description', () {
        const extractor = SmartPlaylistEpisodeExtractor(
          source: 'description',
          pattern: r'Season (\d+), Episode (\d+)',
        );

        final episode = makeEpisode(
          title: 'My Episode',
          description: 'Season 5, Episode 10 of the show',
        );
        final result = extractor.extract(episode);

        expect(result.seasonNumber, 5);
        expect(result.episodeNumber, 10);
      });

      test('handles custom capture groups', () {
        const extractor = SmartPlaylistEpisodeExtractor(
          source: 'title',
          // Episode first, then season
          pattern: r'E(\d+)S(\d+)',
          seasonGroup: 2,
          episodeGroup: 1,
        );

        final episode = makeEpisode(title: 'E15S62 - Title');
        final result = extractor.extract(episode);

        expect(result.seasonNumber, 62);
        expect(result.episodeNumber, 15);
      });
    });

    group('COTEN RADIO specific tests', () {
      const cotenExtractor = SmartPlaylistEpisodeExtractor(
        source: 'title',
        pattern: r'【(\d+)-(\d+)】',
        seasonGroup: 1,
        episodeGroup: 2,
        fallbackSeasonNumber: 0,
        fallbackEpisodePattern: r'【番外編[＃#](\d+)】',
        fallbackEpisodeCaptureGroup: 1,
      );

      test('extracts from regular COTEN RADIO episode', () {
        final episode = makeEpisode(
          title:
              '【62-15】何が変わった？'
              '【COTEN RADIO リンカン編15】',
          seasonNumber: 62,
          episodeNumber: 999,
        );
        final result = cotenExtractor.extract(episode);

        expect(result.seasonNumber, 62);
        expect(result.episodeNumber, 15);
      });

      test('extracts from COTEN RADIO short episode', () {
        final episode = makeEpisode(
          title:
              '【1-8】ニコラ・テスラと直流/交流対決の謎'
              '【COTEN RADIOショート ニコラ・テスラ編8】',
          seasonNumber: 1,
        );
        final result = cotenExtractor.extract(episode);

        expect(result.seasonNumber, 1);
        expect(result.episodeNumber, 8);
      });

      test('extracts from bangai-hen with full-width hash', () {
        final episode = makeEpisode(
          title: '【番外編＃135】仏教のこと、ちょっとだけ',
          seasonNumber: null,
          episodeNumber: 135,
        );
        final result = cotenExtractor.extract(episode);

        expect(result.seasonNumber, 0);
        expect(result.episodeNumber, 135);
      });

      test('extracts from bangai-hen with half-width hash', () {
        final episode = makeEpisode(
          title: '【番外編#100】歴史の話',
          seasonNumber: 0,
          episodeNumber: 100,
        );
        final result = cotenExtractor.extract(episode);

        expect(result.seasonNumber, 0);
        expect(result.episodeNumber, 100);
      });
    });
  });
}
