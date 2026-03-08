import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistDefinition', () {
    test('round-trip with full RSS config', () {
      final def = SmartPlaylistDefinition(
        id: 'main',
        displayName: 'Main Episodes',
        resolverType: 'rssSeason',
        playlistStructure: 'grouped',
        priority: 1,
        episodeFilters: const EpisodeFilters(
          require: [EpisodeFilterEntry(title: r'^\[\d+')],
          exclude: [EpisodeFilterEntry(title: r'bonus')],
        ),
        nullSeasonGroupKey: 0,
        groupList: const GroupListSettings(
          sort: SmartPlaylistSortRule(
            field: SmartPlaylistSortField.playlistNumber,
            order: SortOrder.ascending,
          ),
        ),
        titleExtractor: const SmartPlaylistTitleExtractor(
          source: 'seasonNumber',
          template: 'Season {value}',
        ),
        episodeExtractor: const SmartPlaylistEpisodeExtractor(
          source: 'title',
          pattern: r'\[(\d+)-(\d+)\]',
        ),
      );

      final json = def.toJson();
      final jsonString = jsonEncode(json);
      final decoded = SmartPlaylistDefinition.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(decoded.id, 'main');
      expect(decoded.displayName, 'Main Episodes');
      expect(decoded.resolverType, 'rssSeason');
      expect(decoded.playlistStructure, 'grouped');
      expect(decoded.priority, 1);
      expect(decoded.episodeFilters, isNotNull);
      expect(decoded.nullSeasonGroupKey, 0);
      expect(decoded.groupList, isNotNull);
      expect(decoded.groupList!.sort, isA<SmartPlaylistSortRule>());
      expect(decoded.titleExtractor, isNotNull);
      expect(decoded.episodeExtractor, isNotNull);
    });

    test('round-trip with category groups', () {
      const def = SmartPlaylistDefinition(
        id: 'categories',
        displayName: 'Categories',
        resolverType: 'categoryGroup',
        playlistStructure: 'grouped',
        groups: [
          SmartPlaylistGroupDef(
            id: 'tech',
            displayName: 'Tech',
            pattern: r'tech',
          ),
          SmartPlaylistGroupDef(id: 'other', displayName: 'Other'),
        ],
      );

      final json = def.toJson();
      final jsonString = jsonEncode(json);
      final decoded = SmartPlaylistDefinition.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(decoded.id, 'categories');
      expect(decoded.groups, hasLength(2));
      expect(decoded.groups![0].id, 'tech');
      expect(decoded.groups![0].pattern, r'tech');
      expect(decoded.groups![1].pattern, isNull);
    });

    test('hasFilters returns true when episodeFilters is present', () {
      const def = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'year',
        playlistStructure: 'split',
        episodeFilters: EpisodeFilters(
          require: [EpisodeFilterEntry(title: r'main')],
        ),
      );
      expect(def.hasFilters, isTrue);
    });

    test('hasFilters returns false when episodeFilters is null', () {
      const def = SmartPlaylistDefinition(
        id: 'test',
        displayName: 'Test',
        resolverType: 'year',
        playlistStructure: 'split',
      );
      expect(def.hasFilters, isFalse);
    });

    test('minimal definition with required fields only', () {
      const def = SmartPlaylistDefinition(
        id: 'simple',
        displayName: 'Simple',
        resolverType: 'flat',
        playlistStructure: 'split',
      );

      final json = def.toJson();

      // Required keys present
      expect(
        json.keys,
        containsAll(['id', 'displayName', 'resolverType', 'playlistStructure']),
      );
      expect(json.containsKey('priority'), isFalse);
      expect(json.containsKey('groups'), isFalse);
      expect(json.containsKey('groupList'), isFalse);

      final decoded = SmartPlaylistDefinition.fromJson(json);

      expect(decoded.id, 'simple');
      expect(decoded.priority, 0);
      expect(decoded.episodeFilters, isNull);
      expect(decoded.groups, isNull);
      expect(decoded.groupList, isNull);
      expect(decoded.episodeList, isNull);
      expect(decoded.titleExtractor, isNull);
      expect(decoded.episodeExtractor, isNull);
    });
  });
}
