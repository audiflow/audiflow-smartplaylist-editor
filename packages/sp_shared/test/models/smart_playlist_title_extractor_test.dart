import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistTitleExtractor', () {
    test('creates from JSON config with regex pattern', () {
      final json = {
        'source': 'title',
        'pattern': r'\[(.+?)\s+\d+\]',
        'group': 1,
      };

      final extractor = SmartPlaylistTitleExtractor.fromJson(json);

      expect(extractor.source, 'title');
      expect(extractor.pattern, r'\[(.+?)\s+\d+\]');
      expect(extractor.group, 1);
    });

    test('creates from JSON config with template', () {
      final json = {'source': 'seasonNumber', 'template': 'Season {value}'};

      final extractor = SmartPlaylistTitleExtractor.fromJson(json);

      expect(extractor.source, 'seasonNumber');
      expect(extractor.template, 'Season {value}');
    });

    test('creates from JSON config with fallback', () {
      final json = {
        'source': 'title',
        'pattern': r'\[(.+?)\]',
        'group': 1,
        'fallback': {'source': 'seasonNumber', 'template': 'Season {value}'},
      };

      final extractor = SmartPlaylistTitleExtractor.fromJson(json);

      expect(extractor.fallback, isNotNull);
      expect(extractor.fallback!.source, 'seasonNumber');
      expect(extractor.fallback!.template, 'Season {value}');
    });

    test('converts to JSON', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'title',
        pattern: r'\[(.+?)\]',
        group: 1,
        fallback: SmartPlaylistTitleExtractor(
          source: 'seasonNumber',
          template: 'Season {value}',
        ),
      );

      final json = extractor.toJson();

      expect(json['source'], 'title');
      expect(json['pattern'], r'\[(.+?)\]');
      expect(json['group'], 1);
      expect(json['fallback'], isA<Map<String, dynamic>>());
    });

    test('group defaults to 0 when not specified', () {
      final json = {'source': 'title', 'pattern': r'Season (\d+)'};

      final extractor = SmartPlaylistTitleExtractor.fromJson(json);

      expect(extractor.group, 0);
    });

    test('creates from JSON config with fallbackValue', () {
      final json = {
        'source': 'title',
        'pattern': r'【COTEN RADIO (ショート)?\s*(.+?)\s+\d+】',
        'group': 2,
        'fallbackValue': '番外編',
      };

      final extractor = SmartPlaylistTitleExtractor.fromJson(json);

      expect(extractor.fallbackValue, '番外編');
    });

    test('converts to JSON with fallbackValue', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'title',
        pattern: r'【COTEN RADIO】',
        fallbackValue: '番外編',
      );

      final json = extractor.toJson();

      expect(json['fallbackValue'], '番外編');
    });
  });

  group('SmartPlaylistTitleExtractor.extract', () {
    EpisodeData makeEpisode({
      String title = 'Test Episode',
      int? seasonNumber,
      String? description,
    }) {
      return SimpleEpisodeData(
        id: 0,
        title: title,
        seasonNumber: seasonNumber,
        description: description,
      );
    }

    test('extracts from title using regex', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'title',
        pattern: r'\[(.+?)\s+\d+\]',
        group: 1,
      );

      final episode = makeEpisode(title: '[Rome 1] First Steps');
      final result = extractor.extract(episode);

      expect(result, 'Rome');
    });

    test('extracts full match when group is 0', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'title',
        pattern: r'\[.+?\s+\d+\]',
        group: 0,
      );

      final episode = makeEpisode(title: '[Rome 1] First Steps');
      final result = extractor.extract(episode);

      expect(result, '[Rome 1]');
    });

    test('uses template with seasonNumber', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'seasonNumber',
        template: 'Season {value}',
      );

      final episode = makeEpisode(seasonNumber: 3);
      final result = extractor.extract(episode);

      expect(result, 'Season 3');
    });

    test('uses fallback when pattern does not match', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'title',
        pattern: r'\[(.+?)\]',
        group: 1,
        fallback: SmartPlaylistTitleExtractor(
          source: 'seasonNumber',
          template: 'Season {value}',
        ),
      );

      final episode = makeEpisode(title: 'No brackets here', seasonNumber: 2);
      final result = extractor.extract(episode);

      expect(result, 'Season 2');
    });

    test('returns null when no match and no fallback', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'title',
        pattern: r'\[(.+?)\]',
        group: 1,
      );

      final episode = makeEpisode(title: 'No brackets here');
      final result = extractor.extract(episode);

      expect(result, isNull);
    });

    test('extracts from description', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'description',
        pattern: r'Part of the (.+?) arc',
        group: 1,
      );

      final episode = makeEpisode(
        description: 'Part of the Mystery arc - episode 5',
      );
      final result = extractor.extract(episode);

      expect(result, 'Mystery');
    });

    test('returns null when source field is null', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'seasonNumber',
        template: 'Season {value}',
      );

      final episode = makeEpisode(seasonNumber: null);
      final result = extractor.extract(episode);

      expect(result, isNull);
    });

    test('uses fallback string for null seasonNumber', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'title',
        pattern: r'【COTEN RADIO (ショート)?\s*(.+?)\s+\d+】',
        group: 2,
        fallbackValue: '番外編',
      );

      final episode = makeEpisode(title: '【番外編＃135】仏教のこと', seasonNumber: null);
      final result = extractor.extract(episode);

      expect(result, '番外編');
    });

    test('uses fallback string for seasonNumber zero', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'title',
        pattern: r'【COTEN RADIO (ショート)?\s*(.+?)\s+\d+】',
        group: 2,
        fallbackValue: '番外編',
      );

      final episode = makeEpisode(title: '【番外編＃135】仏教のこと', seasonNumber: 0);
      final result = extractor.extract(episode);

      expect(result, '番外編');
    });

    test('extracts COTEN RADIO playlist title from '
        'regular episode', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'title',
        pattern: r'【COTEN RADIO (ショート\s)?(.+?)\d+】',
        group: 2,
        fallbackValue: '番外編',
      );

      final episode = makeEpisode(
        title:
            '【62-15】何が変わった？'
            '【COTEN RADIO リンカン編15】',
        seasonNumber: 62,
      );
      final result = extractor.extract(episode);

      expect(result, 'リンカン編');
    });

    test('extracts COTEN RADIO short playlist title', () {
      final extractor = SmartPlaylistTitleExtractor(
        source: 'title',
        pattern: r'【COTEN RADIO (ショート\s)?(.+?)\d+】',
        group: 2,
        fallbackValue: '番外編',
      );

      final episode = makeEpisode(
        title:
            '【1-1】概要'
            '【COTEN RADIO ショート 織田信長編1】',
        seasonNumber: 1,
      );
      final result = extractor.extract(episode);

      expect(result, '織田信長編');
    });
  });
}
