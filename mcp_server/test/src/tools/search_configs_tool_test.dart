import 'package:sp_mcp_server/src/tools/search_configs_tool.dart';
import 'package:sp_server/src/services/local_config_repository.dart';
import 'package:test/test.dart';

import '../../helpers/test_data_dir.dart';

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
    late String dataDir;
    late LocalConfigRepository repo;

    setUp(() async {
      dataDir = await createTestDataDir(
        patterns: [
          {
            'id': 'tech-podcast',
            'version': 1,
            'displayName': 'Tech Talk',
            'feedUrlHint': 'https://example.com/tech',
            'playlistCount': 1,
          },
          {
            'id': 'comedy-show',
            'version': 1,
            'displayName': 'Laugh Hour',
            'feedUrlHint': 'https://example.com/comedy',
            'playlistCount': 2,
          },
        ],
      );
      repo = LocalConfigRepository(dataDir: dataDir);
    });

    tearDown(() => cleanupDataDir(dataDir));

    test('returns all patterns when query is absent', () async {
      final result = await executeSearchConfigs(repo, {});
      final configs = result['configs'] as List;
      expect(configs.length, 2);
    });

    test('filters by id keyword', () async {
      final result = await executeSearchConfigs(repo, {'query': 'tech'});
      final configs = result['configs'] as List;
      expect(configs.length, 1);
      expect((configs[0] as Map)['id'], 'tech-podcast');
    });

    test('filters by displayName keyword', () async {
      final result = await executeSearchConfigs(repo, {'query': 'laugh'});
      final configs = result['configs'] as List;
      expect(configs.length, 1);
      expect((configs[0] as Map)['id'], 'comedy-show');
    });

    test('filters by feedUrlHint keyword', () async {
      final result = await executeSearchConfigs(repo, {'query': 'comedy'});
      final configs = result['configs'] as List;
      expect(configs.length, 1);
      expect((configs[0] as Map)['id'], 'comedy-show');
    });

    test('search is case-insensitive', () async {
      final result = await executeSearchConfigs(repo, {'query': 'TECH'});
      final configs = result['configs'] as List;
      expect(configs.length, 1);
    });

    test('returns empty list when no match', () async {
      final result = await executeSearchConfigs(repo, {'query': 'nope'});
      final configs = result['configs'] as List;
      expect(configs, isEmpty);
    });

    test('returns all patterns when query is empty string', () async {
      final result = await executeSearchConfigs(repo, {'query': ''});
      final configs = result['configs'] as List;
      expect(configs.length, 2);
    });
  });
}
