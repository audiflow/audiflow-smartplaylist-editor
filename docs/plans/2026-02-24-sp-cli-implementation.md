# sp_cli: Config Validator & Version Bump CLI - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `sp_cli` package with two CLI tools: `validate` (validates all split config files) and `bump_versions` (increments version fields for changed patterns using git history).

**Architecture:** New `packages/sp_cli` Dart workspace package depending on `sp_shared`. Validate command reads files from a patterns directory, parses them through `fromJson()` and `ConfigAssembler`, then validates via `SmartPlaylistValidator`. Bump command uses `git diff` and `git show` to detect changes and read previous versions, then increments and writes.

**Tech Stack:** Dart 3.10, `sp_shared` (models, schema, assembler), `dart:io` (file system, process).

---

## Phase 1: sp_cli Package Scaffold

### Task 1: Create sp_cli package

**Files:**
- Create: `packages/sp_cli/pubspec.yaml`
- Create: `packages/sp_cli/lib/sp_cli.dart`
- Modify: `pubspec.yaml` (root workspace - add sp_cli)

**Step 1: Create pubspec.yaml**

```yaml
# packages/sp_cli/pubspec.yaml
name: sp_cli
description: CLI tools for validating and managing smart playlist configs
publish_to: none
resolution: workspace

environment:
  sdk: ^3.10.0

dependencies:
  sp_shared:
    path: ../sp_shared

dev_dependencies:
  test: ^1.25.0
```

**Step 2: Create library export file**

```dart
// packages/sp_cli/lib/sp_cli.dart
library;

// Will be populated as we add implementations
```

**Step 3: Add sp_cli to root workspace**

In root `pubspec.yaml`, add `- packages/sp_cli` to the workspace list:

```yaml
workspace:
  - packages/sp_shared
  - packages/sp_server
  - packages/sp_cli
  - mcp_server
```

**Step 4: Run pub get to validate**

Run: `dart pub get`
Expected: Success, resolves all dependencies

**Step 5: Commit**

```bash
jj bookmark create feat/sp-cli
```

---

## Phase 2: Validate Command

### Task 2: Add ValidationError type and core validate logic

**Files:**
- Create: `packages/sp_cli/lib/src/validate_command.dart`
- Test: `packages/sp_cli/test/validate_command_test.dart`
- Modify: `packages/sp_cli/lib/sp_cli.dart` (add export)

**Step 1: Write the failing test**

