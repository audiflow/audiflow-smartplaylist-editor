import 'dart:convert';
import 'dart:io';

import 'package:sp_cli/sp_cli.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sp_cli_validate_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('ValidationError', () {
    test('stores filePath and message', () {
      const error = ValidationError(
        filePath: 'meta.json',
        message: 'file not found',
      );
      expect(error.filePath, 'meta.json');
      expect(error.message, 'file not found');
    });
  });

  group('validatePatterns', () {
    /// Writes a minimal valid config structure to [dir].
    ///
    /// Returns the root directory path.
    void writeValidConfig(Directory dir, {String patternId = 'test_pattern'}) {
      final patternsDir = Directory('${dir.path}/patterns');
      patternsDir.createSync(recursive: true);

      // Root meta.json
      final rootMeta = {
        'version': 2,
        'patterns': [
          {
            'id': patternId,
            'version': 1,
            'displayName': 'Test Pattern',
            'feedUrlHint': 'https://example.com/feed',
            'playlistCount': 1,
          },
        ],
      };
      File(
        '${patternsDir.path}/meta.json',
      ).writeAsStringSync(jsonEncode(rootMeta));

      // Pattern directory with meta.json
      final patternDir = Directory('${patternsDir.path}/$patternId');
      patternDir.createSync(recursive: true);

      final patternMeta = {
        'version': 1,
        'id': patternId,
        'feedUrls': ['https://example.com/feed'],
        'playlists': ['main'],
      };
      File(
        '${patternDir.path}/meta.json',
      ).writeAsStringSync(jsonEncode(patternMeta));

      // Playlist definition
      final playlistDir = Directory('${patternDir.path}/playlists');
      playlistDir.createSync(recursive: true);

      final playlist = {
        'id': 'main',
        'displayName': 'Main Episodes',
        'resolverType': 'rss',
      };
      File(
        '${playlistDir.path}/main.json',
      ).writeAsStringSync(jsonEncode(playlist));
    }

    test('valid config structure passes with no errors', () {
      writeValidConfig(tempDir);
      final errors = validatePatterns('${tempDir.path}/patterns');
      expect(errors, isEmpty);
    });

    test('detects missing root meta.json', () {
      final patternsDir = Directory('${tempDir.path}/patterns');
      patternsDir.createSync(recursive: true);

      final errors = validatePatterns(patternsDir.path);
      expect(errors, hasLength(1));
      expect(errors[0].filePath, contains('meta.json'));
      expect(errors[0].message, contains('not found'));
    });

    test('detects invalid root meta.json', () {
      final patternsDir = Directory('${tempDir.path}/patterns');
      patternsDir.createSync(recursive: true);
      File('${patternsDir.path}/meta.json').writeAsStringSync('not json');

      final errors = validatePatterns(patternsDir.path);
      expect(errors, hasLength(1));
      expect(errors[0].filePath, contains('meta.json'));
      expect(errors[0].message, contains('parse'));
    });

    test('detects root meta.json with missing patterns array', () {
      final patternsDir = Directory('${tempDir.path}/patterns');
      patternsDir.createSync(recursive: true);
      File(
        '${patternsDir.path}/meta.json',
      ).writeAsStringSync(jsonEncode({'version': 2}));

      final errors = validatePatterns(patternsDir.path);
      expect(errors, hasLength(1));
      expect(errors[0].message, contains('patterns'));
    });

    test('detects invalid pattern summary in root meta.json', () {
      final patternsDir = Directory('${tempDir.path}/patterns');
      patternsDir.createSync(recursive: true);
      final rootMeta = {
        'version': 2,
        'patterns': [
          {'id': 'test', 'version': 1},
          // missing displayName, feedUrlHint, playlistCount
        ],
      };
      File(
        '${patternsDir.path}/meta.json',
      ).writeAsStringSync(jsonEncode(rootMeta));

      final errors = validatePatterns(patternsDir.path);
      expect(errors.length, 1);
      expect(errors[0].message, contains('PatternSummary'));
    });

    test('detects missing pattern meta.json', () {
      final patternsDir = Directory('${tempDir.path}/patterns');
      patternsDir.createSync(recursive: true);

      final rootMeta = {
        'version': 2,
        'patterns': [
          {
            'id': 'missing_pattern',
            'version': 1,
            'displayName': 'Missing',
            'feedUrlHint': 'https://example.com/feed',
            'playlistCount': 1,
          },
        ],
      };
      File(
        '${patternsDir.path}/meta.json',
      ).writeAsStringSync(jsonEncode(rootMeta));

      final errors = validatePatterns(patternsDir.path);
      expect(errors.length, 1);
      expect(errors[0].filePath, contains('missing_pattern'));
      expect(errors[0].message, contains('not found'));
    });

    test('detects missing playlist file', () {
      writeValidConfig(tempDir);

      // Remove the playlist file
      File(
        '${tempDir.path}/patterns/test_pattern/playlists/main.json',
      ).deleteSync();

      final errors = validatePatterns('${tempDir.path}/patterns');
      expect(errors.length, 1);
      expect(errors[0].filePath, contains('main.json'));
      expect(errors[0].message, contains('not found'));
    });

    test('detects invalid playlist JSON', () {
      writeValidConfig(tempDir);

      // Overwrite with invalid playlist (missing required fields)
      File(
        '${tempDir.path}/patterns/test_pattern/playlists/main.json',
      ).writeAsStringSync(jsonEncode({'id': 'main'}));

      final errors = validatePatterns('${tempDir.path}/patterns');
      expect(errors.length, 1);
      expect(errors[0].filePath, contains('main.json'));
      expect(errors[0].message, contains('parse'));
    });

    test('schema validation catches invalid resolverType', () {
      writeValidConfig(tempDir);

      // Overwrite with invalid resolverType
      final invalidPlaylist = {
        'id': 'main',
        'displayName': 'Main Episodes',
        'resolverType': 'nonexistent_resolver',
      };
      File(
        '${tempDir.path}/patterns/test_pattern/playlists/main.json',
      ).writeAsStringSync(jsonEncode(invalidPlaylist));

      final errors = validatePatterns('${tempDir.path}/patterns');
      expect(errors.length, 1);
      expect(errors[0].message, contains('schema'));
    });

    test('validates multiple patterns correctly', () {
      // Write first valid pattern
      writeValidConfig(tempDir, patternId: 'pattern_a');

      // Write second valid pattern
      final patternsDir = '${tempDir.path}/patterns';
      final patternBDir = Directory('$patternsDir/pattern_b');
      patternBDir.createSync(recursive: true);

      final patternBMeta = {
        'version': 1,
        'id': 'pattern_b',
        'feedUrls': ['https://example.com/feed_b'],
        'playlists': ['episodes'],
      };
      File(
        '${patternBDir.path}/meta.json',
      ).writeAsStringSync(jsonEncode(patternBMeta));

      final playlistDir = Directory('${patternBDir.path}/playlists');
      playlistDir.createSync(recursive: true);
      final playlist = {
        'id': 'episodes',
        'displayName': 'Episodes',
        'resolverType': 'year',
      };
      File(
        '${playlistDir.path}/episodes.json',
      ).writeAsStringSync(jsonEncode(playlist));

      // Update root meta.json to include both patterns
      final rootMeta = {
        'version': 2,
        'patterns': [
          {
            'id': 'pattern_a',
            'version': 1,
            'displayName': 'Pattern A',
            'feedUrlHint': 'https://example.com/feed',
            'playlistCount': 1,
          },
          {
            'id': 'pattern_b',
            'version': 1,
            'displayName': 'Pattern B',
            'feedUrlHint': 'https://example.com/feed_b',
            'playlistCount': 1,
          },
        ],
      };
      File('$patternsDir/meta.json').writeAsStringSync(jsonEncode(rootMeta));

      final errors = validatePatterns(patternsDir);
      expect(errors, isEmpty);
    });

    test('collects errors from multiple patterns', () {
      final patternsDir = Directory('${tempDir.path}/patterns');
      patternsDir.createSync(recursive: true);

      // Root meta lists two patterns but neither directory exists
      final rootMeta = {
        'version': 2,
        'patterns': [
          {
            'id': 'missing_a',
            'version': 1,
            'displayName': 'Missing A',
            'feedUrlHint': 'https://a.com/feed',
            'playlistCount': 0,
          },
          {
            'id': 'missing_b',
            'version': 1,
            'displayName': 'Missing B',
            'feedUrlHint': 'https://b.com/feed',
            'playlistCount': 0,
          },
        ],
      };
      File(
        '${patternsDir.path}/meta.json',
      ).writeAsStringSync(jsonEncode(rootMeta));

      final errors = validatePatterns(patternsDir.path);
      expect(2 <= errors.length, isTrue);
      expect(errors.any((e) => e.filePath.contains('missing_a')), isTrue);
      expect(errors.any((e) => e.filePath.contains('missing_b')), isTrue);
    });
  });
}
