import 'dart:convert';
import 'dart:io';

import 'http_client.dart';
import 'tools/fetch_feed_tool.dart';
import 'tools/get_config_tool.dart';
import 'tools/get_schema_tool.dart';
import 'tools/preview_config_tool.dart';
import 'tools/search_configs_tool.dart';
import 'tools/submit_config_tool.dart';
import 'tools/tool_definition.dart';
import 'tools/validate_config_tool.dart';

/// JSON-RPC 2.0 error codes.
abstract final class JsonRpcError {
  static const parseError = -32700;
  static const invalidRequest = -32600;
  static const methodNotFound = -32601;
  static const invalidParams = -32602;
  static const internalError = -32603;
}

/// MCP server that exposes SmartPlaylist operations as tools.
///
/// Communicates via JSON-RPC 2.0 over stdin/stdout.
final class SpMcpServer {
  SpMcpServer({required this.httpClient});

  final McpHttpClient httpClient;

  /// All available tool definitions.
  static const _tools = <ToolDefinition>[
    searchConfigsTool,
    getConfigTool,
    getSchemaTool,
    fetchFeedTool,
    validateConfigTool,
    previewConfigTool,
    submitConfigTool,
  ];

  /// Resource URIs and their metadata.
  static const _resources = <Map<String, dynamic>>[
    {
      'uri': 'smartplaylist://schema',
      'name': 'SmartPlaylist JSON Schema',
      'description': 'JSON Schema defining the SmartPlaylist config format',
      'mimeType': 'application/json',
    },
    {
      'uri': 'smartplaylist://configs',
      'name': 'All SmartPlaylist Configs',
      'description': 'List of all available SmartPlaylist configs',
      'mimeType': 'application/json',
    },
  ];

