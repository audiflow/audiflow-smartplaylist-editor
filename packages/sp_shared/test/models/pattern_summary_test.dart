import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('PatternSummary', () {
    test('constructs with required fields', () {
      final summary = PatternSummary(
        id: 'coten_radio',
        version: 1,
        displayName: 'Coten Radio',
        feedUrlHint: 'anchor.fm/s/8c2088c',
        playlistCount: 3,
      );
      expect(summary.id, 'coten_radio');
      expect(summary.version, 1);
      expect(summary.displayName, 'Coten Radio');
      expect(summary.feedUrlHint, 'anchor.fm/s/8c2088c');
      expect(summary.playlistCount, 3);
    });

    test('deserializes from JSON', () {
      final json = {
        'id': 'coten_radio',
        'version': 2,
        'displayName': 'Coten Radio',
        'feedUrlHint': 'anchor.fm/s/8c2088c',
        'playlistCount': 3,
      };
      final summary = PatternSummary.fromJson(json);
      expect(summary.id, 'coten_radio');
      expect(summary.version, 2);
      expect(summary.playlistCount, 3);
    });

    test('serializes to JSON', () {
      final summary = PatternSummary(
        id: 'news',
        version: 1,
        displayName: 'News',
        feedUrlHint: 'example.com',
        playlistCount: 2,
      );
      final json = summary.toJson();
      expect(json['id'], 'news');
      expect(json['version'], 1);
      expect(json['displayName'], 'News');
      expect(json['feedUrlHint'], 'example.com');
      expect(json['playlistCount'], 2);
    });

    test('roundtrips through JSON', () {
      final original = PatternSummary(
        id: 'test',
        version: 5,
        displayName: 'Test Pattern',
        feedUrlHint: 'test.com/feed',
        playlistCount: 1,
      );
      final restored = PatternSummary.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.version, original.version);
      expect(restored.displayName, original.displayName);
      expect(restored.feedUrlHint, original.feedUrlHint);
      expect(restored.playlistCount, original.playlistCount);
    });
  });
}
