import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistSchemaConstants', () {
    test('currentDataVersion is 1', () {
      expect(SmartPlaylistSchemaConstants.currentDataVersion, 1);
    });

    test('currentSchemaVersion is 1', () {
      expect(SmartPlaylistSchemaConstants.currentSchemaVersion, 1);
    });

    test('validResolverTypes contains expected values', () {
      expect(
        SmartPlaylistSchemaConstants.validResolverTypes,
        containsAll(['rss', 'category', 'year', 'titleAppearanceOrder']),
      );
    });

    test('validYearHeaderModes matches runtime enum', () {
      expect(
        SmartPlaylistSchemaConstants.validYearHeaderModes,
        equals(['none', 'firstEpisode', 'perEpisode']),
      );
    });

    test('validContentTypes contains expected values', () {
      expect(
        SmartPlaylistSchemaConstants.validContentTypes,
        equals(['episodes', 'groups']),
      );
    });

    test('validSortFields contains expected values', () {
      expect(
        SmartPlaylistSchemaConstants.validSortFields,
        containsAll([
          'playlistNumber',
          'newestEpisodeDate',
          'progress',
          'alphabetical',
        ]),
      );
    });

    test('validSortOrders contains expected values', () {
      expect(
        SmartPlaylistSchemaConstants.validSortOrders,
        equals(['ascending', 'descending']),
      );
    });

    test('validSortConditionTypes contains both types', () {
      expect(
        SmartPlaylistSchemaConstants.validSortConditionTypes,
        containsAll(['sortKeyGreaterThan', 'greaterThan']),
      );
    });
  });

  group('SmartPlaylistValidator', () {
    late SmartPlaylistValidator validator;

    setUpAll(() {
      validator = SmartPlaylistValidator();
    });

    group('playlist-definition schema', () {
      test('allSchemasMap contains all three schemas', () {
        final schemas = validator.allSchemasMap;
        expect(schemas, contains('pattern-index'));
        expect(schemas, contains('pattern-meta'));
        expect(schemas, contains('playlist-definition'));
      });

      test('allSchemasString returns formatted JSON', () {
        final str = validator.allSchemasString;
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        expect(decoded, contains('pattern-index'));
        expect(decoded, contains('playlist-definition'));
      });

      test('validates a known-good minimal playlist', () {
        final playlist = {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
          'priority': 100,
        };
        expect(validator.validatePlaylistDefinition(playlist), isEmpty);
      });

      test('returns errors for missing required fields', () {
        final playlist = {'id': 'main'};
        final errors = validator.validatePlaylistDefinition(playlist);
        expect(errors, isNotEmpty);
      });

      test('returns errors for invalid resolverType', () {
        final playlist = {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'nonexistent',
        };
        expect(validator.validatePlaylistDefinition(playlist), isNotEmpty);
      });

      test('returns errors for invalid contentType', () {
        final playlist = {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
          'contentType': 'invalid',
        };
        expect(validator.validatePlaylistDefinition(playlist), isNotEmpty);
      });

      test('returns errors for invalid sort spec', () {
        final playlist = {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
          'customSort': {'type': 'unknown'},
        };
        expect(validator.validatePlaylistDefinition(playlist), isNotEmpty);
      });

      test('returns errors for invalid sort field', () {
        final playlist = {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
          'customSort': {
            'rules': [
              {'field': 'invalid', 'order': 'ascending'},
            ],
          },
        };
        expect(validator.validatePlaylistDefinition(playlist), isNotEmpty);
      });

      test('accepts yearHeaderMode none', () {
        final playlist = {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
          'yearHeaderMode': 'none',
        };
        expect(validator.validatePlaylistDefinition(playlist), isEmpty);
      });

      test('accepts yearHeaderMode perEpisode', () {
        final playlist = {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
          'yearHeaderMode': 'perEpisode',
        };
        expect(validator.validatePlaylistDefinition(playlist), isEmpty);
      });

      test('rejects old yearHeaderMode values', () {
        for (final invalid in ['lastEpisode', 'publishYear']) {
          final playlist = {
            'id': 'main',
            'displayName': 'Main',
            'resolverType': 'rss',
            'yearHeaderMode': invalid,
          };
          expect(
            validator.validatePlaylistDefinition(playlist),
            isNotEmpty,
            reason: 'Should reject yearHeaderMode "$invalid"',
          );
        }
      });

      test('accepts null seasonGroup in episode extractor', () {
        final playlist = {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
          'smartPlaylistEpisodeExtractor': {
            'source': 'title',
            'pattern': r'E(\d+)',
            'seasonGroup': null,
          },
        };
        expect(validator.validatePlaylistDefinition(playlist), isEmpty);
      });

      test('accepts fallbackToRss in episode extractor', () {
        final playlist = {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
          'smartPlaylistEpisodeExtractor': {
            'source': 'title',
            'pattern': r'E(\d+)',
            'fallbackToRss': true,
          },
        };
        expect(validator.validatePlaylistDefinition(playlist), isEmpty);
      });

      test('accepts greaterThan sort condition type', () {
        final playlist = {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
          'customSort': {
            'rules': [
              {
                'field': 'playlistNumber',
                'order': 'ascending',
                'condition': {'type': 'greaterThan', 'value': 5},
              },
            ],
          },
        };
        expect(validator.validatePlaylistDefinition(playlist), isEmpty);
      });

      test('validates full complex playlist', () {
        final playlist = {
          'id': 'seasons',
          'displayName': 'Seasons',
          'resolverType': 'rss',
          'priority': 100,
          'contentType': 'groups',
          'yearHeaderMode': 'firstEpisode',
          'episodeYearHeaders': true,
          'showDateRange': true,
          'showSeasonNumber': true,
          'nullSeasonGroupKey': 0,
          'customSort': {
            'rules': [
              {
                'field': 'playlistNumber',
                'order': 'descending',
                'condition': {'type': 'sortKeyGreaterThan', 'value': 0},
              },
              {'field': 'newestEpisodeDate', 'order': 'descending'},
            ],
          },
          'titleExtractor': {
            'source': 'title',
            'pattern': r'\[(.+?)\s+\d+\]',
            'group': 1,
            'template': 'Season {value}',
            'fallback': {
              'source': 'seasonNumber',
              'template': 'Season {value}',
              'fallbackValue': 'Specials',
            },
          },
          'smartPlaylistEpisodeExtractor': {
            'source': 'title',
            'pattern': r'\[(\d+)-(\d+)\]',
            'seasonGroup': 1,
            'episodeGroup': 2,
            'fallbackSeasonNumber': 0,
            'fallbackEpisodePattern': r'\[bangai-hen\s*#(\d+)\]',
            'fallbackEpisodeCaptureGroup': 1,
          },
        };
        expect(validator.validatePlaylistDefinition(playlist), isEmpty);
      });

      test('validatePlaylistDefinitionString handles invalid JSON', () {
        final errors =
            validator.validatePlaylistDefinitionString('not valid json {{{');
        expect(errors, contains(contains('Invalid JSON')));
      });

      test('validatePlaylistDefinitionString validates good JSON', () {
        final json = jsonEncode({
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
        });
        expect(validator.validatePlaylistDefinitionString(json), isEmpty);
      });

      test('rejects negative priority', () {
        final playlist = {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
          'priority': -1,
        };
        expect(validator.validatePlaylistDefinition(playlist), isNotEmpty);
      });
    });

    group('pattern-index schema', () {
      test('validates a known-good pattern index', () {
        final index = {
          'dataVersion': 1,
          'schemaVersion': 1,
          'patterns': [
            {
              'id': 'test',
              'dataVersion': 1,
              'displayName': 'Test',
              'feedUrlHint': 'https://example.com',
              'playlistCount': 2,
            },
          ],
        };
        expect(validator.validatePatternIndex(index), isEmpty);
      });

      test('validates empty patterns array', () {
        final index = {
          'dataVersion': 1,
          'schemaVersion': 1,
          'patterns': <dynamic>[],
        };
        expect(validator.validatePatternIndex(index), isEmpty);
      });

      test('returns errors for missing dataVersion', () {
        final index = {
          'schemaVersion': 1,
          'patterns': <dynamic>[],
        };
        expect(validator.validatePatternIndex(index), isNotEmpty);
      });

      test('accepts dataVersion values above 1', () {
        final index = {
          'dataVersion': 2,
          'schemaVersion': 1,
          'patterns': <dynamic>[],
        };
        expect(validator.validatePatternIndex(index), isEmpty);
      });

      test('rejects dataVersion below 1', () {
        final index = {
          'dataVersion': 0,
          'schemaVersion': 1,
          'patterns': <dynamic>[],
        };
        expect(validator.validatePatternIndex(index), isNotEmpty);
      });
    });

    group('pattern-meta schema', () {
      test('validates a known-good pattern meta', () {
        final meta = {
          'dataVersion': 1,
          'id': 'test',
          'feedUrls': ['https://example.com/feed'],
          'playlists': ['main'],
        };
        expect(validator.validatePatternMeta(meta), isEmpty);
      });

      test('validates with optional fields', () {
        final meta = {
          'dataVersion': 1,
          'id': 'test',
          'podcastGuid': 'guid-123',
          'feedUrls': ['https://example.com/feed'],
          'yearGroupedEpisodes': true,
          'playlists': ['main', 'seasons'],
        };
        expect(validator.validatePatternMeta(meta), isEmpty);
      });

      test('returns errors for empty feedUrls', () {
        final meta = {
          'dataVersion': 1,
          'id': 'test',
          'feedUrls': <dynamic>[],
          'playlists': ['main'],
        };
        expect(validator.validatePatternMeta(meta), isNotEmpty);
      });

      test('returns errors for empty playlists', () {
        final meta = {
          'dataVersion': 1,
          'id': 'test',
          'feedUrls': ['https://example.com/feed'],
          'playlists': <dynamic>[],
        };
        expect(validator.validatePatternMeta(meta), isNotEmpty);
      });

      test('returns errors for missing id', () {
        final meta = {
          'dataVersion': 1,
          'feedUrls': ['https://example.com/feed'],
          'playlists': ['main'],
        };
        expect(validator.validatePatternMeta(meta), isNotEmpty);
      });
    });
  });
}
