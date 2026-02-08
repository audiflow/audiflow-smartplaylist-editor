import 'dart:io';

import 'package:sp_mcp_server/src/http_client.dart';
import 'package:sp_mcp_server/src/mcp_server.dart';

/// Entry point for the SmartPlaylist MCP server.
///
/// Reads configuration from environment variables:
/// - `SP_API_URL`: Base URL of the sp_server (default: http://localhost:8080)
/// - `SP_API_KEY`: Optional API key for authentication
Future<void> main() async {
  final baseUrl = Platform.environment['SP_API_URL'] ?? 'http://localhost:8080';
  final apiKey = Platform.environment['SP_API_KEY'];

  final httpClient = McpHttpClientImpl(baseUrl: baseUrl, apiKey: apiKey);

  final server = SpMcpServer(httpClient: httpClient);
  await server.run();
}
