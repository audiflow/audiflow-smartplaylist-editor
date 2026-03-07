import 'dart:convert';
import 'dart:io';

import 'tool_definition.dart';

/// Gets the JSON Schemas for SmartPlaylist configs.
///
/// Reads the split schema files from the local data repo's schema directory.
const getSchemaTool = ToolDefinition(
  name: 'get_schema',
  description: 'Get the JSON Schemas for SmartPlaylist configs',
  inputSchema: {'type': 'object', 'properties': {}},
);

/// Schema file names mapped to their keys in the response.
const _schemaFiles = {
  'pattern-index': 'pattern-index.schema.json',
  'pattern-meta': 'pattern-meta.schema.json',
  'playlist-definition': 'playlist-definition.schema.json',
};

/// Executes the get_schema tool.
///
/// Reads the three schema files from `$dataDir/schema/`.
Future<Map<String, dynamic>> executeGetSchema(
  String dataDir,
  Map<String, dynamic> arguments,
) async {
  final result = <String, dynamic>{};
  for (final entry in _schemaFiles.entries) {
    final file = File('$dataDir/schema/${entry.value}');
    final raw = await file.readAsString();
    result[entry.key] = jsonDecode(raw);
  }
  return result;
}
