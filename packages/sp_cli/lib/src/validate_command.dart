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
/// `meta.json` at its root. Validates four levels:
/// 1. Root meta.json structure
/// 2. Per-pattern meta.json files
/// 3. Playlist definition files
/// 4. Assembled config against JSON Schema
List<ValidationError> validatePatterns(String patternsDir) {
  final errors = <ValidationError>[];
  final rootMetaPath = '$patternsDir/meta.json';

  final summaries = _parseRootMeta(rootMetaPath, errors);
  if (summaries == null) return errors;

  for (final summary in summaries) {
    _validatePattern(patternsDir, summary.id, errors);
  }
  return errors;
}

/// Parses root meta.json, appending errors and returning null on failure.
List<PatternSummary>? _parseRootMeta(
  String path,
  List<ValidationError> errors,
) {
  final decoded = _readJsonFile(path, errors);
  if (decoded == null) return null;

  final patterns = decoded['patterns'];
  if (patterns is! List) {
    errors.add(
      ValidationError(filePath: path, message: 'missing patterns array'),
    );
    return null;
  }

  return _parseSummaries(path, patterns, errors);
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

/// Parses each entry in the patterns array as a [PatternSummary].
List<PatternSummary> _parseSummaries(
  String path,
  List<dynamic> patterns,
  List<ValidationError> errors,
) {
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

/// Validates a single pattern: meta, playlists, and schema.
void _validatePattern(
  String dataDir,
  String patternId,
  List<ValidationError> errors,
) {
  final patternDir = '$dataDir/$patternId';
  final metaPath = '$patternDir/meta.json';

  final meta = _parsePatternMeta(metaPath, errors);
  if (meta == null) return;

  final playlists = _loadPlaylists(patternDir, meta.playlists, errors);
  if (playlists == null) return;

  _validateSchema(metaPath, meta, playlists, errors);
}

/// Parses a pattern-level meta.json.
PatternMeta? _parsePatternMeta(String path, List<ValidationError> errors) {
  final file = File(path);
  if (!file.existsSync()) {
    errors.add(ValidationError(filePath: path, message: 'file not found'));
    return null;
  }

  try {
    return PatternMeta.parseJson(file.readAsStringSync());
  } on Object catch (e) {
    errors.add(ValidationError(filePath: path, message: 'failed to parse: $e'));
    return null;
  }
}

/// Loads and parses all playlist definitions for a pattern.
///
/// Returns null if any playlist file is missing or unparseable.
List<SmartPlaylistDefinition>? _loadPlaylists(
  String patternDir,
  List<String> playlistIds,
  List<ValidationError> errors,
) {
  final definitions = <SmartPlaylistDefinition>[];
  var hasFailure = false;

  for (final id in playlistIds) {
    final path = '$patternDir/playlists/$id.json';
    final definition = _parsePlaylist(path, errors);
    if (definition == null) {
      hasFailure = true;
    } else {
      definitions.add(definition);
    }
  }

  return hasFailure ? null : definitions;
}

/// Parses a single playlist definition file.
SmartPlaylistDefinition? _parsePlaylist(
  String path,
  List<ValidationError> errors,
) {
  final file = File(path);
  if (!file.existsSync()) {
    errors.add(ValidationError(filePath: path, message: 'file not found'));
    return null;
  }

  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return SmartPlaylistDefinition.fromJson(json);
  } on Object catch (e) {
    errors.add(ValidationError(filePath: path, message: 'failed to parse: $e'));
    return null;
  }
}

/// Assembles the config and validates against JSON Schema.
void _validateSchema(
  String metaPath,
  PatternMeta meta,
  List<SmartPlaylistDefinition> playlists,
  List<ValidationError> errors,
) {
  final assembled = ConfigAssembler.assemble(meta, playlists);
  final envelope = {
    'version': 1,
    'patterns': [assembled.toJson()],
  };

  final validator = SmartPlaylistValidator();
  final schemaErrors = validator.validate(envelope);
  for (final message in schemaErrors) {
    errors.add(
      ValidationError(filePath: metaPath, message: 'schema: $message'),
    );
  }
}
