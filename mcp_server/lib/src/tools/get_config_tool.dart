import 'package:sp_server/src/services/local_config_repository.dart';

import 'tool_definition.dart';

/// Gets a specific SmartPlaylist config by ID.
///
/// Assembles the full config from local pattern meta and playlist files.
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
  LocalConfigRepository repo,
  Map<String, dynamic> arguments,
) async {
  final id = arguments['id'] as String?;
  if (id == null || id.isEmpty) {
    throw ArgumentError('Missing required parameter: id');
  }
  final config = await repo.assembleConfig(id);
  return config.toJson();
}
