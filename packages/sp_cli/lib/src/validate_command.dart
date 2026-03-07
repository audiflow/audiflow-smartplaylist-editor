import 'dart:convert';
import 'dart:io';

import 'package:sp_shared/sp_shared.dart';

/// An error found during config validation.
final class ValidationError {
  const ValidationError({required this.filePath, required this.message});

  final String filePath;
  final String message;

  @override
  String toString() => '$filePath: $message';
}

/// Validates all pattern configs under [patternsDir].
///
/// [patternsDir] is the path to the `patterns/` directory containing
/// `meta.json` at its root. Validates each file against its own schema:
/// 1. Root meta.json against pattern-index schema
/// 2. Per-pattern meta.json against pattern-meta schema
/// 3. Playlist definition files against playlist-definition schema
List<ValidationError> validatePatterns(String patternsDir) {
  final errors = <ValidationError>[];
  final rootMetaPath = '$patternsDir/meta.json';
  final validator = SmartPlaylistValidator();

  // Validate and parse root meta.json
  final rootJson = _readJsonFile(rootMetaPath, errors);
  if (rootJson == null) return errors;

  final rootSchemaErrors = validator.validatePatternIndex(rootJson);
  for (final message in rootSchemaErrors) {
    errors.add(
      ValidationError(filePath: rootMetaPath, message: 'schema: $message'),
    );
  }

  final summaries = _parseSummaries(rootMetaPath, rootJson, errors);
  if (summaries == null) return errors;

  for (final summary in summaries) {
    _validatePattern(patternsDir, summary.id, validator, errors);
  }
  return errors;
}

/// Reads and decodes a JSON file, appending errors on failure.
Map<String, dynamic>? _readJsonFile(String path, List<ValidationError> errors) {
  final file = File(path);
  if (!file.existsSync()) {
    errors.add(ValidationError(filePath: path, message: 'file not found'));
    return null;
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    errors.add(
      ValidationError(filePath: path, message: 'failed to parse JSON: $e'),
    );
    return null;
  }

  if (decoded is! Map<String, dynamic>) {
    errors.add(
      ValidationError(filePath: path, message: 'expected JSON object'),
    );
    return null;
  }

  return decoded;
}

/// Parses pattern summaries from root meta JSON.
List<PatternSummary>? _parseSummaries(
  String path,
  Map<String, dynamic> rootJson,
  List<ValidationError> errors,
) {
  final patterns = rootJson['patterns'];
  if (patterns is! List) {
    errors.add(
      ValidationError(filePath: path, message: 'missing patterns array'),
    );
    return null;
  }

  final summaries = <PatternSummary>[];
  for (final (index, entry) in patterns.indexed) {
    try {
      summaries.add(PatternSummary.fromJson(entry as Map<String, dynamic>));
    } on Object catch (e) {
      errors.add(
        ValidationError(
          filePath: '$path#patterns[$index]',
          message: 'failed to parse PatternSummary: $e',
        ),
      );
    }
  }
  return summaries;
}

/// Validates a single pattern: meta and playlists against their schemas.
void _validatePattern(
  String dataDir,
  String patternId,
  SmartPlaylistValidator validator,
  List<ValidationError> errors,
) {
  final patternDir = '$dataDir/$patternId';
  final metaPath = '$patternDir/meta.json';

  // Validate pattern meta against schema
  final metaJson = _readJsonFile(metaPath, errors);
  if (metaJson == null) return;

  final metaSchemaErrors = validator.validatePatternMeta(metaJson);
  for (final message in metaSchemaErrors) {
    errors.add(
      ValidationError(filePath: metaPath, message: 'schema: $message'),
    );
  }

  // Parse pattern meta to get playlist IDs
  final PatternMeta meta;
  try {
    meta = PatternMeta.fromJson(metaJson);
  } on Object catch (e) {
    errors.add(
      ValidationError(filePath: metaPath, message: 'failed to parse: $e'),
    );
    return;
  }

  // Validate each playlist definition against schema
  for (final playlistId in meta.playlists) {
    final playlistPath = '$patternDir/playlists/$playlistId.json';
    final playlistJson = _readJsonFile(playlistPath, errors);
    if (playlistJson == null) continue;

    final playlistErrors = validator.validatePlaylistDefinition(playlistJson);
    for (final message in playlistErrors) {
      errors.add(
        ValidationError(
          filePath: playlistPath,
          message: 'schema: $message',
        ),
      );
    }

    // Also verify the JSON parses as a valid model
    try {
      SmartPlaylistDefinition.fromJson(playlistJson);
    } on Object catch (e) {
      errors.add(
        ValidationError(
          filePath: playlistPath,
          message: 'failed to parse: $e',
        ),
      );
    }
  }
}
