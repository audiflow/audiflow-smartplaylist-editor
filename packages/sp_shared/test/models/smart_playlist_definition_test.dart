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
        priority: 1,
        titleFilter: r'^\[\d+',
        excludeFilter: r'bonus',
        nullSeasonGroupKey: 0,
        customSort: const SimpleSmartPlaylistSort(
          SmartPlaylistSortField.playlistNumber,
          SortOrder.ascending,
        ),
        titleExtractor: const SmartPlaylistTitleExtractor(
          source: 'seasonNumber',
          template: 'Season {value}',
        ),
        episodeNumberExtractor: const EpisodeNumberExtractor(
          pattern: r'\[(\d+)-(\d+)\]',
          captureGroup: 2,
        ),
        smartPlaylistEpisodeExtractor: const SmartPlaylistEpisodeExtractor(
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
      expect(decoded.priority, 1);
      expect(decoded.titleFilter, r'^\[\d+');
      expect(decoded.excludeFilter, r'bonus');
      expect(decoded.nullSeasonGroupKey, 0);
      expect(decoded.customSort, isA<SimpleSmartPlaylistSort>());
      expect(decoded.titleExtractor, isNotNull);
      expect(decoded.episodeNumberExtractor, isNotNull);
      expect(decoded.smartPlaylistEpisodeExtractor, isNotNull);
    });

    test('round-trip with category groups', () {
      const def = SmartPlaylistDefinition(
        id: 'categories',
        displayName: 'Categories',
        resolverType: 'categoryGroup',
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

    test('fromJson converts empty string filters to null', () {
      final json = {
        'id': 'test',
        'displayName': 'Test',
        'resolverType': 'year',
        'titleFilter': '',
        'excludeFilter': '',
        'requireFilter': '',
        'contentType': '',
        'yearHeaderMode': '',
      };

      final def = SmartPlaylistDefinition.fromJson(json);

      expect(def.titleFilter, isNull);
      expect(def.excludeFilter, isNull);
      expect(def.requireFilter, isNull);
      expect(def.contentType, isNull);
      expect(def.yearHeaderMode, isNull);
    });

    test('fromJson preserves non-empty filter strings', () {
      final json = {
        'id': 'test',
        'displayName': 'Test',
        'resolverType': 'year',
        'titleFilter': r'^\d+',
        'excludeFilter': r'bonus',
        'requireFilter': r'main',
        'contentType': 'groups',
        'yearHeaderMode': 'firstEpisode',
      };

      final def = SmartPlaylistDefinition.fromJson(json);

      expect(def.titleFilter, r'^\d+');
      expect(def.excludeFilter, r'bonus');
      expect(def.requireFilter, r'main');
      expect(def.contentType, 'groups');
      expect(def.yearHeaderMode, 'firstEpisode');
    });

    test('minimal definition with required fields only', () {
      const def = SmartPlaylistDefinition(
        id: 'simple',
        displayName: 'Simple',
        resolverType: 'flat',
      );

      final json = def.toJson();

      // Only required keys present
      expect(json.keys, containsAll(['id', 'displayName', 'resolverType']));
      expect(json.containsKey('priority'), isFalse);
      expect(json.containsKey('groups'), isFalse);
      expect(json.containsKey('customSort'), isFalse);

      final decoded = SmartPlaylistDefinition.fromJson(json);

      expect(decoded.id, 'simple');
      expect(decoded.priority, 0);
      expect(decoded.episodeYearHeaders, isFalse);
      expect(decoded.groups, isNull);
      expect(decoded.customSort, isNull);
      expect(decoded.titleExtractor, isNull);
      expect(decoded.episodeNumberExtractor, isNull);
      expect(decoded.smartPlaylistEpisodeExtractor, isNull);
    });
  });
}
