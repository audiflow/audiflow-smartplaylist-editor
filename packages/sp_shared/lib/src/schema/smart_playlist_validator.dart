import 'dart:convert';

import 'package:json_schema/json_schema.dart';

import 'schema_data.dart';

/// Validates config JSON against the split JSON Schemas.
///
/// Holds three schemas (pattern-index, pattern-meta, playlist-definition)
/// and provides typed validation methods for each.
final class SmartPlaylistValidator {
  SmartPlaylistValidator._({
    required JsonSchema patternIndex,
    required JsonSchema patternMeta,
    required JsonSchema playlistDefinition,
  }) : _patternIndex = patternIndex,
       _patternMeta = patternMeta,
       _playlistDefinition = playlistDefinition;

  final JsonSchema _patternIndex;
  final JsonSchema _patternMeta;
  final JsonSchema _playlistDefinition;

  /// Creates a validator using the embedded schemas.
  factory SmartPlaylistValidator() {
    return SmartPlaylistValidator._(
      patternIndex: JsonSchema.create(patternIndexSchemaString),
      patternMeta: JsonSchema.create(patternMetaSchemaString),
      playlistDefinition: JsonSchema.create(playlistDefinitionSchemaString),
    );
  }

  /// Creates a validator from three JSON Schema strings.
  factory SmartPlaylistValidator.fromSchemaJsons({
    required String patternIndexJson,
    required String patternMetaJson,
    required String playlistDefinitionJson,
  }) {
    return SmartPlaylistValidator._(
      patternIndex: JsonSchema.create(patternIndexJson),
      patternMeta: JsonSchema.create(patternMetaJson),
      playlistDefinition: JsonSchema.create(playlistDefinitionJson),
    );
  }

  /// Returns all three schemas as a map keyed by schema file name.
  Map<String, dynamic> get allSchemasMap => {
    'pattern-index': patternIndexSchemaMap,
    'pattern-meta': patternMetaSchemaMap,
    'playlist-definition': playlistDefinitionSchemaMap,
  };

  /// Returns the pattern-index schema as a decoded map.
  Map<String, dynamic> get patternIndexSchemaMap =>
      _patternIndex.schemaMap! as Map<String, dynamic>;

  /// Returns the pattern-meta schema as a decoded map.
  Map<String, dynamic> get patternMetaSchemaMap =>
      _patternMeta.schemaMap! as Map<String, dynamic>;

  /// Returns the playlist-definition schema as a decoded map.
  Map<String, dynamic> get playlistDefinitionSchemaMap =>
      _playlistDefinition.schemaMap! as Map<String, dynamic>;

  /// Returns all schemas as a formatted JSON string.
  String get allSchemasString {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(allSchemasMap);
  }

  /// Validates a parsed JSON object against the pattern-index schema.
  List<String> validatePatternIndex(Object? parsed) =>
      _validate(_patternIndex, parsed);

  /// Validates a JSON string against the pattern-index schema.
  List<String> validatePatternIndexString(String jsonString) =>
      _validateString(_patternIndex, jsonString);

  /// Validates a parsed JSON object against the pattern-meta schema.
  List<String> validatePatternMeta(Object? parsed) =>
      _validate(_patternMeta, parsed);

  /// Validates a JSON string against the pattern-meta schema.
  List<String> validatePatternMetaString(String jsonString) =>
      _validateString(_patternMeta, jsonString);

  /// Validates a parsed JSON object against the playlist-definition schema.
  List<String> validatePlaylistDefinition(Object? parsed) =>
      _validate(_playlistDefinition, parsed);

  /// Validates a JSON string against the playlist-definition schema.
  List<String> validatePlaylistDefinitionString(String jsonString) =>
      _validateString(_playlistDefinition, jsonString);

  static List<String> _validate(JsonSchema schema, Object? parsed) {
    final result = schema.validate(parsed);
    if (result.isValid) return const [];
    return result.errors.map((e) => e.toString()).toList();
  }

  static List<String> _validateString(JsonSchema schema, String jsonString) {
    final Object? parsed;
    try {
      parsed = jsonDecode(jsonString);
    } on FormatException catch (e) {
      return ['Invalid JSON: ${e.message}'];
    }
    return _validate(schema, parsed);
  }
}
