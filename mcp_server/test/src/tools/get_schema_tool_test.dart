import 'package:sp_mcp_server/src/tools/get_schema_tool.dart';
import 'package:test/test.dart';

import '../../helpers/fake_http_client.dart';

void main() {
  group('getSchemaTool definition', () {
    test('has correct name', () {
      expect(getSchemaTool.name, 'get_schema');
    });

    test('has no required parameters', () {
      final required = getSchemaTool.inputSchema['required'] as List<dynamic>?;
      expect(required, isNull);
    });
  });

  group('executeGetSchema', () {
    late FakeHttpClient client;

    setUp(() {
      client = FakeHttpClient();
    });

    test('calls getRaw /api/schema', () async {
      client.getRawResponse = '{"type": "object"}';

      final result = await executeGetSchema(client, {});

      expect(client.lastGetRawPath, '/api/schema');
      expect(result, {'type': 'object'});
    });
  });
}
