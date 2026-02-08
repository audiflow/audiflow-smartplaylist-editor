import 'package:sp_mcp_server/src/tools/get_config_tool.dart';
import 'package:test/test.dart';

import '../../helpers/fake_http_client.dart';

void main() {
  group('getConfigTool definition', () {
    test('has correct name', () {
      expect(getConfigTool.name, 'get_config');
    });

    test('id is required', () {
      final required = getConfigTool.inputSchema['required'] as List<dynamic>?;
      expect(required, contains('id'));
    });
  });

  group('executeGetConfig', () {
    late FakeHttpClient client;

    setUp(() {
      client = FakeHttpClient();
    });

    test('throws ArgumentError when id is missing', () async {
      expect(() => executeGetConfig(client, {}), throwsA(isA<ArgumentError>()));
    });

    test('throws ArgumentError when id is empty', () async {
      expect(
        () => executeGetConfig(client, {'id': ''}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('calls GET /api/configs/{id} with valid id', () async {
      client.getResponse = {'id': 'test-config'};

      await executeGetConfig(client, {'id': 'test-config'});

      expect(client.lastGetPath, '/api/configs/test-config');
    });
  });
}
