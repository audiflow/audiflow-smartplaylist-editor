import 'dart:convert';
import 'dart:io';

import 'migrate.dart';

void main() {
  var passed = 0;
  var failed = 0;

  void expectEquals(Object? actual, Object? expected, String label) {
    if (actual == expected) {
      passed++;
    } else {
      failed++;
      // ignore: avoid_print
      print('FAIL: $label - expected $expected, got $actual');
    }
  }

  void expectTrue(bool value, String label) {
    if (value) {
      passed++;
    } else {
      failed++;
      // ignore: avoid_print
      print('FAIL: $label');
    }
  }

  // Test 1: splits single config into multi-file structure
  {
    final tempDir = Directory.systemTemp.createTempSync('migrate_test_');
    try {
      final input = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'test_pattern',
            'feedUrlPatterns': [r'https://example\.com/feed'],
            'yearGroupedEpisodes': true,
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main Playlist',
                'resolverType': 'rss',
              },
              {
                'id': 'bonus',
                'displayName': 'Bonus',
                'resolverType': 'category',
              },
            ],
          },
        ],
      });

      migrate(input, tempDir.path);

      // Verify root meta.json
      final rootMeta =
          jsonDecode(File('${tempDir.path}/meta.json').readAsStringSync())
              as Map<String, dynamic>;
      expectEquals(rootMeta['version'], 1, 'root version');
      expectEquals((rootMeta['patterns'] as List).length, 1, 'pattern count');
      expectEquals(
        rootMeta['patterns'][0]['id'],
        'test_pattern',
        'pattern id in root',
      );
      expectEquals(
        rootMeta['patterns'][0]['playlistCount'],
        2,
        'playlist count in root',
      );

      // Verify pattern meta.json
      final patternMeta =
          jsonDecode(
                File(
                  '${tempDir.path}/test_pattern/meta.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expectEquals(patternMeta['id'], 'test_pattern', 'pattern meta id');
      expectTrue(
        patternMeta['yearGroupedEpisodes'] == true,
        'yearGroupedEpisodes',
      );
      expectEquals(
        (patternMeta['playlists'] as List).length,
        2,
        'playlists in meta',
      );
      expectEquals(
        (patternMeta['playlists'] as List)[0],
        'main',
        'first playlist id in meta',
      );
      expectEquals(
        (patternMeta['playlists'] as List)[1],
        'bonus',
        'second playlist id in meta',
      );

      // Verify individual playlist files
      final mainPlaylist =
          jsonDecode(
                File(
                  '${tempDir.path}/test_pattern/playlists/main.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expectEquals(mainPlaylist['id'], 'main', 'main playlist id');
      expectEquals(
        mainPlaylist['resolverType'],
        'rss',
        'main playlist resolverType',
      );
      expectEquals(
        mainPlaylist['displayName'],
        'Main Playlist',
        'main playlist displayName',
      );

      final bonusPlaylist =
          jsonDecode(
                File(
                  '${tempDir.path}/test_pattern/playlists/bonus.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expectEquals(bonusPlaylist['id'], 'bonus', 'bonus playlist id');
      expectEquals(
        bonusPlaylist['resolverType'],
        'category',
        'bonus playlist resolverType',
      );
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  }

  // Test 2: derives displayName from snake_case pattern ID
  {
    final tempDir = Directory.systemTemp.createTempSync('migrate_test_');
    try {
      final input = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'coten_radio',
            'feedUrlPatterns': [r'https://example\.com/feed'],
            'playlists': [
              {'id': 'p1', 'displayName': 'P1', 'resolverType': 'rss'},
            ],
          },
        ],
      });

      migrate(input, tempDir.path);

      final rootMeta =
          jsonDecode(File('${tempDir.path}/meta.json').readAsStringSync())
              as Map<String, dynamic>;
      expectEquals(
        rootMeta['patterns'][0]['displayName'],
        'Coten Radio',
        'derived displayName from snake_case',
      );
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  }

  // Test 3: strips regex escapes for feedUrlHint
  {
    final tempDir = Directory.systemTemp.createTempSync('migrate_test_');
    try {
      final input = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'feedUrlPatterns': [r'https://anchor\.fm/s/8c2088c/podcast/rss'],
            'playlists': [
              {'id': 'p1', 'displayName': 'P1', 'resolverType': 'rss'},
            ],
          },
        ],
      });

      migrate(input, tempDir.path);

      final rootMeta =
          jsonDecode(File('${tempDir.path}/meta.json').readAsStringSync())
              as Map<String, dynamic>;
      final hint = rootMeta['patterns'][0]['feedUrlHint'] as String;
      expectEquals(
        hint,
        'https://anchor.fm/s/8c2088c/podcast/rss',
        'feedUrlHint with escapes stripped',
      );
      expectTrue(
        !hint.contains(r'\'),
        'feedUrlHint should not contain backslashes',
      );
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  }

  // Test 4: handles pattern with no feedUrlPatterns
  {
    final tempDir = Directory.systemTemp.createTempSync('migrate_test_');
    try {
      final input = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'guid_only',
            'podcastGuid': 'abc-123',
            'playlists': [
              {'id': 'p1', 'displayName': 'P1', 'resolverType': 'rss'},
            ],
          },
        ],
      });

      migrate(input, tempDir.path);

      final rootMeta =
          jsonDecode(File('${tempDir.path}/meta.json').readAsStringSync())
              as Map<String, dynamic>;
      expectEquals(
        rootMeta['patterns'][0]['feedUrlHint'],
        '',
        'empty feedUrlHint when no patterns',
      );

      final patternMeta =
          jsonDecode(
                File('${tempDir.path}/guid_only/meta.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expectEquals(
        patternMeta['podcastGuid'],
        'abc-123',
        'podcastGuid preserved in meta',
      );
      expectEquals(
        (patternMeta['feedUrlPatterns'] as List).length,
        0,
        'empty feedUrlPatterns',
      );
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  }

  // Test 5: handles multiple patterns
  {
    final tempDir = Directory.systemTemp.createTempSync('migrate_test_');
    try {
      final input = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'pattern_a',
            'feedUrlPatterns': [r'https://a\.com/feed'],
            'playlists': [
              {'id': 'p1', 'displayName': 'P1', 'resolverType': 'rss'},
            ],
          },
          {
            'id': 'pattern_b',
            'feedUrlPatterns': [r'https://b\.com/feed'],
            'playlists': [
              {'id': 'p2', 'displayName': 'P2', 'resolverType': 'rss'},
              {'id': 'p3', 'displayName': 'P3', 'resolverType': 'category'},
            ],
          },
        ],
      });

      migrate(input, tempDir.path);

      final rootMeta =
          jsonDecode(File('${tempDir.path}/meta.json').readAsStringSync())
              as Map<String, dynamic>;
      expectEquals(
        (rootMeta['patterns'] as List).length,
        2,
        'two patterns in root',
      );
      expectEquals(
        rootMeta['patterns'][0]['id'],
        'pattern_a',
        'first pattern id',
      );
      expectEquals(
        rootMeta['patterns'][1]['id'],
        'pattern_b',
        'second pattern id',
      );
      expectEquals(
        rootMeta['patterns'][0]['playlistCount'],
        1,
        'first pattern playlist count',
      );
      expectEquals(
        rootMeta['patterns'][1]['playlistCount'],
        2,
        'second pattern playlist count',
      );

      // Verify both pattern directories exist
      expectTrue(
        File('${tempDir.path}/pattern_a/meta.json').existsSync(),
        'pattern_a meta.json exists',
      );
      expectTrue(
        File('${tempDir.path}/pattern_b/meta.json').existsSync(),
        'pattern_b meta.json exists',
      );
      expectTrue(
        File('${tempDir.path}/pattern_b/playlists/p2.json').existsSync(),
        'pattern_b/playlists/p2.json exists',
      );
      expectTrue(
        File('${tempDir.path}/pattern_b/playlists/p3.json').existsSync(),
        'pattern_b/playlists/p3.json exists',
      );
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  }

  // Test 6: yearGroupedEpisodes defaults to false (omitted from meta)
  {
    final tempDir = Directory.systemTemp.createTempSync('migrate_test_');
    try {
      final input = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'no_year',
            'feedUrlPatterns': [r'https://example\.com/feed'],
            'playlists': [
              {'id': 'p1', 'displayName': 'P1', 'resolverType': 'rss'},
            ],
          },
        ],
      });

      migrate(input, tempDir.path);

      final patternMeta =
          jsonDecode(
                File('${tempDir.path}/no_year/meta.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expectTrue(
        !patternMeta.containsKey('yearGroupedEpisodes'),
        'yearGroupedEpisodes omitted when false',
      );
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  }

  // Test 7: unit test for deriveDisplayName
  {
    expectEquals(
      deriveDisplayName('coten_radio'),
      'Coten Radio',
      'deriveDisplayName: coten_radio',
    );
    expectEquals(
      deriveDisplayName('my_podcast'),
      'My Podcast',
      'deriveDisplayName: my_podcast',
    );
    expectEquals(
      deriveDisplayName('single'),
      'Single',
      'deriveDisplayName: single word',
    );
  }

  // Test 8: unit test for stripRegexEscapes
  {
    expectEquals(
      stripRegexEscapes(r'https://anchor\.fm/feed'),
      'https://anchor.fm/feed',
      'stripRegexEscapes: dot escape',
    );
    expectEquals(
      stripRegexEscapes('https://example.com/feed'),
      'https://example.com/feed',
      'stripRegexEscapes: no escapes',
    );
  }

  // ignore: avoid_print
  print('\nResults: $passed passed, $failed failed');
  if (0 < failed) {
    exit(1);
  }
}
