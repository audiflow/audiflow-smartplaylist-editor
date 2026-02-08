import '../http_client.dart';
import 'tool_definition.dart';

/// Gets a specific SmartPlaylist config by ID.
///
/// Calls `GET /api/configs/{id}` on the sp_server.
const getConfigTool = ToolDefinition(
  name: 'get_config',
  description: 'Get a specific SmartPlaylist config by ID',
  inputSchema: {
    'type': 'object',
    'properties': {
      'id': {
        'type': 'string',
        'description': 'The unique identifier of the config',
      },
    },
    'required': ['id'],
  },
);

/// Executes the get_config tool.
///
/// Throws [ArgumentError] if the required `id` parameter is missing.
Future<Map<String, dynamic>> executeGetConfig(
  McpHttpClient client,
  Map<String, dynamic> arguments,
) async {
  final id = arguments['id'] as String?;
  if (id == null || id.isEmpty) {
    throw ArgumentError('Missing required parameter: id');
  }
  return client.get('/api/configs/$id');
}
