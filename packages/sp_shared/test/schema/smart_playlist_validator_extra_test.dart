import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistValidator.fromSchemaJsons', () {
    late SmartPlaylistValidator validator;

    setUp(() {
      // Build from the embedded schema strings directly
      validator = SmartPlaylistValidator.fromSchemaJsons(
        patternIndexJson: patternIndexSchemaString,
        patternMetaJson: patternMetaSchemaString,
        playlistDefinitionJson: playlistDefinitionSchemaString,
      );
    });

    test('creates a working validator from JSON strings', () {
      expect(validator, isNotNull);
      expect(validator.patternIndexSchemaMap, isA<Map<String, dynamic>>());
      expect(validator.patternMetaSchemaMap, isA<Map<String, dynamic>>());
      expect(validator.playlistDefinitionSchemaMap, isA<Map<String, dynamic>>());
    });

    test('validates pattern index the same as default constructor', () {
      final defaultValidator = SmartPlaylistValidator();
      final validIndex = {
        'dataVersion': 1,
        'schemaVersion': 1,
        'patterns': <dynamic>[],
      };

      expect(validator.validatePatternIndex(validIndex), isEmpty);
      expect(defaultValidator.validatePatternIndex(validIndex), isEmpty);
    });
  });

  group('validatePatternMetaString', () {
    late SmartPlaylistValidator validator;

    setUp(() {
      validator = SmartPlaylistValidator();
    });

    test('returns empty list for valid pattern meta JSON string', () {
      final validMeta = jsonEncode({
        'dataVersion': 1,
        'id': 'test-pattern',
        'feedUrls': ['https://example.com/feed'],
        'playlists': ['playlist-1'],
      });

      final errors = validator.validatePatternMetaString(validMeta);
      expect(errors, isEmpty);
    });

    test('returns errors for invalid pattern meta JSON string', () {
      final invalidMeta = jsonEncode({
        'dataVersion': 1,
        // missing required 'id', 'feedUrls', 'playlists'
      });

      final errors = validator.validatePatternMetaString(invalidMeta);
      expect(errors, isNotEmpty);
    });

    test('returns error for malformed JSON', () {
      final errors = validator.validatePatternMetaString('{not valid json');
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Invalid JSON'));
    });
  });

  group('validatePatternIndexString', () {
    late SmartPlaylistValidator validator;

    setUp(() {
      validator = SmartPlaylistValidator();
    });

    test('returns empty list for valid pattern index JSON string', () {
      final validIndex = jsonEncode({
        'dataVersion': 1,
        'schemaVersion': 1,
        'patterns': <dynamic>[],
      });

      final errors = validator.validatePatternIndexString(validIndex);
      expect(errors, isEmpty);
    });

    test('returns errors for invalid pattern index JSON string', () {
      final invalidIndex = jsonEncode({
        'schemaVersion': 1,
        // missing required 'dataVersion' and 'patterns'
      });

      final errors = validator.validatePatternIndexString(invalidIndex);
      expect(errors, isNotEmpty);
    });

    test('returns error for malformed JSON', () {
      final errors = validator.validatePatternIndexString('{{broken');
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Invalid JSON'));
    });
  });
}
