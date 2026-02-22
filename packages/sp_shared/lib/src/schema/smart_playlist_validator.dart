import 'dart:convert';

import 'package:json_schema/json_schema.dart';

import 'schema_data.dart';

/// Validates config JSON against the vendored JSON Schema.
///
/// Use the default constructor for the embedded schema, or
/// [fromSchemaJson] for a custom schema string.
final class SmartPlaylistValidator {
  SmartPlaylistValidator._(this._schema);

  final JsonSchema _schema;

  /// Creates a validator using the embedded schema.
  factory SmartPlaylistValidator() {
    return SmartPlaylistValidator.fromSchemaJson(schemaJsonString);
  }

  /// Creates a validator from a JSON Schema string.
  factory SmartPlaylistValidator.fromSchemaJson(String schemaJson) {
    final schema = JsonSchema.create(schemaJson);
    return SmartPlaylistValidator._(schema);
  }

  /// Returns the raw JSON Schema as a decoded map.
  Map<String, dynamic> get schemaMap =>
      _schema.schemaMap! as Map<String, dynamic>;

  /// Returns the JSON Schema as a formatted string.
  String get schemaString {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(schemaMap);
  }

  /// Validates a parsed JSON object against the schema.
  ///
  /// Returns a list of error messages (empty = valid).
  List<String> validate(Object? parsed) {
    final result = _schema.validate(parsed);
    if (result.isValid) return const [];
    return result.errors.map((e) => e.message).toList();
  }

  /// Validates a JSON string against the schema.
  ///
  /// Returns a list of error messages (empty = valid).
  List<String> validateString(String jsonString) {
    final Object? parsed;
    try {
      parsed = jsonDecode(jsonString);
    } on FormatException catch (e) {
      return ['Invalid JSON: ${e.message}'];
    }
    return validate(parsed);
  }
}
