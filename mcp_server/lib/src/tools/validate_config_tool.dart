import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';

import 'tool_definition.dart';

/// Validates a SmartPlaylist config against the JSON Schema.
///
/// Uses the embedded schema from sp_shared for local validation.
const validateConfigTool = ToolDefinition(
  name: 'validate_config',
  description: 'Validate a SmartPlaylist config against the JSON Schema',
  inputSchema: {
    'type': 'object',
    'properties': {
      'config': {
        'type': 'object',
        'description': 'The SmartPlaylist config to validate',
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
  final errors = validator.validateString(jsonEncode(config));
  return {'valid': errors.isEmpty, 'errors': errors};
}
