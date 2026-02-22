import 'dart:convert';
import 'dart:io';

import 'tool_definition.dart';

/// Gets the JSON Schema for SmartPlaylist configs.
///
/// Reads the schema from the local data repo's schema directory.
const getSchemaTool = ToolDefinition(
  name: 'get_schema',
  description: 'Get the JSON Schema for SmartPlaylist configs',
  inputSchema: {'type': 'object', 'properties': {}},
);

/// Executes the get_schema tool.
///
/// Reads schema.json from disk at `$dataDir/schema/schema.json`.
Future<Map<String, dynamic>> executeGetSchema(
  String dataDir,
  Map<String, dynamic> arguments,
) async {
  final file = File('$dataDir/schema/schema.json');
  final raw = await file.readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  return {'schema': decoded};
}
