import 'dart:convert';
import 'dart:io';

import 'package:sp_server/src/services/local_config_repository.dart';
import 'package:test/test.dart';

/// Sample root meta.json content.
Map<String, dynamic> _rootMetaJson() => {
  'version': 1,
  'patterns': [
    {
      'id': 'podcast-a',
      'version': 1,
      'displayName': 'Podcast A',
      'feedUrlHint': 'https://example.com/a/feed.xml',
      'playlistCount': 2,
    },
    {
      'id': 'podcast-b',
      'version': 1,
      'displayName': 'Podcast B',
      'feedUrlHint': 'https://example.com/b/feed.xml',
      'playlistCount': 1,
    },
  ],
};

/// Sample pattern meta.json for podcast-a.
Map<String, dynamic> _patternMetaJson() => {
  'version': 1,
  'id': 'podcast-a',
  'podcastGuid': 'guid-a',
  'feedUrls': ['https://example.com/a/feed.xml'],
  'playlists': ['seasons', 'by-year'],
};

/// Sample playlist JSON for seasons.
Map<String, dynamic> _playlistSeasonsJson() => {
  'id': 'seasons',
  'displayName': 'Seasons',
  'resolverType': 'rss',
};

/// Sample playlist JSON for by-year.
Map<String, dynamic> _playlistByYearJson() => {
  'id': 'by-year',
  'displayName': 'By Year',
  'resolverType': 'year',
};

/// Pretty-prints JSON with 2-space indent and trailing newline.
String _prettyJson(Map<String, dynamic> json) {
  return '${const JsonEncoder.withIndent('  ').convert(json)}\n';
}

/// Creates a temporary directory with the standard split config
/// file structure and returns the data dir path.
Future<Directory> _createTestDataDir({
  Map<String, dynamic>? rootMeta,
  Map<String, dynamic>? patternMeta,
  Map<String, dynamic>? playlistSeasons,
  Map<String, dynamic>? playlistByYear,
}) async {
  final tempDir = await Directory.systemTemp.createTemp('local_config_test_');
  final patternsDir = Directory('${tempDir.path}/patterns');
  await patternsDir.create();

  if (rootMeta != null) {
    await File(
      '${patternsDir.path}/meta.json',
    ).writeAsString(_prettyJson(rootMeta));
  }

  if (patternMeta != null) {
    final patternDir = Directory('${patternsDir.path}/podcast-a');
    await patternDir.create();
    await File(
      '${patternDir.path}/meta.json',
    ).writeAsString(_prettyJson(patternMeta));

    final playlistsDir = Directory('${patternDir.path}/playlists');
    await playlistsDir.create();

    if (playlistSeasons != null) {
      await File(
        '${playlistsDir.path}/seasons.json',
      ).writeAsString(_prettyJson(playlistSeasons));
    }
    if (playlistByYear != null) {
      await File(
        '${playlistsDir.path}/by-year.json',
      ).writeAsString(_prettyJson(playlistByYear));
    }
  }

  return tempDir;
}

