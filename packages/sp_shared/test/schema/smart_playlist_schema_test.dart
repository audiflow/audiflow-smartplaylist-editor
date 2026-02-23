import 'dart:convert';
import 'dart:io';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

/// Loads the vendored schema.json from assets.
String _loadSchemaJson() {
  final file = File('packages/sp_shared/assets/schema.json');
  return file.readAsStringSync();
}

void main() {
  group('SmartPlaylistSchemaConstants', () {
    test('currentVersion is 1', () {
      expect(SmartPlaylistSchemaConstants.currentVersion, 1);
    });

    test('validResolverTypes contains expected values', () {
      expect(
        SmartPlaylistSchemaConstants.validResolverTypes,
        containsAll(['rss', 'category', 'year', 'titleAppearanceOrder']),
      );
    });

    test('validYearHeaderModes matches runtime enum', () {
      // Must match YearHeaderMode enum values
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
      validator = SmartPlaylistValidator.fromSchemaJson(_loadSchemaJson());
    });

    test('schemaMap contains expected top-level fields', () {
      final schema = validator.schemaMap;
      expect(schema[r'$schema'], contains('json-schema.org'));
      expect(schema['type'], 'object');
      expect(schema['properties'], containsPair('version', isA<Map>()));
      expect(schema['properties'], containsPair('patterns', isA<Map>()));
    });

    test('schemaString returns formatted JSON', () {
      final str = validator.schemaString;
      final decoded = jsonDecode(str) as Map<String, dynamic>;
      expect(decoded, contains(r'$schema'));
    });

    test('validates a known-good minimal config', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'feedUrls': ['test.com'],
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main',
                'resolverType': 'rss',
                'priority': 100,
              },
            ],
          },
        ],
      };
      expect(validator.validate(config), isEmpty);
    });

    test('returns errors for missing version', () {
      final config = {
        'patterns': [
          {
            'id': 'test',
            'playlists': [
              {'id': 'main', 'displayName': 'Main', 'resolverType': 'rss'},
            ],
          },
        ],
      };
      final errors = validator.validate(config);
      expect(errors, isNotEmpty);
    });

    test('returns errors for wrong version', () {
      final config = {'version': 99, 'patterns': <dynamic>[]};
      final errors = validator.validate(config);
      expect(errors, isNotEmpty);
    });

    test('returns errors for missing patterns', () {
      final config = {'version': 1};
      final errors = validator.validate(config);
      expect(errors, isNotEmpty);
    });

    test('returns errors for invalid resolverType', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main',
                'resolverType': 'nonexistent',
              },
            ],
          },
        ],
      };
      final errors = validator.validate(config);
      expect(errors, isNotEmpty);
    });

    test('validateString handles invalid JSON', () {
      final errors = validator.validateString('not valid json {{{');
      expect(errors, contains(contains('Invalid JSON')));
    });

    test('validateString validates a good config string', () {
      final config = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'playlists': [
              {'id': 'main', 'displayName': 'Main', 'resolverType': 'rss'},
            ],
          },
        ],
      });
      expect(validator.validateString(config), isEmpty);
    });

    test('validates a full complex config successfully', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'complex-podcast',
            'podcastGuid': 'abc-123-def',
            'feedUrls': [
              'https://example.com/feed',
              'https://mirror.example.com/rss',
            ],
            'yearGroupedEpisodes': true,
            'playlists': [
              {
                'id': 'seasons',
                'displayName': 'Seasons',
                'resolverType': 'rss',
                'priority': 100,
                'contentType': 'groups',
                'yearHeaderMode': 'firstEpisode',
                'episodeYearHeaders': true,
                'showDateRange': true,
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
              },
              {
                'id': 'categories',
                'displayName': 'Categories',
                'resolverType': 'category',
                'priority': 50,
                'titleFilter': r'(?:Main|Bonus)',
                'excludeFilter': r'(?:Trailer|Preview)',
                'requireFilter': r'\[.+\]',
                'groups': [
                  {
                    'id': 'main',
                    'displayName': 'Main Episodes',
                    'pattern': r'^Main\b',
                    'episodeYearHeaders': true,
                    'showDateRange': true,
                  },
                  {
                    'id': 'bonus',
                    'displayName': 'Bonus Content',
                    'pattern': r'^Bonus\b',
                  },
                  {'id': 'other', 'displayName': 'Other'},
                ],
              },
              {
                'id': 'by-year',
                'displayName': 'By Year',
                'resolverType': 'year',
                'yearHeaderMode': 'perEpisode',
                'customSort': {
                  'rules': [
                    {'field': 'alphabetical', 'order': 'ascending'},
                  ],
                },
              },
              {
                'id': 'appearance',
                'displayName': 'In Order',
                'resolverType': 'titleAppearanceOrder',
                'contentType': 'episodes',
              },
            ],
          },
        ],
      };
      expect(validator.validate(config), isEmpty);
    });

    test('validates empty patterns array', () {
      final config = {'version': 1, 'patterns': <dynamic>[]};
      expect(validator.validate(config), isEmpty);
    });

    test('returns errors for invalid contentType', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main',
                'resolverType': 'rss',
                'contentType': 'invalid',
              },
            ],
          },
        ],
      };
      final errors = validator.validate(config);
      expect(errors, isNotEmpty);
    });

    test('returns errors for invalid sort spec type', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main',
                'resolverType': 'rss',
                'customSort': {'type': 'unknown'},
              },
            ],
          },
        ],
      };
      final errors = validator.validate(config);
      expect(errors, isNotEmpty);
    });

    test('returns errors for invalid sort field', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main',
                'resolverType': 'rss',
                'customSort': {
                  'rules': [
                    {'field': 'invalid', 'order': 'ascending'},
                  ],
                },
              },
            ],
          },
        ],
      };
      final errors = validator.validate(config);
      expect(errors, isNotEmpty);
    });

    test('accepts yearHeaderMode none', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main',
                'resolverType': 'rss',
                'yearHeaderMode': 'none',
              },
            ],
          },
        ],
      };
      expect(validator.validate(config), isEmpty);
    });

    test('accepts yearHeaderMode perEpisode', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main',
                'resolverType': 'rss',
                'yearHeaderMode': 'perEpisode',
              },
            ],
          },
        ],
      };
      expect(validator.validate(config), isEmpty);
    });

    test('rejects old yearHeaderMode values', () {
      for (final invalid in ['lastEpisode', 'publishYear']) {
        final config = {
          'version': 1,
          'patterns': [
            {
              'id': 'test',
              'playlists': [
                {
                  'id': 'main',
                  'displayName': 'Main',
                  'resolverType': 'rss',
                  'yearHeaderMode': invalid,
                },
              ],
            },
          ],
        };
        expect(
          validator.validate(config),
          isNotEmpty,
          reason: 'Should reject yearHeaderMode "$invalid"',
        );
      }
    });

    test('accepts null seasonGroup in episode extractor', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main',
                'resolverType': 'rss',
                'smartPlaylistEpisodeExtractor': {
                  'source': 'title',
                  'pattern': r'E(\d+)',
                  'seasonGroup': null,
                },
              },
            ],
          },
        ],
      };
      expect(validator.validate(config), isEmpty);
    });

    test('accepts fallbackToRss in episode extractor', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main',
                'resolverType': 'rss',
                'smartPlaylistEpisodeExtractor': {
                  'source': 'title',
                  'pattern': r'E(\d+)',
                  'fallbackToRss': true,
                },
              },
            ],
          },
        ],
      };
      expect(validator.validate(config), isEmpty);
    });

    test('accepts greaterThan sort condition type', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'playlists': [
              {
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
              },
            ],
          },
        ],
      };
      expect(validator.validate(config), isEmpty);
    });
  });
}
