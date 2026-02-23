import 'package:sp_mcp_server/src/tools/get_config_tool.dart';
import 'package:sp_server/src/services/local_config_repository.dart';
import 'package:test/test.dart';

import '../../helpers/test_data_dir.dart';

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
    late String dataDir;
    late LocalConfigRepository repo;

    setUp(() async {
      dataDir = await createTestDataDir(
        patternMetas: {
          'test-config': {
            'version': 1,
            'id': 'test-config',
            'feedUrls': ['https://example.com/feed'],
            'playlists': ['main'],
          },
        },
        playlists: {
          'test-config': {
            'main': {
              'id': 'main',
              'displayName': 'Main Episodes',
              'resolverType': 'rss',
            },
          },
        },
      );
      repo = LocalConfigRepository(dataDir: dataDir);
    });

    tearDown(() => cleanupDataDir(dataDir));

    test('throws ArgumentError when id is missing', () async {
      expect(() => executeGetConfig(repo, {}), throwsA(isA<ArgumentError>()));
    });

    test('throws ArgumentError when id is empty', () async {
      expect(
        () => executeGetConfig(repo, {'id': ''}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns assembled config for valid id', () async {
      final result = await executeGetConfig(repo, {'id': 'test-config'});

      expect(result['id'], 'test-config');
      expect(result['playlists'], isList);
      final playlists = result['playlists'] as List;
      expect(playlists.length, 1);
      expect((playlists[0] as Map)['id'], 'main');
    });
  });
}
