import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

/// Parses the vendored playlist-definition schema to extract enum values.
Map<String, dynamic> _loadPlaylistDefinitionSchema() {
  return jsonDecode(playlistDefinitionSchemaString) as Map<String, dynamic>;
}

/// Parses the vendored pattern-index schema.
Map<String, dynamic> _loadPatternIndexSchema() {
  return jsonDecode(patternIndexSchemaString) as Map<String, dynamic>;
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
  late Map<String, dynamic> playlistSchema;
  late Map<String, dynamic> defs;
  late Map<String, dynamic> topProps;
  late Map<String, dynamic> indexSchema;

  setUpAll(() {
    playlistSchema = _loadPlaylistDefinitionSchema();
    defs = playlistSchema[r'$defs'] as Map<String, dynamic>;
    topProps = playlistSchema['properties'] as Map<String, dynamic>;
    indexSchema = _loadPatternIndexSchema();
  });

  group('constants match vendored playlist-definition schema', () {
    test('resolverTypes match schema oneOf', () {
      final resolverType = topProps['resolverType'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(resolverType);
      expect(
        SmartPlaylistSchemaConstants.validResolverTypes,
        equals(schemaValues),
      );
    });

    test('playlistStructures match schema oneOf', () {
      final playlistStructure =
          topProps['playlistStructure'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(playlistStructure);
      expect(
        SmartPlaylistSchemaConstants.validPlaylistStructures,
        equals(schemaValues),
      );
    });

    test('yearBindings match schema \$defs/YearBinding oneOf', () {
      final yearBinding = defs['YearBinding'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(yearBinding);
      expect(
        SmartPlaylistSchemaConstants.validYearBindings,
        equals(schemaValues),
      );
    });

    test('sortFields match schema SortRule field oneOf', () {
      final sortRule = defs['SortRule'] as Map<String, dynamic>;
      final props = sortRule['properties'] as Map<String, dynamic>;
      final field = props['field'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(field);
      expect(
        SmartPlaylistSchemaConstants.validSortFields,
        equals(schemaValues),
      );
    });

    test('episodeSortFields match schema EpisodeSortRule field oneOf', () {
      final episodeSortRule = defs['EpisodeSortRule'] as Map<String, dynamic>;
      final props = episodeSortRule['properties'] as Map<String, dynamic>;
      final field = props['field'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(field);
      expect(
        SmartPlaylistSchemaConstants.validEpisodeSortFields,
        equals(schemaValues),
      );
    });

    test('sortOrders match schema \$defs/SortOrder enum', () {
      final sortOrder = defs['SortOrder'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(sortOrder);
      expect(
        SmartPlaylistSchemaConstants.validSortOrders,
        equals(schemaValues),
      );
    });

    test('titleExtractorSources match schema enum', () {
      final titleExtractor = defs['TitleExtractor'] as Map<String, dynamic>;
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
          defs['EpisodeExtractor'] as Map<String, dynamic>;
      final props = episodeExtractor['properties'] as Map<String, dynamic>;
      final source = props['source'] as Map<String, dynamic>;
      final schemaValues = _extractEnum(source);
      expect(
        SmartPlaylistSchemaConstants.validEpisodeExtractorSources,
        equals(schemaValues),
      );
    });
  });

  group('version constraints match pattern-index schema', () {
    test('dataVersion uses minimum constraint', () {
      final props = indexSchema['properties'] as Map<String, dynamic>;
      final dataVersion = props['dataVersion'] as Map<String, dynamic>;
      expect(dataVersion['minimum'], equals(1));
      expect(dataVersion.containsKey('const'), isFalse);
    });

    test('schemaVersion uses minimum constraint', () {
      final props = indexSchema['properties'] as Map<String, dynamic>;
      final schemaVersion = props['schemaVersion'] as Map<String, dynamic>;
      expect(schemaVersion['minimum'], equals(1));
      expect(schemaVersion.containsKey('const'), isFalse);
    });

    test('patternIndexSchemaId matches schema \$id', () {
      expect(
        SmartPlaylistSchemaConstants.patternIndexSchemaId,
        equals(indexSchema[r'$id']),
      );
    });

    test('playlistDefinitionSchemaId matches schema \$id', () {
      expect(
        SmartPlaylistSchemaConstants.playlistDefinitionSchemaId,
        equals(playlistSchema[r'$id']),
      );
    });

    test('patternMetaSchemaId matches schema \$id', () {
      final metaSchema =
          jsonDecode(patternMetaSchemaString) as Map<String, dynamic>;
      expect(
        SmartPlaylistSchemaConstants.patternMetaSchemaId,
        equals(metaSchema[r'$id']),
      );
    });
  });

  group('model toJson round-trip validates against schema', () {
    late SmartPlaylistValidator validator;

    setUpAll(() {
      validator = SmartPlaylistValidator();
    });

    test('minimal SmartPlaylistDefinition validates directly', () {
      final def = SmartPlaylistDefinition(
        id: 'main',
        displayName: 'Main Episodes',
        resolverType: 'rss',
        playlistStructure: 'split',
      );
      expect(validator.validatePlaylistDefinition(def.toJson()), isEmpty);
    });

    test('full SmartPlaylistDefinition validates directly', () {
      final def = SmartPlaylistDefinition(
        id: 'seasons',
        displayName: 'Seasons',
        resolverType: 'rss',
        playlistStructure: 'grouped',
        priority: 100,
        episodeFilters: const EpisodeFilters(
          require: [EpisodeFilterEntry(title: r'S\d+')],
          exclude: [EpisodeFilterEntry(title: r'Trailer')],
        ),
        nullSeasonGroupKey: 0,
        prependSeasonNumber: true,
        groupList: const GroupListSettings(
          yearBinding: 'pinToYear',
          userSortable: true,
          showDateRange: true,
          sort: SmartPlaylistSortRule(
            field: SmartPlaylistSortField.playlistNumber,
            order: SortOrder.descending,
          ),
        ),
        episodeList: const EpisodeListSettings(
          showYearHeaders: true,
          sort: EpisodeSortRule(
            field: EpisodeSortField.publishedAt,
            order: SortOrder.ascending,
          ),
        ),
        groups: [
          SmartPlaylistGroupDef(
            id: 'main',
            displayName: 'Main',
            pattern: r'^Main\b',
            display: const GroupDefDisplay(showDateRange: true),
            episodeList: const GroupDefEpisodeList(showYearHeaders: true),
          ),
          SmartPlaylistGroupDef(id: 'other', displayName: 'Other'),
        ],
        titleExtractor: SmartPlaylistTitleExtractor(
          source: 'title',
          pattern: r'\[(.+?)\]',
          group: 1,
          template: 'Season {value}',
        ),
        episodeExtractor: SmartPlaylistEpisodeExtractor(
          source: 'title',
          pattern: r'\[(\d+)-(\d+)\]',
          seasonGroup: 1,
          episodeGroup: 2,
          fallbackToRss: true,
        ),
      );
      expect(validator.validatePlaylistDefinition(def.toJson()), isEmpty);
    });

    test('PatternMeta round-trips against pattern-meta schema', () {
      final meta = PatternMeta(
        dataVersion: 1,
        id: 'test-podcast',
        podcastGuid: 'guid-abc',
        feedUrls: ['https://example.com/feed'],
        yearGroupedEpisodes: true,
        playlists: ['seasons', 'categories'],
      );
      expect(validator.validatePatternMeta(meta.toJson()), isEmpty);
    });

    test('RootMeta round-trips against pattern-index schema', () {
      final rootMeta = RootMeta(
        dataVersion: 1,
        schemaVersion: 1,
        patterns: [
          PatternSummary(
            id: 'test',
            dataVersion: 1,
            displayName: 'Test Podcast',
            feedUrlHint: 'https://example.com/feed',
            playlistCount: 2,
          ),
        ],
      );
      expect(validator.validatePatternIndex(rootMeta.toJson()), isEmpty);
    });
  });
}
