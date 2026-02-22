import 'dart:convert';
import 'dart:io';

import 'package:sp_shared/sp_shared.dart';

/// Repository that reads and writes split config files from
/// the local filesystem.
///
/// Replaces the HTTP-based [ConfigRepository] for local-first
/// operation. Files are stored under `$dataDir/patterns/`.
class LocalConfigRepository {
  LocalConfigRepository({required String dataDir})
    : _patternsDir = '$dataDir/patterns';

  final String _patternsDir;

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  // -- Read methods --

  /// Lists all pattern summaries from root meta.json.
  Future<List<PatternSummary>> listPatterns() async {
    final raw = await _readFile('$_patternsDir/meta.json');
    final rootMeta = RootMeta.parseJson(raw);
    return rootMeta.patterns;
  }

  /// Gets pattern metadata for a specific pattern.
  Future<PatternMeta> getPatternMeta(String patternId) async {
    final raw = await _readFile('$_patternsDir/$patternId/meta.json');
    return PatternMeta.parseJson(raw);
  }

  /// Gets a single playlist definition by pattern and playlist ID.
  Future<SmartPlaylistDefinition> getPlaylist(
    String patternId,
    String playlistId,
  ) async {
    final path = '$_patternsDir/$patternId/playlists/$playlistId.json';
    final raw = await _readFile(path);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return SmartPlaylistDefinition.fromJson(json);
  }

  /// Assembles a full config from pattern meta and all playlists.
  ///
  /// Fetches the pattern meta, then reads each playlist referenced
  /// in the meta, and assembles them using [ConfigAssembler].
  Future<SmartPlaylistPatternConfig> assembleConfig(String patternId) async {
    final meta = await getPatternMeta(patternId);

    final playlists = <SmartPlaylistDefinition>[];
    for (final playlistId in meta.playlists) {
      playlists.add(await getPlaylist(patternId, playlistId));
    }

    return ConfigAssembler.assemble(meta, playlists);
  }

  // -- Write methods --

  /// Writes playlist JSON to disk using atomic write.
  Future<void> savePlaylist(
    String patternId,
    String playlistId,
    Map<String, dynamic> json,
  ) async {
    final path = '$_patternsDir/$patternId/playlists/$playlistId.json';
    await _atomicWrite(path, json);
  }

  /// Writes pattern meta JSON to disk using atomic write.
  Future<void> savePatternMeta(
    String patternId,
    Map<String, dynamic> json,
  ) async {
    final path = '$_patternsDir/$patternId/meta.json';
    await _atomicWrite(path, json);
  }

  /// Creates a new pattern directory with playlists/ subdir and
  /// writes the initial meta.json.
  Future<void> createPattern(
    String patternId,
    Map<String, dynamic> metaJson,
  ) async {
    final patternDir = Directory('$_patternsDir/$patternId');
    await patternDir.create(recursive: true);

    final playlistsDir = Directory('$_patternsDir/$patternId/playlists');
    await playlistsDir.create();

    await _atomicWrite('$_patternsDir/$patternId/meta.json', metaJson);
  }

  /// Deletes a playlist file from disk.
  ///
  /// Throws [FileSystemException] if the file does not exist.
  Future<void> deletePlaylist(String patternId, String playlistId) async {
    final file = File(
      '$_patternsDir/$patternId/playlists/$playlistId.json',
    );
    if (!await file.exists()) {
      throw FileSystemException(
        'Playlist file not found',
        file.path,
      );
    }
    await file.delete();
  }

  /// Deletes an entire pattern directory recursively.
  ///
  /// Throws [FileSystemException] if the directory does not exist.
  Future<void> deletePattern(String patternId) async {
    final dir = Directory('$_patternsDir/$patternId');
    if (!await dir.exists()) {
      throw FileSystemException(
        'Pattern directory not found',
        dir.path,
      );
    }
    await dir.delete(recursive: true);
  }

  // -- Private helpers --

  /// Reads file contents as a string.
  ///
  /// Throws [FileSystemException] if the file does not exist.
  Future<String> _readFile(String path) async {
    final file = File(path);
    return file.readAsString();
  }

  /// Writes JSON to a file atomically: write to .tmp first, then
  /// rename to the target path.
  ///
  /// Output is pretty-printed with 2-space indent and a trailing
  /// newline.
  Future<void> _atomicWrite(
    String path,
    Map<String, dynamic> json,
  ) async {
    final content = '${_jsonEncoder.convert(json)}\n';
    final tmpPath = '$path.tmp';
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsString(content);
    await tmpFile.rename(path);
  }
}