```dart
// packages/sp_cli/test/validate_command_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:sp_cli/sp_cli.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('validate_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Helper to write a JSON file at the given path under tempDir.
  void writeJson(String relativePath, Object data) {
    final file = File('${tempDir.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  group('ValidateCommand', () {
    test('validates a correct config structure', () async {
      writeJson('meta.json', {
        'version': 2,
        'patterns': [
          {
            'id': 'test_pattern',
            'version': 1,
            'displayName': 'Test Pattern',
            'feedUrlHint': 'example.com/feed',
            'playlistCount': 1,
          },
        ],
      });
      writeJson('test_pattern/meta.json', {
        'version': 1,
        'id': 'test_pattern',
        'feedUrls': ['https://example.com/feed'],
        'playlists': ['main'],
      });
      writeJson('test_pattern/playlists/main.json', {
        'id': 'main',
        'displayName': 'Main Playlist',
        'resolverType': 'rss',
      });

      final errors = await validatePatterns(tempDir.path);
      expect(errors, isEmpty);
    });

    test('reports error for missing root meta.json', () async {
      final errors = await validatePatterns(tempDir.path);
      expect(errors, hasLength(1));
      expect(errors[0].filePath, 'meta.json');
      expect(errors[0].message, contains('not found'));
    });

    test('reports error for invalid root meta.json', () async {
      writeJson('meta.json', {'invalid': true});

      final errors = await validatePatterns(tempDir.path);
      expect(errors, isNotEmpty);
      expect(errors[0].filePath, 'meta.json');
    });

    test('reports error for missing pattern meta.json', () async {
      writeJson('meta.json', {
        'version': 1,
        'patterns': [
          {
            'id': 'missing_pattern',
            'version': 1,
            'displayName': 'Missing',
            'feedUrlHint': 'example.com',
            'playlistCount': 1,
          },
        ],
      });

      final errors = await validatePatterns(tempDir.path);
      expect(errors, isNotEmpty);
      expect(errors[0].filePath, 'missing_pattern/meta.json');
    });

    test('reports error for missing playlist file', () async {
      writeJson('meta.json', {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'version': 1,
            'displayName': 'Test',
            'feedUrlHint': 'example.com',
            'playlistCount': 1,
          },
        ],
      });
      writeJson('test/meta.json', {
        'version': 1,
        'id': 'test',
        'feedUrls': ['https://example.com/feed'],
        'playlists': ['nonexistent'],
      });

      final errors = await validatePatterns(tempDir.path);
      expect(errors, isNotEmpty);
      expect(
        errors.any((e) => e.filePath.contains('nonexistent')),
        isTrue,
      );
    });

    test('reports error for invalid playlist JSON', () async {
      writeJson('meta.json', {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'version': 1,
            'displayName': 'Test',
            'feedUrlHint': 'example.com',
            'playlistCount': 1,
          },
        ],
      });
      writeJson('test/meta.json', {
        'version': 1,
        'id': 'test',
        'feedUrls': ['https://example.com/feed'],
        'playlists': ['bad'],
      });
      // Missing required fields: displayName, resolverType
      writeJson('test/playlists/bad.json', {
        'id': 'bad',
      });

      final errors = await validatePatterns(tempDir.path);
      expect(errors, isNotEmpty);
      expect(errors[0].filePath, 'test/playlists/bad.json');
    });

    test('validates assembled config against schema', () async {
      writeJson('meta.json', {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'version': 1,
            'displayName': 'Test',
            'feedUrlHint': 'example.com',
            'playlistCount': 1,
          },
        ],
      });
      writeJson('test/meta.json', {
        'version': 1,
        'id': 'test',
        'feedUrls': ['https://example.com/feed'],
        'playlists': ['main'],
      });
      writeJson('test/playlists/main.json', {
        'id': 'main',
        'displayName': 'Main',
        'resolverType': 'invalid_resolver', // not in schema enum
      });

      final errors = await validatePatterns(tempDir.path);
      expect(errors, isNotEmpty);
      // Schema validation catches the invalid resolverType
      expect(
        errors.any((e) => e.message.contains('resolverType')),
        isTrue,
      );
    });

    test('validates multiple patterns', () async {
      writeJson('meta.json', {
        'version': 1,
        'patterns': [
          {
            'id': 'a',
            'version': 1,
            'displayName': 'A',
            'feedUrlHint': 'a.com',
            'playlistCount': 1,
          },
          {
            'id': 'b',
            'version': 1,
            'displayName': 'B',
            'feedUrlHint': 'b.com',
            'playlistCount': 1,
          },
        ],
      });
      writeJson('a/meta.json', {
        'version': 1,
        'id': 'a',
        'feedUrls': ['https://a.com/feed'],
        'playlists': ['main'],
      });
      writeJson('a/playlists/main.json', {
        'id': 'main',
        'displayName': 'A Main',
        'resolverType': 'rss',
      });
      writeJson('b/meta.json', {
        'version': 1,
        'id': 'b',
        'feedUrls': ['https://b.com/feed'],
        'playlists': ['main'],
      });
      writeJson('b/playlists/main.json', {
        'id': 'main',
        'displayName': 'B Main',
        'resolverType': 'year',
      });

      final errors = await validatePatterns(tempDir.path);
      expect(errors, isEmpty);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_cli/test/validate_command_test.dart`
Expected: FAIL - `validatePatterns` not found

**Step 3: Write implementation**

