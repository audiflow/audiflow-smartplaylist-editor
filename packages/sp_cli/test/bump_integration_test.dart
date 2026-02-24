@Tags(['integration'])
import 'dart:convert';
import 'dart:io';

import 'package:sp_cli/sp_cli.dart';
import 'package:test/test.dart';

final _encoder = JsonEncoder.withIndent('  ');

void main() {
  late Directory tempDir;
  late String repoDir;
  late String patternsDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sp_cli_bump_integ_');
    repoDir = tempDir.path;
    patternsDir = '$repoDir/patterns';

    _initGitRepo(repoDir);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('bump integration', () {
    test('bumps version for changed pattern', () async {
      // Commit 1: initial state
      _writeInitialConfig(patternsDir);
      _gitCommit(repoDir, 'initial config');
      final baseRef = _gitRevParse(repoDir, 'HEAD');

      // Commit 2: simulate PR merge (modify playlist)
      _modifyPlaylist(patternsDir);
      _gitCommit(repoDir, 'update playlist displayName');

      // Run bump pipeline
      final diffOutput = await gitDiff(repoDir, baseRef);
      final changedIds = extractChangedPatternIds(diffOutput, 'patterns/');
      expect(changedIds, equals(['test']));

      // Read previous versions from base commit
      final previousRootJson = await gitShowFile(
        repoDir,
        baseRef,
        'patterns/meta.json',
      );
      final previousRoot =
          jsonDecode(previousRootJson!) as Map<String, dynamic>;
      final previousRootVersion = previousRoot['version'] as int;

      final previousVersions = _extractPatternVersions(previousRoot);
      final currentPlaylistCounts = _countPlaylists(patternsDir, changedIds);

      final bumps = computeVersionBumps(
        changedPatternIds: changedIds,
        previousVersions: previousVersions,
        previousRootVersion: previousRootVersion,
        currentPlaylistCounts: currentPlaylistCounts,
      );

      // Read current root meta before applying bumps
      final currentRootMeta = _readJson('$patternsDir/meta.json');
      await applyBumps(
        patternsDir: patternsDir,
        bumps: bumps,
        currentRootMeta: currentRootMeta,
      );

      // Verify pattern meta was bumped
      final updatedPatternMeta = _readJson('$patternsDir/test/meta.json');
      expect(updatedPatternMeta['version'], 2);

      // Verify root meta was bumped
      final updatedRootMeta = _readJson('$patternsDir/meta.json');
      expect(updatedRootMeta['version'], 2);

      final patterns = updatedRootMeta['patterns'] as List<dynamic>;
      final testEntry = patterns.first as Map<String, dynamic>;
      expect(testEntry['id'], 'test');
      expect(testEntry['version'], 2);
      expect(testEntry['playlistCount'], 1);
    });
  });
}

// -- Git helpers ----------------------------------------------------------

void _initGitRepo(String dir) {
  _git(dir, ['init']);
  _git(dir, ['config', 'user.name', 'Test']);
  _git(dir, ['config', 'user.email', 'test@test.com']);
}

void _gitCommit(String dir, String message) {
  _git(dir, ['add', '.']);
  _git(dir, ['commit', '-m', message]);
}

String _gitRevParse(String dir, String ref) {
  final result = Process.runSync('git', [
    'rev-parse',
    ref,
  ], workingDirectory: dir);
  return (result.stdout as String).trim();
}

void _git(String dir, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: dir);
  if (result.exitCode != 0) {
    throw ProcessException('git', args, '${result.stderr}', result.exitCode);
  }
}

// -- File helpers ---------------------------------------------------------

void _writeInitialConfig(String patternsDir) {
  _writeRootMeta(patternsDir);
  _writePatternMeta(patternsDir);
  _writePlaylist(patternsDir, 'Main Episodes');
}

void _writeRootMeta(String patternsDir) {
  final rootMeta = {
    'version': 1,
    'patterns': [
      {
        'id': 'test',
        'version': 1,
        'displayName': 'Test Pattern',
        'feedUrlHint': 'https://example.com/feed',
        'playlistCount': 1,
      },
    ],
  };
  _writeJson('$patternsDir/meta.json', rootMeta);
}

void _writePatternMeta(String patternsDir) {
  final patternMeta = {
    'version': 1,
    'id': 'test',
    'feedUrls': ['https://example.com/feed'],
    'playlists': ['main'],
  };
  _writeJson('$patternsDir/test/meta.json', patternMeta);
}

void _writePlaylist(String patternsDir, String displayName) {
  final playlist = {
    'id': 'main',
    'displayName': displayName,
    'resolverType': 'rss',
  };
  _writeJson('$patternsDir/test/playlists/main.json', playlist);
}

void _modifyPlaylist(String patternsDir) {
  _writePlaylist(patternsDir, 'Updated Episodes');
}

void _writeJson(String path, Map<String, dynamic> data) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${_encoder.convert(data)}\n');
}

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

// -- Data extraction helpers ----------------------------------------------

Map<String, int> _extractPatternVersions(Map<String, dynamic> rootMeta) {
  final patterns = (rootMeta['patterns'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  return {for (final p in patterns) p['id'] as String: p['version'] as int};
}

Map<String, int> _countPlaylists(String patternsDir, List<String> ids) {
  return {
    for (final id in ids)
      id: _readPlaylistIds('$patternsDir/$id/meta.json').length,
  };
}

List<String> _readPlaylistIds(String metaPath) {
  final meta = _readJson(metaPath);
  return (meta['playlists'] as List<dynamic>).cast<String>();
}
