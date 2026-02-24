import 'dart:convert';
import 'dart:io';

import 'package:sp_cli/sp_cli.dart';

void main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run bin/bump_versions.dart <patterns-dir> <previous-ref>',
    );
    exit(2);
  }

  final patternsDir = args[0];
  final previousRef = args[1];

  if (!Directory(patternsDir).existsSync()) {
    stderr.writeln('Error: directory not found: $patternsDir');
    exit(2);
  }

  final repoDir = Directory(patternsDir).parent.path;
  stderr.writeln('Detecting changes from $previousRef...');

  final changedIds = await _detectChanges(repoDir, previousRef);
  if (changedIds.isEmpty) {
    stderr.writeln('No pattern changes detected. Nothing to bump.');
    exit(0);
  }
  stderr.writeln('  Changed patterns: ${changedIds.join(', ')}');

  final previousVersions = await _readPreviousVersions(
    repoDir,
    previousRef,
    changedIds,
  );
  final previousRootVersion = await _readPreviousRootVersion(
    repoDir,
    previousRef,
  );
  final playlistCounts = _readPlaylistCounts(patternsDir, changedIds);

  final bumps = computeVersionBumps(
    changedPatternIds: changedIds,
    previousVersions: previousVersions,
    previousRootVersion: previousRootVersion,
    currentPlaylistCounts: playlistCounts,
  );

  final currentRootMeta =
      jsonDecode(File('$patternsDir/meta.json').readAsStringSync())
          as Map<String, dynamic>;

  await applyBumps(
    patternsDir: patternsDir,
    bumps: bumps,
    currentRootMeta: currentRootMeta,
  );

  _printSummary(bumps, previousVersions, previousRootVersion);
}

Future<List<String>> _detectChanges(String repoDir, String previousRef) async {
  final diffOutput = await gitDiff(repoDir, previousRef);
  return extractChangedPatternIds(diffOutput, 'patterns/');
}

Future<Map<String, int>> _readPreviousVersions(
  String repoDir,
  String previousRef,
  List<String> changedIds,
) async {
  final versions = <String, int>{};
  for (final id in changedIds) {
    final content = await gitShowFile(
      repoDir,
      previousRef,
      'patterns/$id/meta.json',
    );
    if (content != null) {
      final meta = jsonDecode(content) as Map<String, dynamic>;
      versions[id] = meta['version'] as int;
    }
  }
  return versions;
}

Future<int> _readPreviousRootVersion(String repoDir, String previousRef) async {
  final content = await gitShowFile(repoDir, previousRef, 'patterns/meta.json');
  if (content == null) return 0;
  final meta = jsonDecode(content) as Map<String, dynamic>;
  return meta['version'] as int;
}

Map<String, int> _readPlaylistCounts(
  String patternsDir,
  List<String> changedIds,
) {
  final counts = <String, int>{};
  for (final id in changedIds) {
    final metaFile = File('$patternsDir/$id/meta.json');
    if (metaFile.existsSync()) {
      final meta =
          jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      counts[id] = (meta['playlists'] as List).length;
    }
  }
  return counts;
}

void _printSummary(
  BumpResult bumps,
  Map<String, int> previousVersions,
  int previousRootVersion,
) {
  for (final entry in bumps.patternBumps.entries) {
    final prev = previousVersions[entry.key] ?? 0;
    stderr.writeln('  ${entry.key}: version $prev -> ${entry.value}');
  }
  stderr.writeln(
    '  Root meta: version $previousRootVersion -> ${bumps.newRootVersion}',
  );
  stderr.writeln('Version bump complete.');
}
