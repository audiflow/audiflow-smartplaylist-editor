import 'dart:convert';

import 'package:test/test.dart';

import 'package:sp_server/src/services/config_repository.dart';

const _sampleIndex = '''
{
  "version": 1,
  "patterns": [
    {
      "id": "config-a",
      "podcastGuid": "guid-a",
      "playlists": [
        {
          "id": "seasons",
          "displayName": "Seasons",
          "resolverType": "rss"
        }
      ]
    },
    {
      "id": "config-b",
      "feedUrlPatterns": ["https://example\\\\.com/.*"],
      "playlists": [
        {
          "id": "by-year",
          "displayName": "By Year",
          "resolverType": "year"
        },
        {
          "id": "cats",
          "displayName": "Categories",
          "resolverType": "category"
        }
      ]
    }
  ]
}
''';

void main() {
  group('ConfigRepository', () {
    late ConfigRepository repository;
    var fetchCount = 0;

    setUp(() {
      fetchCount = 0;
      repository = ConfigRepository(
        httpGet: (_) async {
          fetchCount++;
          return _sampleIndex;
        },
        configRepoUrl: 'https://example.com/index.json',
      );
    });

    group('listConfigs', () {
      test('returns config summaries', () async {
        final configs = await repository.listConfigs();

        expect(configs.length, equals(2));
        expect(configs[0].id, equals('config-a'));
        expect(configs[0].podcastGuid, equals('guid-a'));
        expect(configs[0].playlistCount, equals(1));
        expect(configs[1].id, equals('config-b'));
        expect(configs[1].playlistCount, equals(2));
      });

      test('returns feedUrlPatterns', () async {
        final configs = await repository.listConfigs();
        final second = configs[1];

        expect(second.feedUrlPatterns, isNotNull);
        expect(second.feedUrlPatterns!.length, equals(1));
      });

      test('caches results', () async {
        await repository.listConfigs();
        await repository.listConfigs();

        expect(fetchCount, equals(1));
      });

      test('respects cache TTL', () async {
        final shortTtl = ConfigRepository(
          httpGet: (_) async {
            fetchCount++;
            return _sampleIndex;
          },
          configRepoUrl: 'https://example.com/index.json',
          cacheTtl: Duration.zero,
        );

        fetchCount = 0;
        await shortTtl.listConfigs();
        await shortTtl.listConfigs();

        expect(fetchCount, equals(2));
      });
    });

    group('getConfig', () {
      test('returns config by ID', () async {
        final config = await repository.getConfig('config-a');

        expect(config, isNotNull);
        expect(config!['id'], equals('config-a'));
        expect(config['podcastGuid'], equals('guid-a'));
      });

      test('returns null for unknown ID', () async {
        final config = await repository.getConfig('nonexistent');

        expect(config, isNull);
      });

      test('includes playlists in config', () async {
        final config = await repository.getConfig('config-b');

        expect(config, isNotNull);
        final playlists = config!['playlists'] as List<dynamic>;
        expect(playlists.length, equals(2));
      });
    });

    group('clearCache', () {
      test('forces re-fetch after clear', () async {
        await repository.listConfigs();
        expect(fetchCount, equals(1));

        repository.clearCache();
        await repository.listConfigs();
        expect(fetchCount, equals(2));
      });
    });

    group('cacheSize', () {
      test('tracks cached entries', () async {
        expect(repository.cacheSize, equals(0));
        await repository.listConfigs();
        expect(repository.cacheSize, equals(1));
      });
    });

    group('error handling', () {
      test('throws on HTTP failure', () async {
        final failingRepo = ConfigRepository(
          httpGet: (_) async {
            throw Exception('Network error');
          },
          configRepoUrl: 'https://example.com/fail',
        );

        expect(() => failingRepo.listConfigs(), throwsException);
      });

      test('throws on invalid JSON', () async {
        final badRepo = ConfigRepository(
          httpGet: (_) async => 'not json',
          configRepoUrl: 'https://example.com/bad',
        );

        expect(() => badRepo.listConfigs(), throwsA(isA<FormatException>()));
      });

      test('throws when root is not an object', () async {
        final badRepo = ConfigRepository(
          httpGet: (_) async => jsonEncode([1, 2, 3]),
          configRepoUrl: 'https://example.com/bad',
        );

        expect(() => badRepo.listConfigs(), throwsA(isA<FormatException>()));
      });
    });

    group('ConfigSummary.toJson', () {
      test('serializes all fields', () {
        const summary = ConfigSummary(
          id: 'test-id',
          podcastGuid: 'guid',
          feedUrlPatterns: ['pattern'],
          playlistCount: 3,
        );

        final json = summary.toJson();

        expect(json['id'], equals('test-id'));
        expect(json['podcastGuid'], equals('guid'));
        expect(json['feedUrlPatterns'], equals(['pattern']));
        expect(json['playlistCount'], equals(3));
      });

      test('omits null fields', () {
        const summary = ConfigSummary(id: 'test', playlistCount: 0);

        final json = summary.toJson();

        expect(json.containsKey('podcastGuid'), isFalse);
        expect(json.containsKey('feedUrlPatterns'), isFalse);
      });
    });
  });
}