  /// Starts the server loop, reading JSON-RPC messages
  /// from stdin and writing responses to stdout.
  Future<void> run() async {
    final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final response = await _handleMessage(trimmed);
      if (response != null) {
        stdout.writeln(jsonEncode(response));
      }
    }
  }

  /// Processes a single raw JSON-RPC message string.
  ///
  /// Visible for testing. In production, [run] calls this internally
  /// for each line read from stdin.
  Future<Map<String, dynamic>?> handleMessageForTest(String raw) =>
      _handleMessage(raw);

  /// Parses and dispatches a single JSON-RPC message.
  Future<Map<String, dynamic>?> _handleMessage(String raw) async {
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException {
      return _errorResponse(null, JsonRpcError.parseError, 'Parse error');
    }

    if (parsed is! Map<String, dynamic>) {
      return _errorResponse(
        null,
        JsonRpcError.invalidRequest,
        'Invalid request',
      );
    }

    final id = parsed['id'];
    final method = parsed['method'] as String?;
    final params = parsed['params'] as Map<String, dynamic>? ?? {};

    // Notifications (no id) are acknowledged silently.
    if (method == null) {
      return _errorResponse(id, JsonRpcError.invalidRequest, 'Missing method');
    }

    // Handle "notifications/initialized" silently (no response needed).
    if (method == 'notifications/initialized') return null;

    try {
      final result = await _dispatch(method, params);
      return _successResponse(id, result);
    } on _MethodNotFoundError {
      return _errorResponse(
        id,
        JsonRpcError.methodNotFound,
        'Method not found: $method',
      );
    } on ArgumentError catch (e) {
      return _errorResponse(id, JsonRpcError.invalidParams, e.message);
    } on HttpException catch (e) {
      return _errorResponse(id, JsonRpcError.internalError, 'HTTP error: $e');
    } on Exception catch (e) {
      return _errorResponse(
        id,
        JsonRpcError.internalError,
        'Internal error: $e',
      );
    }
  }

  /// Routes a method call to the appropriate handler.
  Future<Map<String, dynamic>> _dispatch(
    String method,
    Map<String, dynamic> params,
  ) async {
    return switch (method) {
      'initialize' => _handleInitialize(params),
      'tools/list' => _handleToolsList(),
      'tools/call' => _handleToolsCall(params),
      'resources/list' => _handleResourcesList(),
      'resources/read' => _handleResourcesRead(params),
      _ => throw _MethodNotFoundError(),
    };
  }

  /// Handles the `initialize` lifecycle method.
  Map<String, dynamic> _handleInitialize(Map<String, dynamic> params) {
    return {
      'protocolVersion': '2024-11-05',
      'capabilities': {
        'tools': <String, dynamic>{},
        'resources': <String, dynamic>{},
      },
      'serverInfo': {'name': 'sp-mcp-server', 'version': '0.1.0'},
    };
  }

  /// Returns all available tool definitions.
  Map<String, dynamic> _handleToolsList() {
    return {'tools': _tools.map((t) => t.toJson()).toList()};
  }

  /// Dispatches a `tools/call` request to the matching tool executor.
  Future<Map<String, dynamic>> _handleToolsCall(
    Map<String, dynamic> params,
  ) async {
    final name = params['name'] as String?;
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};

    if (name == null || name.isEmpty) {
      throw ArgumentError('Missing tool name');
    }

    try {
      final result = await _executeTool(name, arguments);
      return {
        'content': [
          {'type': 'text', 'text': jsonEncode(result)},
        ],
      };
    } on ArgumentError {
      rethrow;
    } on HttpException catch (e) {
      return {
        'content': [
          {
            'type': 'text',
            'text': jsonEncode({'error': e.toString()}),
          },
        ],
        'isError': true,
      };
    } on Exception catch (e) {
      return {
        'content': [
          {
            'type': 'text',
            'text': jsonEncode({'error': 'Tool execution failed: $e'}),
          },
        ],
        'isError': true,
      };
    }
  }

  /// Executes a tool by name with the given arguments.
  Future<Map<String, dynamic>> _executeTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    return switch (name) {
      'search_configs' => executeSearchConfigs(httpClient, arguments),
      'get_config' => executeGetConfig(httpClient, arguments),
      'get_schema' => executeGetSchema(httpClient, arguments),
      'fetch_feed' => executeFetchFeed(httpClient, arguments),
      'validate_config' => executeValidateConfig(httpClient, arguments),
      'preview_config' => executePreviewConfig(httpClient, arguments),
      'submit_config' => executeSubmitConfig(httpClient, arguments),
      _ => throw ArgumentError('Unknown tool: $name'),
    };
  }

  /// Returns all available resource definitions.
  Map<String, dynamic> _handleResourcesList() {
    return {'resources': _resources};
  }

  /// Reads the content of a resource by URI.
  Future<Map<String, dynamic>> _handleResourcesRead(
    Map<String, dynamic> params,
  ) async {
    final uri = params['uri'] as String?;
    if (uri == null || uri.isEmpty) {
      throw ArgumentError('Missing resource URI');
    }

    return switch (uri) {
      'smartplaylist://schema' => _readSchemaResource(),
      'smartplaylist://configs' => _readConfigsResource(),
      _ => throw ArgumentError('Unknown resource: $uri'),
    };
  }

  Future<Map<String, dynamic>> _readSchemaResource() async {
    final raw = await httpClient.getRaw('/api/schema');
    return {
      'contents': [
        {
          'uri': 'smartplaylist://schema',
          'mimeType': 'application/json',
          'text': raw,
        },
      ],
    };
  }

  Future<Map<String, dynamic>> _readConfigsResource() async {
    final result = await httpClient.get('/api/configs');
    return {
      'contents': [
        {
          'uri': 'smartplaylist://configs',
          'mimeType': 'application/json',
          'text': jsonEncode(result),
        },
      ],
    };
  }

  Map<String, dynamic> _successResponse(
    Object? id,
    Map<String, dynamic> result,
  ) {
    return {'jsonrpc': '2.0', 'id': id, 'result': result};
  }

  Map<String, dynamic> _errorResponse(Object? id, int code, String message) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message},
    };
  }
}

/// Sentinel exception for unknown methods.
final class _MethodNotFoundError implements Exception {}
