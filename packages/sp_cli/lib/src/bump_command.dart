import 'dart:convert';
import 'dart:io';

/// Result of computing version bumps.
final class BumpResult {
  const BumpResult({
    required this.patternBumps,
    required this.newRootVersion,
    required this.playlistCounts,
  });

  /// Pattern ID -> new version number.
  final Map<String, int> patternBumps;

  /// New root meta version number.
  final int newRootVersion;

  /// Pattern ID -> current playlist count.
  final Map<String, int> playlistCounts;
}

/// Parses git diff `--name-only` output and extracts unique pattern IDs.
///
/// Only paths under [patternsPrefix] that have a subdirectory component
/// are considered (e.g., `patterns/coten_radio/meta.json` yields
/// `coten_radio`, but `patterns/meta.json` is ignored).
List<String> extractChangedPatternIds(
  String diffOutput,
  String patternsPrefix,
) {
  final seen = <String>{};
  for (final line in diffOutput.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (!trimmed.startsWith(patternsPrefix)) continue;

    final rest = trimmed.substring(patternsPrefix.length);
    final slashIndex = rest.indexOf('/');
    // Skip root-level files (no subdirectory component)
    if (0 < slashIndex) {
      seen.add(rest.substring(0, slashIndex));
    }
  }
  return seen.toList();
}

/// Computes version bumps for changed patterns.
///
/// Each changed pattern gets `previousVersion + 1` (or 1 if new).
/// Root version is always `previousRootVersion + 1`.
BumpResult computeVersionBumps({
  required List<String> changedPatternIds,
  required Map<String, int> previousVersions,
  required int previousRootVersion,
  required Map<String, int> currentPlaylistCounts,
}) {
  final patternBumps = <String, int>{};
  for (final id in changedPatternIds) {
    final previous = previousVersions[id] ?? 0;
    patternBumps[id] = previous + 1;
  }

  return BumpResult(
    patternBumps: patternBumps,
    newRootVersion: previousRootVersion + 1,
    playlistCounts: Map.of(currentPlaylistCounts),
  );
}

/// Runs `git diff <previousRef> --name-only` in [repoDir].
///
/// Returns the diff output as a string.
/// Throws [ProcessException] if git exits with a non-zero code.
Future<String> gitDiff(String repoDir, String previousRef) async {
  final result = await Process.run('git', [
    'diff',
    previousRef,
    '--name-only',
  ], workingDirectory: repoDir);
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      ['diff', previousRef, '--name-only'],
      '${result.stderr}',
      result.exitCode,
    );
  }
  return result.stdout as String;
}

/// Runs `git show <ref>:<filePath>` in [repoDir].
///
/// Returns the file content, or null if the file does not exist at [ref].
Future<String?> gitShowFile(String repoDir, String ref, String filePath) async {
  final result = await Process.run('git', [
    'show',
    '$ref:$filePath',
  ], workingDirectory: repoDir);
  if (result.exitCode != 0) return null;
  return result.stdout as String;
}

/// Writes version bumps to disk.
///
/// Updates each changed pattern's `meta.json` version field, and updates
/// root `meta.json` with the new root version and per-pattern version
/// plus playlist count.
Future<void> applyBumps({
  required String patternsDir,
  required BumpResult bumps,
  required Map<String, dynamic> currentRootMeta,
}) async {
  final encoder = JsonEncoder.withIndent('  ');

  await _updatePatternMetas(patternsDir, bumps, encoder);
  _updateRootMeta(patternsDir, bumps, currentRootMeta, encoder);
}

/// Updates each changed pattern's meta.json with the new version.
Future<void> _updatePatternMetas(
  String patternsDir,
  BumpResult bumps,
  JsonEncoder encoder,
) async {
  for (final entry in bumps.patternBumps.entries) {
    final metaPath = '$patternsDir/${entry.key}/meta.json';
    final file = File(metaPath);
    final content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    content['version'] = entry.value;
    file.writeAsStringSync('${encoder.convert(content)}\n');
  }
}

/// Updates root meta.json with new versions and playlist counts.
void _updateRootMeta(
  String patternsDir,
  BumpResult bumps,
  Map<String, dynamic> currentRootMeta,
  JsonEncoder encoder,
) {
  final meta = Map<String, dynamic>.of(currentRootMeta);
  meta['version'] = bumps.newRootVersion;

  final patterns = (meta['patterns'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final pattern in patterns) {
    final id = pattern['id'] as String;
    if (bumps.patternBumps.containsKey(id)) {
      pattern['version'] = bumps.patternBumps[id];
      pattern['playlistCount'] = bumps.playlistCounts[id];
    }
  }

  final rootPath = '$patternsDir/meta.json';
  File(rootPath).writeAsStringSync('${encoder.convert(meta)}\n');
}
