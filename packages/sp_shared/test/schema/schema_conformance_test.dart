import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

/// Parses the vendored schema.json to extract enum values.
Map<String, dynamic> _loadSchema() {
  return jsonDecode(schemaJsonString) as Map<String, dynamic>;
}

/// Extracts enum values from a schema property definition.
List<String> _extractEnum(Map<String, dynamic> property) {
  if (property.containsKey('enum')) {
    return (property['enum'] as List<dynamic>).cast<String>();
  }
  if (property.containsKey('oneOf')) {
    return (property['oneOf'] as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['const'] as String)
        .toList();
  }
  return [];
}

void main() {
  late Map<String, dynamic> schema;
  late Map<String, dynamic> defs;

  setUpAll(() {
    schema = _loadSchema();
    defs = schema[r'$defs'] as Map<String, dynamic>;
  });

  group('constants match vendored schema.json', () {
    test('resolverTypes match schema oneOf', () {
      final definition =
          defs['SmartPlaylistDefinition'] as Map<String, dynamic>;
      final props = definition['properties'] as Map<String, dynamic>;
      final resolverType = props['resolverType'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(resolverType);
      expect(
        SmartPlaylistSchemaConstants.validResolverTypes,
        equals(schemaValues),
      );
    });

    test('contentTypes match schema enum', () {
      final definition =
          defs['SmartPlaylistDefinition'] as Map<String, dynamic>;
      final props = definition['properties'] as Map<String, dynamic>;
      final contentType = props['contentType'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(contentType);
      expect(
        SmartPlaylistSchemaConstants.validContentTypes,
        equals(schemaValues),
      );
    });

    test('yearHeaderModes match schema enum', () {
      final definition =
          defs['SmartPlaylistDefinition'] as Map<String, dynamic>;
      final props = definition['properties'] as Map<String, dynamic>;
      final yearHeaderMode = props['yearHeaderMode'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(yearHeaderMode);
      expect(
        SmartPlaylistSchemaConstants.validYearHeaderModes,
        equals(schemaValues),
      );
    });

    test('sortFields match schema oneOf', () {
      final sortRule = defs['SmartPlaylistSortRule'] as Map<String, dynamic>;
      final props = sortRule['properties'] as Map<String, dynamic>;
      final field = props['field'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(field);
      expect(
        SmartPlaylistSchemaConstants.validSortFields,
        equals(schemaValues),
      );
    });

    test('sortOrders match schema enum', () {
      final sortRule = defs['SmartPlaylistSortRule'] as Map<String, dynamic>;
      final props = sortRule['properties'] as Map<String, dynamic>;
      final order = props['order'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(order);
      expect(
        SmartPlaylistSchemaConstants.validSortOrders,
        equals(schemaValues),
      );
    });

    test('sortConditionTypes match schema enum', () {
      final sortCondition =
          defs['SmartPlaylistSortCondition'] as Map<String, dynamic>;
      final props = sortCondition['properties'] as Map<String, dynamic>;
      final type = props['type'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(type);
      expect(
        SmartPlaylistSchemaConstants.validSortConditionTypes,
        equals(schemaValues),
      );
    });

    test('titleExtractorSources match schema enum', () {
      final titleExtractor =
          defs['SmartPlaylistTitleExtractor'] as Map<String, dynamic>;
      final props = titleExtractor['properties'] as Map<String, dynamic>;
      final source = props['source'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(source);
      expect(
        SmartPlaylistSchemaConstants.validTitleExtractorSources,
        equals(schemaValues),
      );
    });

    test('episodeExtractorSources match schema enum', () {
      final episodeExtractor =
          defs['SmartPlaylistEpisodeExtractor'] as Map<String, dynamic>;
      final props = episodeExtractor['properties'] as Map<String, dynamic>;
      final source = props['source'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(source);
      expect(
        SmartPlaylistSchemaConstants.validEpisodeExtractorSources,
        equals(schemaValues),
      );
    });

    test('currentVersion matches schema const', () {
      final props = schema['properties'] as Map<String, dynamic>;
      final version = props['version'] as Map<String, dynamic>;
      expect(
        SmartPlaylistSchemaConstants.currentVersion,
        equals(version['const']),
      );
    });
  });

  group('model toJson round-trip validates against schema', () {
    late SmartPlaylistValidator validator;

    setUpAll(() {
      validator = SmartPlaylistValidator();
    });

    test('minimal SmartPlaylistDefinition round-trips', () {
      final def = SmartPlaylistDefinition(
        id: 'main',
        displayName: 'Main Episodes',
        resolverType: 'rss',
      );
      final wrapped = {
        'version': SmartPlaylistSchemaConstants.currentVersion,
        'patterns': [
          {
            'id': 'test',
            'playlists': [def.toJson()],
          },
        ],
      };
      expect(validator.validate(wrapped), isEmpty);
    });

    test('full SmartPlaylistDefinition round-trips', () {
      final def = SmartPlaylistDefinition(
        id: 'seasons',
        displayName: 'Seasons',
        resolverType: 'rss',
        priority: 100,
        contentType: 'groups',
        yearHeaderMode: 'firstEpisode',
        episodeYearHeaders: true,
        showDateRange: true,
        titleFilter: r'S\d+',
        excludeFilter: r'Trailer',
        requireFilter: r'\[.+\]',
        nullSeasonGroupKey: 0,
        groups: [
          SmartPlaylistGroupDef(
            id: 'main',
            displayName: 'Main',
            pattern: r'^Main\b',
          ),
          SmartPlaylistGroupDef(id: 'other', displayName: 'Other'),
        ],
        customSort: SmartPlaylistSortSpec([
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.playlistNumber,
            order: SortOrder.descending,
            condition: SortKeyGreaterThan(0),
          ),
          SmartPlaylistSortRule(
            field: SmartPlaylistSortField.newestEpisodeDate,
            order: SortOrder.descending,
          ),
        ]),
        titleExtractor: SmartPlaylistTitleExtractor(
          source: 'title',
          pattern: r'\[(.+?)\]',
          group: 1,
          template: 'Season {value}',
        ),
        smartPlaylistEpisodeExtractor: SmartPlaylistEpisodeExtractor(
          source: 'title',
          pattern: r'\[(\d+)-(\d+)\]',
          seasonGroup: 1,
          episodeGroup: 2,
          fallbackToRss: true,
        ),
      );
      final wrapped = {
        'version': SmartPlaylistSchemaConstants.currentVersion,
        'patterns': [
          {
            'id': 'complex',
            'podcastGuid': 'guid-123',
            'feedUrls': ['https://example.com/feed.xml'],
            'yearGroupedEpisodes': true,
            'playlists': [def.toJson()],
          },
        ],
      };
      expect(validator.validate(wrapped), isEmpty);
    });

    test('SmartPlaylistPatternConfig round-trips', () {
      final config = SmartPlaylistPatternConfig(
        id: 'test-podcast',
        podcastGuid: 'guid-abc',
        feedUrls: ['https://example.com/feed'],
        yearGroupedEpisodes: true,
        playlists: [
          SmartPlaylistDefinition(
            id: 'main',
            displayName: 'Main',
            resolverType: 'category',
            groups: [
              SmartPlaylistGroupDef(
                id: 'g1',
                displayName: 'Group 1',
                pattern: r'.*',
              ),
            ],
          ),
        ],
      );
      final wrapped = {
        'version': SmartPlaylistSchemaConstants.currentVersion,
        'patterns': [config.toJson()],
      };
      expect(validator.validate(wrapped), isEmpty);
    });
  });
}
