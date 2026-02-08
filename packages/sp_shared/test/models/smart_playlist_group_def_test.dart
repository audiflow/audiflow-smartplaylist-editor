import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistGroupDef', () {
    test('round-trip with pattern', () {
      const def = SmartPlaylistGroupDef(
        id: 'main',
        displayName: 'Main Episodes',
        pattern: r'^\[\d+-\d+\]',
      );

      final json = def.toJson();
      final decoded = SmartPlaylistGroupDef.fromJson(json);

      expect(decoded.id, 'main');
      expect(decoded.displayName, 'Main Episodes');
      expect(decoded.pattern, r'^\[\d+-\d+\]');
    });

    test('round-trip without pattern (fallback)', () {
      const def = SmartPlaylistGroupDef(id: 'other', displayName: 'Other');

      final json = def.toJson();
      final decoded = SmartPlaylistGroupDef.fromJson(json);

      expect(decoded.id, 'other');
      expect(decoded.displayName, 'Other');
      expect(decoded.pattern, isNull);
      // pattern key should be absent from JSON
      expect(json.containsKey('pattern'), isFalse);
    });

    test('round-trip through JSON string encoding', () {
      const def = SmartPlaylistGroupDef(
        id: 'bonus',
        displayName: 'Bonus',
        pattern: r'bonus',
      );

      final jsonString = jsonEncode(def.toJson());
      final decoded = SmartPlaylistGroupDef.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

      expect(decoded.id, def.id);
      expect(decoded.displayName, def.displayName);
      expect(decoded.pattern, def.pattern);
    });
  });
}
