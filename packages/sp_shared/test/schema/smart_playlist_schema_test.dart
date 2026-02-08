import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistSchema', () {
    group('generate()', () {
      test('generates valid JSON Schema', () {
        final schema = SmartPlaylistSchema.generate();
        final decoded = jsonDecode(schema) as Map<String, dynamic>;

        expect(decoded[r'$schema'], contains('json-schema.org'));
        expect(decoded['type'], 'object');
        expect(decoded['properties'], containsPair('version', isA<Map>()));
        expect(decoded['properties'], containsPair('patterns', isA<Map>()));
      });

      test('includes \$defs for all sub-schemas', () {
        final schema = SmartPlaylistSchema.generate();
        final decoded = jsonDecode(schema) as Map<String, dynamic>;
        final defs = decoded[r'$defs'] as Map<String, dynamic>;

        expect(defs, contains('SmartPlaylistPatternConfig'));
        expect(defs, contains('SmartPlaylistDefinition'));
        expect(defs, contains('SmartPlaylistGroupDef'));
        expect(defs, contains('SmartPlaylistSortSpec'));
        expect(defs, contains('SmartPlaylistSortRule'));
        expect(defs, contains('SmartPlaylistSortCondition'));
        expect(defs, contains('SmartPlaylistTitleExtractor'));
        expect(defs, contains('EpisodeNumberExtractor'));
        expect(defs, contains('SmartPlaylistEpisodeExtractor'));
      });

      test('includes descriptions for all top-level properties', () {
        final schema = SmartPlaylistSchema.generate();
        final decoded = jsonDecode(schema) as Map<String, dynamic>;
        final properties = decoded['properties'] as Map<String, dynamic>;

        for (final entry in properties.entries) {
          final prop = entry.value as Map<String, dynamic>;
          expect(
            prop,
            contains('description'),
            reason: 'Property "${entry.key}" should have a description',
          );
        }
      });

      test('version property has const constraint', () {
        final schema = SmartPlaylistSchema.generate();
        final decoded = jsonDecode(schema) as Map<String, dynamic>;
        final properties = decoded['properties'] as Map<String, dynamic>;
        final version = properties['version'] as Map<String, dynamic>;

        expect(version['const'], SmartPlaylistSchema.currentVersion);
      });

      test('SmartPlaylistDefinition has resolver type enum', () {
        final schema = SmartPlaylistSchema.generate();
        final decoded = jsonDecode(schema) as Map<String, dynamic>;
        final defs = decoded[r'$defs'] as Map<String, dynamic>;
        final definition =
            defs['SmartPlaylistDefinition'] as Map<String, dynamic>;
        final props = definition['properties'] as Map<String, dynamic>;
        final resolverType = props['resolverType'] as Map<String, dynamic>;

        expect(resolverType['enum'], SmartPlaylistSchema.validResolverTypes);
      });
    });

    group('validate()', () {
      test('validates a known-good minimal config', () {
        final config = {
          'version': 1,
          'patterns': [
            {
              'id': 'test',
              'feedUrlPatterns': [r'test\.com'],
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
        expect(SmartPlaylistSchema.validate(jsonEncode(config)), isEmpty);
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
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('version')));
      });

      test('returns errors for wrong version', () {
        final config = {'version': 99, 'patterns': []};
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('Unsupported version: 99')));
      });

      test('returns errors for missing patterns', () {
        final config = {'version': 1};
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('patterns')));
      });

      test('returns errors for missing required playlist fields', () {
        final config = {
          'version': 1,
          'patterns': [
            {
              'id': 'test',
              'playlists': [
                {
                  // Missing id, displayName, resolverType
                },
              ],
            },
          ],
        };
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('"id"')));
        expect(errors, contains(contains('"displayName"')));
        expect(errors, contains(contains('"resolverType"')));
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
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('invalid value "nonexistent"')));
      });

      test('returns errors for invalid JSON string', () {
        final errors = SmartPlaylistSchema.validate('not valid json {{{');
        expect(errors, contains(contains('Invalid JSON')));
      });

      test('returns errors when root is not an object', () {
        final errors = SmartPlaylistSchema.validate('"just a string"');
        expect(errors, contains(contains('Root must be a JSON object')));
      });

      test('returns errors for wrong type on version field', () {
        final config = {'version': 'one', 'patterns': []};
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('must be an integer')));
      });

      test('validates a full complex config successfully', () {
        final config = {
          'version': 1,
          'patterns': [
            {
              'id': 'complex-podcast',
              'podcastGuid': 'abc-123-def',
              'feedUrlPatterns': [
                r'https://example\.com/feed.*',
                r'https://mirror\.example\.com/.*',
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
                    'type': 'composite',
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
                  'episodeNumberExtractor': {
                    'pattern': r'\[\w+\s+(\d+)\]',
                    'captureGroup': 1,
                    'fallbackToRss': true,
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
                  'yearHeaderMode': 'publishYear',
                  'customSort': {
                    'type': 'simple',
                    'field': 'alphabetical',
                    'order': 'ascending',
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
        expect(SmartPlaylistSchema.validate(jsonEncode(config)), isEmpty);
      });

      test('validates empty patterns array', () {
        final config = {'version': 1, 'patterns': <dynamic>[]};
        expect(SmartPlaylistSchema.validate(jsonEncode(config)), isEmpty);
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
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('invalid value "invalid"')));
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
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('Must be "simple" or "composite"')));
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
                    'type': 'simple',
                    'field': 'invalid',
                    'order': 'ascending',
                  },
                },
              ],
            },
          ],
        };
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('invalid value "invalid"')));
      });

      test('returns errors for invalid title extractor source', () {
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
                  'titleExtractor': {'source': 'invalid'},
                },
              ],
            },
          ],
        };
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('invalid value "invalid"')));
      });

      test('returns errors for missing pattern config id', () {
        final config = {
          'version': 1,
          'patterns': [
            {
              'playlists': [
                {'id': 'main', 'displayName': 'Main', 'resolverType': 'rss'},
              ],
            },
          ],
        };
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('missing required field "id"')));
      });

      test('returns errors for missing episode extractor pattern', () {
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
                  'episodeNumberExtractor': {
                    // Missing required 'pattern'
                  },
                },
              ],
            },
          ],
        };
        final errors = SmartPlaylistSchema.validate(jsonEncode(config));
        expect(errors, contains(contains('"pattern"')));
      });
    });
  });
}
