import 'dart:convert';
import 'dart:io';

/// Creates a temporary data directory with the specified test data
/// for use in MCP server tests.
///
/// Returns the path to the created temp directory. Callers should
/// delete the directory in tearDown using [cleanupDataDir].
Future<String> createTestDataDir({
  List<Map<String, dynamic>> patterns = const [],
  Map<String, Map<String, dynamic>> patternMetas = const {},
  Map<String, Map<String, Map<String, dynamic>>> playlists = const {},
  Map<String, dynamic>? schema,
}) async {
  final dir = await Directory.systemTemp.createTemp('mcp_test_');
  final dataDir = dir.path;

  // Write root meta.json
  final patternsDir = Directory('$dataDir/patterns');
  await patternsDir.create(recursive: true);

  final rootMeta = {
    'version': 1,
    'patterns': patterns,
  };
  await _writeJson('$dataDir/patterns/meta.json', rootMeta);

  // Write pattern metas and playlists
  for (final entry in patternMetas.entries) {
    final patternId = entry.key;
    final meta = entry.value;

    final patternDir = Directory('$dataDir/patterns/$patternId/playlists');
    await patternDir.create(recursive: true);
    await _writeJson('$dataDir/patterns/$patternId/meta.json', meta);
  }

  for (final patternEntry in playlists.entries) {
    final patternId = patternEntry.key;
    for (final playlistEntry in patternEntry.value.entries) {
      final playlistId = playlistEntry.key;
      final playlistJson = playlistEntry.value;

      final playlistDir = Directory(
        '$dataDir/patterns/$patternId/playlists',
      );
      if (!await playlistDir.exists()) {
        await playlistDir.create(recursive: true);
      }
      await _writeJson(
        '$dataDir/patterns/$patternId/playlists/$playlistId.json',
        playlistJson,
      );
    }
  }

  // Write schema if provided
  if (schema != null) {
    final schemaDir = Directory('$dataDir/schema');
    await schemaDir.create(recursive: true);
    await _writeJson('$dataDir/schema/schema.json', schema);
  }

  return dataDir;
}

/// Removes a temporary data directory created by [createTestDataDir].
Future<void> cleanupDataDir(String dataDir) async {
  final dir = Directory(dataDir);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}

Future<void> _writeJson(String path, Object json) async {
  const encoder = JsonEncoder.withIndent('  ');
  await File(path).writeAsString('${encoder.convert(json)}\n');
}
