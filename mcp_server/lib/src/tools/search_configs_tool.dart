import '../http_client.dart';
import 'tool_definition.dart';

/// Searches SmartPlaylist configs by keyword.
///
/// Calls `GET /api/configs?q={query}` on the sp_server.
const searchConfigsTool = ToolDefinition(
  name: 'search_configs',
  description: 'Search SmartPlaylist configs by keyword',
  inputSchema: {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': 'Search keyword to filter configs',
      },
    },
  },
);

/// Executes the search_configs tool.
Future<Map<String, dynamic>> executeSearchConfigs(
  McpHttpClient client,
  Map<String, dynamic> arguments,
) async {
  final query = arguments['query'] as String?;
  final queryParams = <String, String>{};
  if (query != null && query.isNotEmpty) {
    queryParams['q'] = query;
  }
  return client.get('/api/configs', queryParams);
}
