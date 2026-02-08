import 'package:sp_mcp_server/src/tools/preview_config_tool.dart';
import 'package:test/test.dart';

import '../../helpers/fake_http_client.dart';

void main() {
  group('previewConfigTool definition', () {
    test('has correct name', () {
      expect(previewConfigTool.name, 'preview_config');
    });

    test('config and feedUrl are required', () {
      final required =
          previewConfigTool.inputSchema['required'] as List<dynamic>?;
      expect(required, containsAll(['config', 'feedUrl']));
    });
  });

  group('executePreviewConfig', () {
    late FakeHttpClient client;

    setUp(() {
      client = FakeHttpClient();
    });

    test('throws ArgumentError when config is missing', () async {
      expect(
        () => executePreviewConfig(client, {
          'feedUrl': 'https://example.com/feed.xml',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when feedUrl is missing', () async {
      expect(
        () => executePreviewConfig(client, {
          'config': {'id': 'test'},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when feedUrl is empty', () async {
      expect(
        () => executePreviewConfig(client, {
          'config': {'id': 'test'},
          'feedUrl': '',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('calls POST /api/configs/preview with config and feedUrl', () async {
      client.postResponse = {'playlists': [], 'ungroupedEpisodeIds': []};

      final config = {'id': 'test'};
      await executePreviewConfig(client, {
        'config': config,
        'feedUrl': 'https://example.com/feed.xml',
      });

      expect(client.lastPostPath, '/api/configs/preview');
      expect(client.lastPostBody, {
        'config': config,
        'feedUrl': 'https://example.com/feed.xml',
      });
    });
  });
}
