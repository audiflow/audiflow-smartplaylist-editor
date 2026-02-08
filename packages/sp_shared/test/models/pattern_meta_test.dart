import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('PatternMeta', () {
    test('deserializes from JSON', () {
      final json = {
        'version': 1,
        'id': 'coten_radio',
        'feedUrlPatterns': [r'https://anchor\.fm/s/8c2088c/podcast/rss'],
        'yearGroupedEpisodes': true,
        'playlists': ['regular', 'short', 'extras'],
      };
      final meta = PatternMeta.fromJson(json);
      expect(meta.version, 1);
      expect(meta.id, 'coten_radio');
      expect(meta.feedUrlPatterns, hasLength(1));
      expect(meta.yearGroupedEpisodes, isTrue);
      expect(meta.playlists, ['regular', 'short', 'extras']);
    });

    test('defaults yearGroupedEpisodes to false', () {
      final json = {
        'version': 1,
        'id': 'test',
        'feedUrlPatterns': <String>[],
        'playlists': ['main'],
      };
      final meta = PatternMeta.fromJson(json);
      expect(meta.yearGroupedEpisodes, isFalse);
    });

    test('handles optional podcastGuid', () {
      final json = {
        'version': 1,
        'id': 'test',
        'podcastGuid': 'abc-123',
        'feedUrlPatterns': <String>[],
        'playlists': ['main'],
      };
      final meta = PatternMeta.fromJson(json);
      expect(meta.podcastGuid, 'abc-123');
    });

    test('serializes to JSON', () {
      final meta = PatternMeta(
        version: 1,
        id: 'test',
        feedUrlPatterns: ['pattern1'],
        yearGroupedEpisodes: true,
        playlists: ['p1', 'p2'],
      );
      final json = meta.toJson();
      expect(json['version'], 1);
      expect(json['id'], 'test');
      expect(json['yearGroupedEpisodes'], isTrue);
      expect(json['playlists'], ['p1', 'p2']);
    });

    test('parses from JSON string', () {
      final jsonString = jsonEncode({
        'version': 1,
        'id': 'test',
        'feedUrlPatterns': ['pattern'],
        'playlists': ['main'],
      });
      final meta = PatternMeta.parseJson(jsonString);
      expect(meta.id, 'test');
    });

    test('roundtrips through JSON', () {
      final original = PatternMeta(
        version: 2,
        id: 'test',
        podcastGuid: 'guid-1',
        feedUrlPatterns: ['p1', 'p2'],
        yearGroupedEpisodes: true,
        playlists: ['a', 'b'],
      );
      final restored = PatternMeta.fromJson(original.toJson());
      expect(restored.version, original.version);
      expect(restored.id, original.id);
      expect(restored.podcastGuid, original.podcastGuid);
      expect(restored.feedUrlPatterns, original.feedUrlPatterns);
      expect(restored.yearGroupedEpisodes, original.yearGroupedEpisodes);
      expect(restored.playlists, original.playlists);
    });
  });
}