```dart
// packages/sp_cli/lib/src/validate_command.dart
import 'dart:convert';
import 'dart:io';

import 'package:sp_shared/sp_shared.dart';

/// A validation error with file path and message.
final class ValidationError {
  const ValidationError({required this.filePath, required this.message});

  final String filePath;
  final String message;

  @override
  String toString() => '$filePath: $message';
}

/// Validates all configs in a patterns directory.
///
/// Performs four levels of validation:
/// 1. Root meta.json structure
/// 2. Pattern meta.json structure + playlist file existence
/// 3. Playlist definition parsing
/// 4. Assembly + JSON Schema validation
///
/// Returns a list of errors. Empty list = all valid.
Future<List<ValidationError>> validatePatterns(String patternsDir) async {
  final errors = <ValidationError>[];

  // 1. Parse root meta.json
  final rootMetaFile = File('$patternsDir/meta.json');
  if (!rootMetaFile.existsSync()) {
    return [
      const ValidationError(
        filePath: 'meta.json',
        message: 'Root meta.json not found',
      ),
    ];
  }

  final Map<String, dynamic> rootJson;
  final List<dynamic> patternEntries;
  try {
    rootJson = jsonDecode(rootMetaFile.readAsStringSync())
        as Map<String, dynamic>;
    patternEntries = rootJson['patterns'] as List<dynamic>;
    // Validate each entry can be parsed as PatternSummary
    for (final entry in patternEntries) {
      PatternSummary.fromJson(entry as Map<String, dynamic>);
    }
  } catch (e) {
    errors.add(ValidationError(
      filePath: 'meta.json',
      message: 'Failed to parse root meta.json: $e',
    ));
    return errors;
  }

  // 2-4. Validate each pattern
  final validator = SmartPlaylistValidator();

  for (final entry in patternEntries) {
    final patternId =
        (entry as Map<String, dynamic>)['id'] as String;

    // 2. Parse pattern meta.json
    final patternMetaFile = File('$patternsDir/$patternId/meta.json');
    if (!patternMetaFile.existsSync()) {
      errors.add(ValidationError(
        filePath: '$patternId/meta.json',
        message: 'Pattern meta.json not found',
      ));
      continue;
    }

    final PatternMeta patternMeta;
    try {
      patternMeta = PatternMeta.parseJson(
        patternMetaFile.readAsStringSync(),
      );
    } catch (e) {
      errors.add(ValidationError(
        filePath: '$patternId/meta.json',
        message: 'Failed to parse pattern meta.json: $e',
      ));
      continue;
    }

    // 3. Parse each playlist definition
    final playlists = <SmartPlaylistDefinition>[];
    var hasPlaylistError = false;

    for (final playlistId in patternMeta.playlists) {
      final playlistFile = File(
        '$patternsDir/$patternId/playlists/$playlistId.json',
      );
      if (!playlistFile.existsSync()) {
        errors.add(ValidationError(
          filePath: '$patternId/playlists/$playlistId.json',
          message: 'Playlist file not found',
        ));
        hasPlaylistError = true;
        continue;
      }

      try {
        final playlistJson = jsonDecode(playlistFile.readAsStringSync())
            as Map<String, dynamic>;
        playlists.add(SmartPlaylistDefinition.fromJson(playlistJson));
      } catch (e) {
        errors.add(ValidationError(
          filePath: '$patternId/playlists/$playlistId.json',
          message: 'Failed to parse playlist: $e',
        ));
        hasPlaylistError = true;
      }
    }

    if (hasPlaylistError) continue;

    // 4. Assemble and validate against schema
    try {
      final config = ConfigAssembler.assemble(patternMeta, playlists);
      final envelope = {
        'version': 1,
        'patterns': [config.toJson()],
      };
      final schemaErrors = validator.validate(envelope);
      for (final schemaError in schemaErrors) {
        errors.add(ValidationError(
          filePath: '$patternId',
          message: 'Schema validation: $schemaError',
        ));
      }
    } catch (e) {
      errors.add(ValidationError(
        filePath: '$patternId',
        message: 'Assembly failed: $e',
      ));
    }
  }

  return errors;
}
```

