import '../http_client.dart';
import 'tool_definition.dart';

/// Previews how a config resolves episodes from a feed.
///
/// Calls `POST /api/configs/preview` on the sp_server.
const previewConfigTool = ToolDefinition(
  name: 'preview_config',
  description: 'Preview how a config resolves episodes from a feed',
  inputSchema: {
    'type': 'object',
    'properties': {
      'config': {
        'type': 'object',
        'description': 'The SmartPlaylist config to preview',
      },
      'feedUrl': {
        'type': 'string',
        'description': 'The RSS feed URL to fetch episodes from',
      },
    },
    'required': ['config', 'feedUrl'],
  },
);

/// Executes the preview_config tool.
///
/// Throws [ArgumentError] if the required parameters are missing.
Future<Map<String, dynamic>> executePreviewConfig(
  McpHttpClient client,
  Map<String, dynamic> arguments,
) async {
  final config = arguments['config'];
  if (config is! Map<String, dynamic>) {
    throw ArgumentError('Missing or invalid required parameter: config');
  }
  final feedUrl = arguments['feedUrl'] as String?;
  if (feedUrl == null || feedUrl.isEmpty) {
    throw ArgumentError('Missing required parameter: feedUrl');
  }
  return client.post('/api/configs/preview', {
    'config': config,
    'feedUrl': feedUrl,
  });
}
