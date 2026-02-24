import 'package:sp_cli/sp_cli.dart';
import 'package:test/test.dart';

void main() {
  group('extractChangedPatternIds', () {
    test('extracts pattern IDs from diff output', () {
      const diff = '''
patterns/coten_radio/playlists/regular.json
patterns/coten_radio/meta.json
patterns/rebuild/playlists/main.json
''';
      final ids = extractChangedPatternIds(diff, 'patterns/');
      expect(ids, unorderedEquals(['coten_radio', 'rebuild']));
    });

    test('ignores root meta.json (no subdirectory)', () {
      const diff = '''
patterns/meta.json
patterns/coten_radio/playlists/regular.json
''';
      final ids = extractChangedPatternIds(diff, 'patterns/');
      expect(ids, equals(['coten_radio']));
    });

    test('ignores files outside patterns dir', () {
      const diff = '''
README.md
some/other/file.json
patterns/coten_radio/meta.json
''';
      final ids = extractChangedPatternIds(diff, 'patterns/');
      expect(ids, equals(['coten_radio']));
    });

    test('returns empty for no changes', () {
      const diff = '';
      final ids = extractChangedPatternIds(diff, 'patterns/');
      expect(ids, isEmpty);
    });

    test('deduplicates pattern IDs', () {
      const diff = '''
patterns/coten_radio/meta.json
patterns/coten_radio/playlists/regular.json
patterns/coten_radio/playlists/bonus.json
''';
      final ids = extractChangedPatternIds(diff, 'patterns/');
      expect(ids, equals(['coten_radio']));
    });
  });

  group('computeVersionBumps', () {
    test('increments version from previous state', () {
      final result = computeVersionBumps(
        changedPatternIds: ['coten_radio'],
        previousVersions: {'coten_radio': 3},
        previousRootVersion: 10,
        currentPlaylistCounts: {'coten_radio': 2},
      );
      expect(result.patternBumps['coten_radio'], 4);
      expect(result.newRootVersion, 11);
      expect(result.playlistCounts['coten_radio'], 2);
    });

    test('starts at 1 for new patterns', () {
      final result = computeVersionBumps(
        changedPatternIds: ['new_pattern'],
        previousVersions: {},
        previousRootVersion: 5,
        currentPlaylistCounts: {'new_pattern': 1},
      );
      expect(result.patternBumps['new_pattern'], 1);
      expect(result.newRootVersion, 6);
    });

    test('bumps multiple patterns independently', () {
      final result = computeVersionBumps(
        changedPatternIds: ['alpha', 'beta'],
        previousVersions: {'alpha': 2, 'beta': 7},
        previousRootVersion: 20,
        currentPlaylistCounts: {'alpha': 1, 'beta': 3},
      );
      expect(result.patternBumps['alpha'], 3);
      expect(result.patternBumps['beta'], 8);
      expect(result.newRootVersion, 21);
      expect(result.playlistCounts['alpha'], 1);
      expect(result.playlistCounts['beta'], 3);
    });

    test('computes new root version as previousRootVersion + 1', () {
      final result = computeVersionBumps(
        changedPatternIds: ['x'],
        previousVersions: {'x': 1},
        previousRootVersion: 99,
        currentPlaylistCounts: {'x': 2},
      );
      expect(result.newRootVersion, 100);
    });
  });
}