**Step 4: Add export to library**

```dart
// packages/sp_cli/lib/sp_cli.dart
library;

export 'src/validate_command.dart';
```

**Step 5: Run test to verify it passes**

Run: `dart test packages/sp_cli/test/validate_command_test.dart`
Expected: PASS

**Step 6: Commit**

---

### Task 3: Create validate CLI entry point

**Files:**
- Create: `packages/sp_cli/bin/validate.dart`

**Step 1: Write the entry point**

```dart
// packages/sp_cli/bin/validate.dart
import 'dart:io';

import 'package:sp_cli/sp_cli.dart';

void main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run bin/validate.dart <patterns-dir>');
    exit(2);
  }

  final patternsDir = args[0];
  if (!Directory(patternsDir).existsSync()) {
    stderr.writeln('Error: Directory not found: $patternsDir');
    exit(2);
  }

  stderr.writeln('Validating patterns in $patternsDir...');

  final errors = await validatePatterns(patternsDir);

  if (errors.isEmpty) {
    stderr.writeln('All configs valid.');
    exit(0);
  }

  stderr.writeln('');
  for (final error in errors) {
    stderr.writeln('  [FAIL] ${error.filePath}');
    stderr.writeln('    - ${error.message}');
  }
  stderr.writeln('');
  stderr.writeln('Validation failed: ${errors.length} error(s) found.');
  exit(1);
}
```

**Step 2: Test against actual dev data repo**

Run: `dart run packages/sp_cli/bin/validate.dart /Users/tohru/Documents/src/projects/audiflow/audiflow-smartplaylist-dev/patterns`
Expected: All configs valid (exit 0)

**Step 3: Commit**

---

## Phase 3: Bump Versions Command

### Task 4: Add BumpResult type and diff detection

**Files:**
- Create: `packages/sp_cli/lib/src/bump_command.dart`
- Test: `packages/sp_cli/test/bump_command_test.dart`
- Modify: `packages/sp_cli/lib/sp_cli.dart` (add export)

**Step 1: Write the failing test**

```dart
// packages/sp_cli/test/bump_command_test.dart
import 'package:sp_cli/sp_cli.dart';
import 'package:test/test.dart';

void main() {
  group('extractChangedPatternIds', () {
    test('extracts pattern IDs from diff output', () {
      final diffOutput = '''
patterns/coten_radio/playlists/regular.json
patterns/coten_radio/playlists/short.json
patterns/news_connect/meta.json
''';
      final ids = extractChangedPatternIds(diffOutput, 'patterns');
      expect(ids, unorderedEquals(['coten_radio', 'news_connect']));
    });

    test('ignores root meta.json', () {
      final diffOutput = 'patterns/meta.json\n';
      final ids = extractChangedPatternIds(diffOutput, 'patterns');
      expect(ids, isEmpty);
    });

    test('ignores files outside patterns dir', () {
      final diffOutput = '''
.github/workflows/deploy.yml
README.md
patterns/coten_radio/meta.json
''';
      final ids = extractChangedPatternIds(diffOutput, 'patterns');
      expect(ids, equals(['coten_radio']));
    });

    test('returns empty for no changes', () {
      final ids = extractChangedPatternIds('', 'patterns');
      expect(ids, isEmpty);
    });

    test('deduplicates pattern IDs', () {
      final diffOutput = '''
patterns/coten_radio/meta.json
patterns/coten_radio/playlists/regular.json
patterns/coten_radio/playlists/short.json
''';
      final ids = extractChangedPatternIds(diffOutput, 'patterns');
      expect(ids, equals(['coten_radio']));
    });
  });

  group('computeVersionBumps', () {
    test('increments version from previous state', () {
      final bumps = computeVersionBumps(
        changedPatternIds: ['coten_radio'],
        previousVersions: {'coten_radio': 2},
        currentPlaylistCounts: {'coten_radio': 3},
      );
      expect(bumps.patternBumps, hasLength(1));
      expect(bumps.patternBumps['coten_radio'], 3);
    });

    test('starts at 1 for new patterns', () {
      final bumps = computeVersionBumps(
        changedPatternIds: ['new_pattern'],
        previousVersions: {}, // no previous version
        currentPlaylistCounts: {'new_pattern': 2},
      );
      expect(bumps.patternBumps['new_pattern'], 1);
    });

    test('bumps multiple patterns independently', () {
      final bumps = computeVersionBumps(
        changedPatternIds: ['a', 'b'],
        previousVersions: {'a': 5, 'b': 1},
        currentPlaylistCounts: {'a': 2, 'b': 3},
      );
      expect(bumps.patternBumps['a'], 6);
      expect(bumps.patternBumps['b'], 2);
    });

    test('computes new root version', () {
      final bumps = computeVersionBumps(
        changedPatternIds: ['a'],
        previousVersions: {'a': 1},
        previousRootVersion: 5,
        currentPlaylistCounts: {'a': 1},
      );
      expect(bumps.newRootVersion, 6);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_cli/test/bump_command_test.dart`
