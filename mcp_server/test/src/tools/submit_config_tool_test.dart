import 'package:sp_mcp_server/src/tools/submit_config_tool.dart';
import 'package:test/test.dart';

import '../../helpers/fake_http_client.dart';

void main() {
  group('submitConfigTool definition', () {
    test('has correct name', () {
      expect(submitConfigTool.name, 'submit_config');
    });

    test('config and configId are required', () {
      final required =
          submitConfigTool.inputSchema['required'] as List<dynamic>?;
      expect(required, containsAll(['config', 'configId']));
    });
  });

  group('executeSubmitConfig', () {
    late FakeHttpClient client;

    setUp(() {
      client = FakeHttpClient();
    });

    test('throws ArgumentError when config is missing', () async {
      expect(
        () => executeSubmitConfig(client, {'configId': 'test'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when configId is missing', () async {
      expect(
        () => executeSubmitConfig(client, {
          'config': {'id': 'test'},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when configId is empty', () async {
      expect(
        () => executeSubmitConfig(client, {
          'config': {'id': 'test'},
          'configId': '',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('calls POST /api/configs/submit with required fields', () async {
      client.postResponse = {
        'prUrl': 'https://github.com/test/pr/1',
        'branch': 'smartplaylist/test-123',
      };

      final config = {'id': 'test'};
      await executeSubmitConfig(client, {'config': config, 'configId': 'test'});

      expect(client.lastPostPath, '/api/configs/submit');
      expect(client.lastPostBody, {'config': config, 'configId': 'test'});
    });

    test('includes description when provided', () async {
      client.postResponse = {
        'prUrl': 'https://github.com/test/pr/1',
        'branch': 'smartplaylist/test-123',
      };

      final config = {'id': 'test'};
      await executeSubmitConfig(client, {
        'config': config,
        'configId': 'test',
        'description': 'My new config',
      });

      expect(client.lastPostBody, {
        'config': config,
        'configId': 'test',
        'description': 'My new config',
      });
    });
  });
}
