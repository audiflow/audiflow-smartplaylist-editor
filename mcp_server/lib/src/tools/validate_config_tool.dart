import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';

import 'tool_definition.dart';

/// Validates a SmartPlaylist config against the JSON Schema.
///
/// Uses the embedded schema from sp_shared for local validation.
/// The `type` parameter selects which schema to validate against:
/// - `playlistDefinition` (default): validates a playlist definition
/// - `patternMeta`: validates a pattern meta.json
/// - `patternIndex`: validates a root meta.json
const validateConfigTool = ToolDefinition(
  name: 'validate_config',
  description: 'Validate a SmartPlaylist config against the JSON Schema',
  inputSchema: {
    'type': 'object',
    'properties': {
      'config': {
        'type': 'object',
        'description': 'The config object to validate',
      },
      'type': {
        'type': 'string',
        'enum': ['playlistDefinition', 'patternMeta', 'patternIndex'],
        'description':
            'Schema type to validate against (default: playlistDefinition)',
      },
    },
    'required': ['config'],
  },
);

/// Executes the validate_config tool.
///
/// Throws [ArgumentError] if the required `config` parameter is missing.
Future<Map<String, dynamic>> executeValidateConfig(
  SmartPlaylistValidator validator,
  Map<String, dynamic> arguments,
) async {
  final config = arguments['config'];
  if (config is! Map<String, dynamic>) {
    throw ArgumentError('Missing or invalid required parameter: config');
  }

  final type = arguments['type'] as String? ?? 'playlistDefinition';
  final json = jsonEncode(config);
  final List<String> errors;
  switch (type) {
    case 'playlistDefinition':
      errors = validator.validatePlaylistDefinitionString(json);
    case 'patternMeta':
      errors = validator.validatePatternMetaString(json);
    case 'patternIndex':
      errors = validator.validatePatternIndexString(json);
    default:
      throw ArgumentError('Invalid type: $type');
  }
  return {'valid': errors.isEmpty, 'errors': errors};
}