Expected: FAIL - functions not found

**Step 3: Write implementation**

```dart
// packages/sp_cli/lib/src/bump_command.dart
import 'dart:convert';
import 'dart:io';

/// Result of computing version bumps.
final class BumpResult {
  const BumpResult({
    required this.patternBumps,
    required this.newRootVersion,
    required this.playlistCounts,
  });

  /// Map of pattern ID -> new version.
  final Map<String, int> patternBumps;

  /// New root meta.json version.
  final int newRootVersion;

  /// Map of pattern ID -> playlist count (for root meta update).
  final Map<String, int> playlistCounts;
}

/// Extracts unique pattern IDs from git diff output.
///
/// Parses lines like `patterns/coten_radio/playlists/regular.json`
/// and extracts `coten_radio`. Ignores root-level files (meta.json).
List<String> extractChangedPatternIds(
  String diffOutput,
  String patternsPrefix,
) {
  final prefix = patternsPrefix.endsWith('/')
      ? patternsPrefix
      : '$patternsPrefix/';
  final ids = <String>{};

  for (final line in diffOutput.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (!trimmed.startsWith(prefix)) continue;

    final rest = trimmed.substring(prefix.length);
    final slashIndex = rest.indexOf('/');
    if (0 > slashIndex) continue; // root-level file like meta.json

    ids.add(rest.substring(0, slashIndex));
  }

  return ids.toList();
}

/// Computes version bumps for changed patterns.
///
/// Reads previous versions and increments by 1.
/// New patterns (not in [previousVersions]) start at 1.
BumpResult computeVersionBumps({
  required List<String> changedPatternIds,
  required Map<String, int> previousVersions,
  int previousRootVersion = 0,
  required Map<String, int> currentPlaylistCounts,
}) {
  final bumps = <String, int>{};

  for (final id in changedPatternIds) {
    final previous = previousVersions[id];
    bumps[id] = (previous ?? 0) + 1;
  }

  return BumpResult(
    patternBumps: bumps,
    newRootVersion: previousRootVersion + 1,
    playlistCounts: currentPlaylistCounts,
  );
}

/// Runs `git diff` to detect changed files.
///
/// Returns the raw diff output as a string.
Future<String> gitDiff(String repoDir, String previousRef) async {
  final result = await Process.run(
    'git',
    ['diff', previousRef, '--name-only'],
    workingDirectory: repoDir,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      ['diff', previousRef, '--name-only'],
      'git diff failed: ${result.stderr}',
      result.exitCode,
    );
  }
  return result.stdout as String;
}

/// Reads a file from a previous git ref.
///
/// Returns null if the file doesn't exist at that ref.
Future<String?> gitShowFile(
  String repoDir,
  String ref,
  String filePath,
) async {
  final result = await Process.run(
    'git',
    ['show', '$ref:$filePath'],
    workingDirectory: repoDir,
  );
  if (result.exitCode != 0) return null;
  return result.stdout as String;
}

/// Applies version bumps to files on disk.
///
/// Updates each changed pattern's meta.json and the root meta.json.
Future<void> applyBumps({
  required String patternsDir,
  required BumpResult bumps,
  required Map<String, dynamic> currentRootMeta,
}) async {
  const encoder = JsonEncoder.withIndent('  ');

  // Update each changed pattern's meta.json
  for (final entry in bumps.patternBumps.entries) {
    final patternId = entry.key;
    final newVersion = entry.value;
    final metaFile = File('$patternsDir/$patternId/meta.json');
    if (!metaFile.existsSync()) continue;

    final meta =
        jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
    meta['version'] = newVersion;
    metaFile.writeAsStringSync('${encoder.convert(meta)}\n');
  }

  // Update root meta.json
  currentRootMeta['version'] = bumps.newRootVersion;
  final patterns = currentRootMeta['patterns'] as List<dynamic>;
  for (final pattern in patterns) {
    final p = pattern as Map<String, dynamic>;
    final id = p['id'] as String;
    if (bumps.patternBumps.containsKey(id)) {
      p['version'] = bumps.patternBumps[id];
    }
    if (bumps.playlistCounts.containsKey(id)) {
      p['playlistCount'] = bumps.playlistCounts[id];
    }
  }
  final rootMetaFile = File('$patternsDir/meta.json');
  rootMetaFile.writeAsStringSync('${encoder.convert(currentRootMeta)}\n');
}
```

