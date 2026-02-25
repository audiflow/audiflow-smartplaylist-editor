import 'dart:convert';

import 'package:sp_mcp_server/src/mcp_server.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

import '../helpers/test_data_dir.dart';

void main() {
  late String dataDir;
  late SpMcpServer server;

  setUp(() async {
    dataDir = await createTestDataDir(
      patterns: [
        {
          'id': 'test-podcast',
          'version': 1,
          'displayName': 'Test Podcast',
          'feedUrlHint': 'https://example.com/feed',
          'playlistCount': 1,
        },
      ],
      patternMetas: {
        'test-podcast': {
          'version': 1,
          'id': 'test-podcast',
          'feedUrls': ['https://example.com/feed'],
          'playlists': ['main'],
        },
      },
      playlists: {
        'test-podcast': {
          'main': {
            'id': 'main',
            'displayName': 'Main Episodes',
            'resolverType': 'rss',
          },
        },
      },
      schema: {'type': 'object', 'properties': {}},
    );
    server = SpMcpServer(dataDir: dataDir);
  });

  tearDown(() => cleanupDataDir(dataDir));

  /// Sends a JSON-RPC request through the server's message handler
  /// and returns the parsed response.
  Future<Map<String, dynamic>?> sendRequest({
    required Object? id,
    required String method,
    Map<String, dynamic>? params,
  }) async {
    final request = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    };
    return server.handleMessageForTest(jsonEncode(request));
  }

  group('initialize', () {
    test('returns protocol version and capabilities', () async {
      final response = await sendRequest(id: 1, method: 'initialize');

      expect(response, isNotNull);
      expect(response!['jsonrpc'], '2.0');
      expect(response['id'], 1);

      final result = response['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], '2024-11-05');
      expect(result['serverInfo']['name'], 'sp-mcp-server');
      expect(result['serverInfo']['version'], '0.1.0');
      expect(result['capabilities']['tools'], isA<Map>());
      expect(result['capabilities']['resources'], isA<Map>());
    });
  });

  group('tools/list', () {
    test('returns all 8 tools', () async {
      final response = await sendRequest(id: 2, method: 'tools/list');

      expect(response, isNotNull);
      final tools = response!['result']['tools'] as List;
      expect(tools.length, 8);

      final toolNames = tools.map((t) => (t as Map)['name']).toSet();
      expect(
        toolNames,
        containsAll([
          'search_configs',
          'get_config',
          'get_schema',
          'fetch_feed',
          'validate_config',
          'preview_config',
          'preview_group',
          'submit_config',
        ]),
      );
    });

    test('each tool has name, description, and inputSchema', () async {
      final response = await sendRequest(id: 3, method: 'tools/list');
      final tools = response!['result']['tools'] as List;

      for (final tool in tools) {
        final t = tool as Map<String, dynamic>;
        expect(t.containsKey('name'), isTrue);
        expect(t.containsKey('description'), isTrue);
        expect(t.containsKey('inputSchema'), isTrue);
      }
    });
  });

  group('tools/call', () {
    test('executes search_configs successfully', () async {
      final response = await sendRequest(
        id: 4,
        method: 'tools/call',
        params: {'name': 'search_configs', 'arguments': {}},
      );

      expect(response, isNotNull);
      final result = response!['result'] as Map<String, dynamic>;
      final content = result['content'] as List;
      expect(content.length, 1);
      expect(content[0]['type'], 'text');

      final text = jsonDecode(content[0]['text'] as String);
      expect(text['configs'], isList);
      final configs = text['configs'] as List;
      expect(configs.length, 1);
      expect((configs[0] as Map)['id'], 'test-podcast');
    });

    test('returns error for unknown tool', () async {
      final response = await sendRequest(
        id: 5,
        method: 'tools/call',
        params: {'name': 'nonexistent', 'arguments': {}},
      );

      expect(response, isNotNull);
      // ArgumentError for unknown tool becomes invalidParams.
      expect(response!['error'], isNotNull);
      expect(response['error']['code'], JsonRpcError.invalidParams);
    });

    test('returns error for missing tool name', () async {
      final response = await sendRequest(
        id: 6,
        method: 'tools/call',
        params: {'arguments': {}},
      );

      expect(response, isNotNull);
      expect(response!['error'], isNotNull);
      expect(response['error']['code'], JsonRpcError.invalidParams);
    });

    test('returns isError for file system failures', () async {
      // Create a server pointing at a nonexistent data directory
      // so that file operations fail.
      final badServer = SpMcpServer(
        dataDir: '/nonexistent/path',
        feedService: DiskFeedCacheService(
          cacheDir: '/nonexistent/cache',
          httpGet: (url) async => '',
        ),
      );

      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 7,
        'method': 'tools/call',
        'params': {'name': 'search_configs', 'arguments': {}},
      });

      final response = await badServer.handleMessageForTest(request);
      expect(response, isNotNull);
      final result = response!['result'] as Map<String, dynamic>;
      expect(result['isError'], isTrue);
    });
  });

  group('resources/list', () {
    test('returns schema and configs resources', () async {
      final response = await sendRequest(id: 8, method: 'resources/list');

      expect(response, isNotNull);
      final resources = response!['result']['resources'] as List;
      expect(resources.length, 2);

      final uris = resources.map((r) => (r as Map)['uri']).toSet();
      expect(
        uris,
        containsAll(['smartplaylist://schema', 'smartplaylist://configs']),
      );
    });
  });

  group('resources/read', () {
    test('reads schema resource', () async {
      final response = await sendRequest(
        id: 9,
        method: 'resources/read',
        params: {'uri': 'smartplaylist://schema'},
      );

      expect(response, isNotNull);
      final contents = response!['result']['contents'] as List;
      expect(contents.length, 1);
      expect(contents[0]['uri'], 'smartplaylist://schema');
      expect(contents[0]['mimeType'], 'application/json');
    });

    test('reads configs resource', () async {
      final response = await sendRequest(
        id: 10,
        method: 'resources/read',
        params: {'uri': 'smartplaylist://configs'},
      );

      expect(response, isNotNull);
      final contents = response!['result']['contents'] as List;
      expect(contents.length, 1);
      expect(contents[0]['uri'], 'smartplaylist://configs');
    });

    test('returns error for unknown resource', () async {
      final response = await sendRequest(
        id: 11,
        method: 'resources/read',
        params: {'uri': 'smartplaylist://unknown'},
      );

      expect(response, isNotNull);
      expect(response!['error'], isNotNull);
    });
  });

  group('error handling', () {
    test('returns parse error for invalid JSON', () async {
      final response = await server.handleMessageForTest('not json');

      expect(response, isNotNull);
      expect(response!['error']['code'], JsonRpcError.parseError);
    });

    test('returns invalid request for non-object', () async {
      final response = await server.handleMessageForTest('"string"');

      expect(response, isNotNull);
      expect(response!['error']['code'], JsonRpcError.invalidRequest);
    });

    test('returns method not found for unknown method', () async {
      final response = await sendRequest(id: 12, method: 'unknown/method');

      expect(response, isNotNull);
      expect(response!['error']['code'], JsonRpcError.methodNotFound);
    });

    test('returns null for notifications/initialized', () async {
      final request = jsonEncode({
        'jsonrpc': '2.0',
        'id': 13,
        'method': 'notifications/initialized',
      });
      final response = await server.handleMessageForTest(request);
      expect(response, isNull);
    });
  });
}
