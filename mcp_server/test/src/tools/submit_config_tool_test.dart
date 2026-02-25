import 'dart:convert';
import 'dart:io';

import 'package:sp_mcp_server/src/tools/submit_config_tool.dart';
import 'package:sp_server/src/services/local_config_repository.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

import '../../helpers/test_data_dir.dart';

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

    test('description says save to disk', () {
      expect(submitConfigTool.description, 'Save a config to disk');
    });
  });

  group('executeSubmitConfig', () {
    late String dataDir;
    late LocalConfigRepository repo;
    late SmartPlaylistValidator validator;

    setUp(() async {
      dataDir = await createTestDataDir(
        patterns: [
          {
            'id': 'test-pattern',
            'version': 3,
            'displayName': 'Test Pattern',
            'feedUrlHint': 'https://example.com/feed',
            'playlistCount': 1,
          },
        ],
        patternMetas: {
          'test-pattern': {
            'version': 2,
            'id': 'test-pattern',
            'feedUrls': ['https://example.com/feed'],
            'playlists': ['main'],
          },
        },
        playlists: {
          'test-pattern': {
            'main': {
              'id': 'main',
              'displayName': 'Main',
              'resolverType': 'rss',
            },
          },
        },
      );
      repo = LocalConfigRepository(dataDir: dataDir);
      validator = SmartPlaylistValidator();
    });

    tearDown(() => cleanupDataDir(dataDir));

    test('throws ArgumentError when config is missing', () async {
      expect(
        () => executeSubmitConfig(repo, validator, {'configId': 'test'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when configId is missing', () async {
      expect(
        () => executeSubmitConfig(repo, validator, {
          'config': {'id': 'test', 'playlists': []},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when configId is empty', () async {
      expect(
        () => executeSubmitConfig(repo, validator, {
          'config': {'id': 'test', 'playlists': []},
          'configId': '',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns errors for invalid config', () async {
      final result = await executeSubmitConfig(repo, validator, {
        'config': <String, dynamic>{},
        'configId': 'test-pattern',
      });

      expect(result['success'], isFalse);
      expect(result['errors'], isNotEmpty);
    });

    test('saves valid config to disk', () async {
      final config = {
        'id': 'test-pattern',
        'feedUrls': ['https://example.com/feed'],
        'playlists': [
          {'id': 'main', 'displayName': 'Main Episodes', 'resolverType': 'rss'},
        ],
      };

      final result = await executeSubmitConfig(repo, validator, {
        'config': config,
        'configId': 'test-pattern',
      });

      expect(result['success'], isTrue);
      expect(result['patternId'], 'test-pattern');

      // Verify file was written
      final playlistFile = File(
        '$dataDir/patterns/test-pattern/playlists/main.json',
      );
      expect(await playlistFile.exists(), isTrue);
      final written =
          jsonDecode(await playlistFile.readAsString()) as Map<String, dynamic>;
      expect(written['id'], 'main');
      expect(written['displayName'], 'Main Episodes');
    });

    test('updates pattern meta with new playlist IDs and feedUrls', () async {
      final config = {
        'id': 'test-pattern',
        'feedUrls': ['https://example.com/new-feed'],
        'playlists': [
          {'id': 'main', 'displayName': 'Main', 'resolverType': 'rss'},
          {'id': 'bonus', 'displayName': 'Bonus', 'resolverType': 'year'},
        ],
      };

      await executeSubmitConfig(repo, validator, {
        'config': config,
        'configId': 'test-pattern',
      });

      final metaFile = File('$dataDir/patterns/test-pattern/meta.json');
      final meta =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      expect(meta['feedUrls'], equals(['https://example.com/new-feed']));
      expect(meta['playlists'], equals(['main', 'bonus']));
    });

    test('preserves pattern meta version', () async {
      final config = {
        'id': 'test-pattern',
        'feedUrls': ['https://example.com/feed'],
        'playlists': [
          {'id': 'main', 'displayName': 'Main', 'resolverType': 'rss'},
        ],
      };

      await executeSubmitConfig(repo, validator, {
        'config': config,
        'configId': 'test-pattern',
      });

      final metaFile = File('$dataDir/patterns/test-pattern/meta.json');
      final meta =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      expect(meta['version'], equals(2));
    });

    test('updates root meta playlistCount', () async {
      final config = {
        'id': 'test-pattern',
        'feedUrls': ['https://example.com/feed'],
        'playlists': [
          {'id': 'main', 'displayName': 'Main', 'resolverType': 'rss'},
          {'id': 'bonus', 'displayName': 'Bonus', 'resolverType': 'year'},
        ],
      };

      await executeSubmitConfig(repo, validator, {
        'config': config,
        'configId': 'test-pattern',
      });

      final rootFile = File('$dataDir/patterns/meta.json');
      final root =
          jsonDecode(await rootFile.readAsString()) as Map<String, dynamic>;
      final patterns = root['patterns'] as List;
      final entry = patterns.first as Map<String, dynamic>;
      expect(entry['playlistCount'], equals(2));
    });

    test('preserves root meta version and pattern summary version', () async {
      final config = {
        'id': 'test-pattern',
        'feedUrls': ['https://example.com/feed'],
        'playlists': [
          {'id': 'main', 'displayName': 'Main', 'resolverType': 'rss'},
        ],
      };

      await executeSubmitConfig(repo, validator, {
        'config': config,
        'configId': 'test-pattern',
      });

      final rootFile = File('$dataDir/patterns/meta.json');
      final root =
          jsonDecode(await rootFile.readAsString()) as Map<String, dynamic>;
      expect(root['version'], equals(1));
      final patterns = root['patterns'] as List;
      final entry = patterns.first as Map<String, dynamic>;
      expect(entry['version'], equals(3));
    });
  });
}