**Step 4: Add export to library**

```dart
// packages/sp_cli/lib/sp_cli.dart
library;

export 'src/bump_command.dart';
export 'src/validate_command.dart';
```

**Step 5: Run test to verify it passes**

Run: `dart test packages/sp_cli/test/bump_command_test.dart`
Expected: PASS

**Step 6: Commit**

---

### Task 5: Add integration test for bump with temp git repo

**Files:**
- Create: `packages/sp_cli/test/bump_integration_test.dart`

**Step 1: Write the integration test**

```dart
// packages/sp_cli/test/bump_integration_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:sp_cli/sp_cli.dart';
import 'package:test/test.dart';

const _encoder = JsonEncoder.withIndent('  ');

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('bump_int_test_');
    // Initialize git repo
    _runGit(tempDir.path, ['init']);
    _runGit(tempDir.path, ['config', 'user.email', 'test@test.com']);
    _runGit(tempDir.path, ['config', 'user.name', 'Test']);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  void writeJson(String relativePath, Object data) {
    final file = File('${tempDir.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('${_encoder.convert(data)}\n');
  }

  group('bump_versions integration', () {
    test('bumps version for changed pattern', () async {
      // Create initial state and commit
      writeJson('patterns/meta.json', {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'version': 1,
            'displayName': 'Test',
            'feedUrlHint': 'test.com',
            'playlistCount': 1,
          },
        ],
      });
      writeJson('patterns/test/meta.json', {
        'version': 1,
        'id': 'test',
        'feedUrls': ['https://test.com/feed'],
        'playlists': ['main'],
      });
      writeJson('patterns/test/playlists/main.json', {
        'id': 'main',
        'displayName': 'Main',
        'resolverType': 'rss',
      });
      _runGit(tempDir.path, ['add', '-A']);
      _runGit(tempDir.path, ['commit', '-m', 'initial']);

      // Simulate a PR merge: modify a playlist
      writeJson('patterns/test/playlists/main.json', {
        'id': 'main',
        'displayName': 'Main Updated',
        'resolverType': 'rss',
      });
      _runGit(tempDir.path, ['add', '-A']);
      _runGit(tempDir.path, ['commit', '-m', 'update playlist']);

      // Run bump
      final diffOutput = await gitDiff(tempDir.path, 'HEAD~1');
      final changedIds =
          extractChangedPatternIds(diffOutput, 'patterns');
      expect(changedIds, equals(['test']));

      final prevRootContent = await gitShowFile(
        tempDir.path,
        'HEAD~1',
        'patterns/meta.json',
      );
      final prevRoot =
          jsonDecode(prevRootContent!) as Map<String, dynamic>;
      final prevRootVersion = prevRoot['version'] as int;

      final prevPatternContent = await gitShowFile(
        tempDir.path,
        'HEAD~1',
        'patterns/test/meta.json',
      );
      final prevPattern =
          jsonDecode(prevPatternContent!) as Map<String, dynamic>;

      final currentMeta = jsonDecode(
        File('${tempDir.path}/patterns/test/meta.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final playlistCount =
          (currentMeta['playlists'] as List).length;

      final bumps = computeVersionBumps(
        changedPatternIds: changedIds,
        previousVersions: {
          'test': prevPattern['version'] as int,
        },
        previousRootVersion: prevRootVersion,
        currentPlaylistCounts: {'test': playlistCount},
      );

      expect(bumps.patternBumps['test'], 2);
      expect(bumps.newRootVersion, 2);

      // Apply bumps
      final currentRootMeta = jsonDecode(
        File('${tempDir.path}/patterns/meta.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      await applyBumps(
        patternsDir: '${tempDir.path}/patterns',
        bumps: bumps,
        currentRootMeta: currentRootMeta,
      );

      // Verify files were updated
      final updatedRoot = jsonDecode(
        File('${tempDir.path}/patterns/meta.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(updatedRoot['version'], 2);
      expect(
        (updatedRoot['patterns'] as List)[0]['version'],
        2,
      );

      final updatedPattern = jsonDecode(
        File('${tempDir.path}/patterns/test/meta.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(updatedPattern['version'], 2);
    });
  });
}

void _runGit(String dir, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: dir);
  if (result.exitCode != 0) {
    throw Exception('git ${args.join(' ')} failed: ${result.stderr}');
  }
}
```

