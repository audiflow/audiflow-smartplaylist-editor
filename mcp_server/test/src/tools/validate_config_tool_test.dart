import 'package:sp_mcp_server/src/tools/validate_config_tool.dart';
import 'package:test/test.dart';

import '../../helpers/fake_http_client.dart';

void main() {
  group('validateConfigTool definition', () {
    test('has correct name', () {
      expect(validateConfigTool.name, 'validate_config');
    });

    test('config is required', () {
      final required =
          validateConfigTool.inputSchema['required'] as List<dynamic>?;
      expect(required, contains('config'));
    });
  });

  group('executeValidateConfig', () {
    late FakeHttpClient client;

    setUp(() {
      client = FakeHttpClient();
    });

    test('throws ArgumentError when config is missing', () async {
      expect(
        () => executeValidateConfig(client, {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when config is not a Map', () async {
      expect(
        () => executeValidateConfig(client, {'config': 'string'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('calls POST /api/configs/validate with config', () async {
      client.postResponse = {'valid': true, 'errors': []};

      final config = {'id': 'test', 'playlists': []};
      await executeValidateConfig(client, {'config': config});

      expect(client.lastPostPath, '/api/configs/validate');
      expect(client.lastPostBody, {'config': config});
    });
  });
}
