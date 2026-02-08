import '../http_client.dart';
import 'tool_definition.dart';

/// Validates a SmartPlaylist config against the JSON Schema.
///
/// Calls `POST /api/configs/validate` on the sp_server.
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
  McpHttpClient client,
  Map<String, dynamic> arguments,
) async {
  final config = arguments['config'];
  if (config is! Map<String, dynamic>) {
    throw ArgumentError('Missing or invalid required parameter: config');
  }
  return client.post('/api/configs/validate', {'config': config});
}
