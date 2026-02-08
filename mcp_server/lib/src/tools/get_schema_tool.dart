import 'dart:convert';

import '../http_client.dart';
import 'tool_definition.dart';

/// Gets the JSON Schema for SmartPlaylist configs.
///
/// Calls `GET /api/schema` on the sp_server.
const getSchemaTool = ToolDefinition(
  name: 'get_schema',
  description: 'Get the JSON Schema for SmartPlaylist configs',
  inputSchema: {'type': 'object', 'properties': {}},
);

/// Executes the get_schema tool.
///
/// The schema endpoint returns raw JSON, so we use [McpHttpClient.getRaw]
/// and decode the response ourselves.
Future<Map<String, dynamic>> executeGetSchema(
  McpHttpClient client,
  Map<String, dynamic> arguments,
) async {
  final raw = await client.getRaw('/api/schema');
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  return {'schema': decoded};
}
