import 'package:sp_mcp_server/src/tools/search_configs_tool.dart';
import 'package:test/test.dart';

import '../../helpers/fake_http_client.dart';

void main() {
  group('searchConfigsTool definition', () {
    test('has correct name', () {
      expect(searchConfigsTool.name, 'search_configs');
    });

    test('query is optional', () {
      final required =
          searchConfigsTool.inputSchema['required'] as List<dynamic>?;
      expect(required, isNull);
    });
  });

  group('executeSearchConfigs', () {
    late FakeHttpClient client;

    setUp(() {
      client = FakeHttpClient();
    });

    test('calls GET /api/configs without query when query is absent', () async {
      client.getResponse = {'configs': []};

      await executeSearchConfigs(client, {});

      expect(client.lastGetPath, '/api/configs');
      expect(client.lastGetQueryParams, isEmpty);
    });

    test('calls GET /api/configs with query parameter', () async {
      client.getResponse = {'configs': []};

      await executeSearchConfigs(client, {'query': 'tech'});

      expect(client.lastGetPath, '/api/configs');
      expect(client.lastGetQueryParams, {'q': 'tech'});
    });

    test('ignores empty query string', () async {
      client.getResponse = {'configs': []};

      await executeSearchConfigs(client, {'query': ''});

      expect(client.lastGetQueryParams, isEmpty);
    });
  });
}
