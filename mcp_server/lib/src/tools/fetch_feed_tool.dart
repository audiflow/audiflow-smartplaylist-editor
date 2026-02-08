import '../http_client.dart';
import 'tool_definition.dart';

/// Fetches and parses a podcast RSS feed.
///
/// Calls `GET /api/feeds?url={url}` on the sp_server.
const fetchFeedTool = ToolDefinition(
  name: 'fetch_feed',
  description: 'Fetch and parse a podcast RSS feed',
  inputSchema: {
    'type': 'object',
    'properties': {
      'url': {
        'type': 'string',
        'description': 'The URL of the RSS feed to fetch',
      },
    },
    'required': ['url'],
  },
);

/// Executes the fetch_feed tool.
///
/// Throws [ArgumentError] if the required `url` parameter is missing.
Future<Map<String, dynamic>> executeFetchFeed(
  McpHttpClient client,
  Map<String, dynamic> arguments,
) async {
  final url = arguments['url'] as String?;
  if (url == null || url.isEmpty) {
    throw ArgumentError('Missing required parameter: url');
  }
  return client.get('/api/feeds', {'url': url});
}