void main() {
  late Directory tempDir;

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalConfigRepository', () {
    group('listPatterns', () {
      test('reads pattern summaries from root meta.json', () async {
        tempDir = await _createTestDataDir(rootMeta: _rootMetaJson());
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        final patterns = await repo.listPatterns();

        expect(patterns.length, equals(2));
        expect(patterns[0].id, equals('podcast-a'));
        expect(patterns[0].displayName, equals('Podcast A'));
        expect(patterns[0].playlistCount, equals(2));
        expect(patterns[1].id, equals('podcast-b'));
        expect(patterns[1].playlistCount, equals(1));
      });

      test('throws FileSystemException when meta.json is missing', () async {
        tempDir = await Directory.systemTemp.createTemp('local_config_test_');
        await Directory('${tempDir.path}/patterns').create();
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        expect(() => repo.listPatterns(), throwsA(isA<FileSystemException>()));
      });
    });

    group('getPatternMeta', () {
      test('reads pattern meta.json', () async {
        tempDir = await _createTestDataDir(patternMeta: _patternMetaJson());
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        final meta = await repo.getPatternMeta('podcast-a');

        expect(meta.id, equals('podcast-a'));
        expect(meta.podcastGuid, equals('guid-a'));
        expect(meta.feedUrls, hasLength(1));
        expect(meta.playlists, equals(['seasons', 'by-year']));
      });

      test('throws FileSystemException for missing pattern', () async {
        tempDir = await _createTestDataDir(rootMeta: _rootMetaJson());
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        expect(
          () => repo.getPatternMeta('nonexistent'),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('getPlaylist', () {
      test('reads playlist definition', () async {
        tempDir = await _createTestDataDir(
          patternMeta: _patternMetaJson(),
          playlistSeasons: _playlistSeasonsJson(),
        );
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        final playlist = await repo.getPlaylist('podcast-a', 'seasons');

        expect(playlist.id, equals('seasons'));
        expect(playlist.displayName, equals('Seasons'));
        expect(playlist.resolverType, equals('rss'));
      });

      test('throws FileSystemException for missing playlist', () async {
        tempDir = await _createTestDataDir(patternMeta: _patternMetaJson());
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        expect(
          () => repo.getPlaylist('podcast-a', 'nonexistent'),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('assembleConfig', () {
      test('combines meta and all playlists', () async {
        tempDir = await _createTestDataDir(
          patternMeta: _patternMetaJson(),
          playlistSeasons: _playlistSeasonsJson(),
          playlistByYear: _playlistByYearJson(),
        );
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        final config = await repo.assembleConfig('podcast-a');

        expect(config.id, equals('podcast-a'));
        expect(config.podcastGuid, equals('guid-a'));
        expect(config.playlists.length, equals(2));
        expect(config.playlists[0].id, equals('seasons'));
        expect(config.playlists[1].id, equals('by-year'));
      });

      test('preserves playlist order from meta', () async {
        final reversedMeta = {
          'version': 1,
          'id': 'podcast-a',
          'feedUrls': ['https://example.com/a/feed.xml'],
          'playlists': ['by-year', 'seasons'],
        };
        tempDir = await _createTestDataDir(
          patternMeta: reversedMeta,
          playlistSeasons: _playlistSeasonsJson(),
          playlistByYear: _playlistByYearJson(),
        );
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        final config = await repo.assembleConfig('podcast-a');

        expect(config.playlists[0].id, equals('by-year'));
        expect(config.playlists[1].id, equals('seasons'));
      });
    });

    group('savePlaylist', () {
      test('writes JSON to disk with pretty-print', () async {
        tempDir = await _createTestDataDir(
          patternMeta: _patternMetaJson(),
          playlistSeasons: _playlistSeasonsJson(),
        );
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        final updatedJson = {
          'id': 'seasons',
          'displayName': 'Updated Seasons',
          'resolverType': 'rss',
        };
        await repo.savePlaylist('podcast-a', 'seasons', updatedJson);

        final file = File(
          '${tempDir.path}/patterns/podcast-a/playlists/seasons.json',
        );
        final content = await file.readAsString();
        expect(content, equals(_prettyJson(updatedJson)));
      });

      test('creates file via atomic write', () async {
        tempDir = await _createTestDataDir(patternMeta: _patternMetaJson());
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        // Create playlists dir (it exists from _createTestDataDir
        // if patternMeta is set)
        final newPlaylist = {
          'id': 'new-pl',
          'displayName': 'New Playlist',
          'resolverType': 'year',
        };
        await repo.savePlaylist('podcast-a', 'new-pl', newPlaylist);

        final file = File(
          '${tempDir.path}/patterns/podcast-a/playlists/new-pl.json',
        );
        expect(await file.exists(), isTrue);
        final content = await file.readAsString();
        expect(content, equals(_prettyJson(newPlaylist)));
      });
    });

    group('savePatternMeta', () {
      test('writes pattern meta to disk', () async {
        tempDir = await _createTestDataDir(patternMeta: _patternMetaJson());
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        final updatedMeta = {
          'version': 1,
          'id': 'podcast-a',
          'feedUrls': ['https://example.com/a/new-feed.xml'],
          'playlists': ['seasons'],
        };
        await repo.savePatternMeta('podcast-a', updatedMeta);

        final file = File('${tempDir.path}/patterns/podcast-a/meta.json');
        final content = await file.readAsString();
        expect(content, equals(_prettyJson(updatedMeta)));
      });
    });

    group('createPattern', () {
      test('creates directory structure with meta', () async {
        tempDir = await _createTestDataDir(rootMeta: _rootMetaJson());
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        final metaJson = {
          'version': 1,
          'id': 'new-pattern',
          'feedUrls': ['https://example.com/new/feed.xml'],
          'playlists': <String>[],
        };
        await repo.createPattern('new-pattern', metaJson);

        final patternDir = Directory('${tempDir.path}/patterns/new-pattern');
        expect(await patternDir.exists(), isTrue);

        final playlistsDir = Directory(
          '${tempDir.path}/patterns/new-pattern/playlists',
        );
        expect(await playlistsDir.exists(), isTrue);

        final metaFile = File('${tempDir.path}/patterns/new-pattern/meta.json');
        final content = await metaFile.readAsString();
        expect(content, equals(_prettyJson(metaJson)));
      });
    });

    group('deletePlaylist', () {
      test('removes playlist file', () async {
        tempDir = await _createTestDataDir(
          patternMeta: _patternMetaJson(),
          playlistSeasons: _playlistSeasonsJson(),
          playlistByYear: _playlistByYearJson(),
        );
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        await repo.deletePlaylist('podcast-a', 'seasons');

        final file = File(
          '${tempDir.path}/patterns/podcast-a/playlists/seasons.json',
        );
        expect(await file.exists(), isFalse);

        // Other playlist should still exist
        final otherFile = File(
          '${tempDir.path}/patterns/podcast-a/playlists/by-year.json',
        );
        expect(await otherFile.exists(), isTrue);
      });

      test('throws FileSystemException for missing file', () async {
        tempDir = await _createTestDataDir(patternMeta: _patternMetaJson());
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        expect(
          () => repo.deletePlaylist('podcast-a', 'nonexistent'),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('deletePattern', () {
      test('removes entire pattern directory', () async {
        tempDir = await _createTestDataDir(
          patternMeta: _patternMetaJson(),
          playlistSeasons: _playlistSeasonsJson(),
          playlistByYear: _playlistByYearJson(),
        );
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        await repo.deletePattern('podcast-a');

        final patternDir = Directory('${tempDir.path}/patterns/podcast-a');
        expect(await patternDir.exists(), isFalse);
      });

      test('throws FileSystemException for missing pattern', () async {
        tempDir = await _createTestDataDir(rootMeta: _rootMetaJson());
        final repo = LocalConfigRepository(dataDir: tempDir.path);

        expect(
          () => repo.deletePattern('nonexistent'),
          throwsA(isA<FileSystemException>()),
        );
      });
    });
  });
}