**Step 2: Run test to verify it passes**

Run: `dart test packages/sp_cli/test/bump_integration_test.dart`
Expected: PASS

**Step 3: Commit**

---

### Task 6: Create bump_versions CLI entry point

**Files:**
- Create: `packages/sp_cli/bin/bump_versions.dart`

**Step 1: Write the entry point**

```dart
// packages/sp_cli/bin/bump_versions.dart
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
    stderr.writeln('Error: Directory not found: $patternsDir');
    exit(2);
  }

  // Find the repo root (parent of patterns dir)
  final repoDir = Directory(patternsDir).parent.path;

  stderr.writeln('Detecting changes from $previousRef...');

  // 1. Detect changed patterns
  final diffOutput = await gitDiff(repoDir, previousRef);
  final changedIds = extractChangedPatternIds(diffOutput, 'patterns');

  if (changedIds.isEmpty) {
    stderr.writeln('No pattern changes detected. Nothing to bump.');
    exit(0);
  }

  stderr.writeln('  Changed patterns: ${changedIds.join(', ')}');

  // 2. Read previous versions from git history
  final previousVersions = <String, int>{};
  for (final id in changedIds) {
    final content = await gitShowFile(
      repoDir,
      previousRef,
      'patterns/$id/meta.json',
    );
    if (content != null) {
      final meta = jsonDecode(content) as Map<String, dynamic>;
      previousVersions[id] = meta['version'] as int;
    }
  }

  // Read previous root version
  var previousRootVersion = 0;
  final prevRootContent = await gitShowFile(
    repoDir,
    previousRef,
    'patterns/meta.json',
  );
  if (prevRootContent != null) {
    final prevRoot =
        jsonDecode(prevRootContent) as Map<String, dynamic>;
    previousRootVersion = prevRoot['version'] as int;
  }

  // 3. Get current playlist counts
  final playlistCounts = <String, int>{};
  for (final id in changedIds) {
    final metaFile = File('$patternsDir/$id/meta.json');
    if (metaFile.existsSync()) {
      final meta =
          jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      playlistCounts[id] = (meta['playlists'] as List).length;
    }
  }

  // 4. Compute bumps
  final bumps = computeVersionBumps(
    changedPatternIds: changedIds,
    previousVersions: previousVersions,
    previousRootVersion: previousRootVersion,
    currentPlaylistCounts: playlistCounts,
  );

  // 5. Apply bumps
  final currentRootMeta = jsonDecode(
    File('$patternsDir/meta.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  await applyBumps(
    patternsDir: patternsDir,
    bumps: bumps,
    currentRootMeta: currentRootMeta,
  );

  // 6. Print summary
  for (final entry in bumps.patternBumps.entries) {
    final prev = previousVersions[entry.key] ?? 0;
    stderr.writeln('  ${entry.key}: version $prev -> ${entry.value}');
  }
  stderr.writeln(
    '  Root meta: version $previousRootVersion -> ${bumps.newRootVersion}',
  );
  stderr.writeln('Version bump complete.');
}
```

