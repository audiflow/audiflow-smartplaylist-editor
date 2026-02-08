import '../http_client.dart';
import 'tool_definition.dart';

/// Submits a config as a GitHub PR.
///
/// Calls `POST /api/configs/submit` on the sp_server.
const submitConfigTool = ToolDefinition(
  name: 'submit_config',
  description: 'Submit a config as a GitHub PR',
  inputSchema: {
    'type': 'object',
    'properties': {
      'config': {
        'type': 'object',
        'description': 'The SmartPlaylist config to submit',
      },
      'configId': {
        'type': 'string',
        'description': 'The unique identifier for the config',
      },
      'description': {
        'type': 'string',
        'description': 'Description for the PR',
      },
    },
    'required': ['config', 'configId'],
  },
);

/// Executes the submit_config tool.
///
/// Throws [ArgumentError] if the required parameters are missing.
Future<Map<String, dynamic>> executeSubmitConfig(
  McpHttpClient client,
  Map<String, dynamic> arguments,
) async {
  final config = arguments['config'];
  if (config is! Map<String, dynamic>) {
    throw ArgumentError('Missing or invalid required parameter: config');
  }
  final configId = arguments['configId'] as String?;
  if (configId == null || configId.isEmpty) {
    throw ArgumentError('Missing required parameter: configId');
  }
  final body = <String, dynamic>{'config': config, 'configId': configId};
  final description = arguments['description'] as String?;
  if (description != null && description.isNotEmpty) {
    body['description'] = description;
  }
  return client.post('/api/configs/submit', body);
}