**Step 2: Test against actual dev data repo (dry run)**

This cannot be tested destructively against the real repo. Verify it runs without error:

Run: `cd /Users/tohru/Documents/src/projects/audiflow/audiflow-smartplaylist-dev && git log --oneline -3`
Expected: Shows recent commits (to identify a valid ref for testing)

**Step 3: Commit**

---

## Phase 4: Quality Gates

### Task 7: Run full analysis and test suite

**Step 1: Format**

Run: `dart format packages/sp_cli`

**Step 2: Analyze**

Run: `dart analyze packages/sp_cli`
Expected: No issues

**Step 3: Run all sp_cli tests**

Run: `dart test packages/sp_cli`
Expected: ALL PASS

**Step 4: Run all workspace tests**

Run: `dart test packages/sp_shared && dart test packages/sp_server && dart test packages/sp_cli`
Expected: ALL PASS

**Step 5: Commit and bookmark**

```bash
jj bookmark move feat/sp-cli
```

---

## Phase 5: Data Repo Workflow Templates

### Task 8: Create workflow templates

**Files:**
- Create: `docs/workflows/validate.yml` (template for data repo)
- Create: `docs/workflows/bump-deploy.yml` (template for data repo)

These are templates to be copied into the data repo's `.github/workflows/` directory.
See the design document `docs/plans/2026-02-24-data-repo-ci-design.md` for the full workflow YAML.

**Step 1: Write validate.yml template**

Copy from design document Section "Workflow 1: validate.yml".

**Step 2: Write bump-deploy.yml template**

Copy from design document Section "Workflow 2: bump-deploy.yml".

**Step 3: Commit**

---

## Summary of Deliverables

| Phase | Package | What |
|-------|---------|------|
| 1 | sp_cli | Package scaffold + workspace registration |
| 2 | sp_cli | `validatePatterns()` + `bin/validate.dart` entry point |
| 3 | sp_cli | `computeVersionBumps()` + `applyBumps()` + `bin/bump_versions.dart` entry point |
| 4 | sp_cli | Format, analyze, test quality gates |
| 5 | docs | Workflow YAML templates for data repo |

## Key Notes for Implementer

- **RootMeta version check**: `RootMeta.parseJson()` enforces `version == 1`, but the data repo has `version: 2` (bumped by previous edits). The validator uses `RootMeta.fromJson()` (no version check) and parses PatternSummary entries manually instead.
- **Schema envelope**: The JSON Schema validates `{"version": 1, "patterns": [...]}` format. To validate an assembled config, wrap it in this envelope before calling `SmartPlaylistValidator.validate()`.
- **git operations**: The bump command shells out to `git` CLI. Tests use temp git repos with known history.
- **File encoding**: All JSON files are written with 2-space indent and trailing newline.
