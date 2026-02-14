import 'dart:convert';
import 'dart:io';

const _encoder = JsonEncoder.withIndent('  ');

/// Splits a single SmartPlaylist JSON file into the new multi-file
/// directory structure.
///
/// Input format (single file):
/// ```json
/// {
///   "version": 1,
///   "patterns": [
///     {
///       "id": "pattern_id",
///       "feedUrls": [...],
///       "yearGroupedEpisodes": true,
///       "podcastGuid": "...",
///       "playlists": [{ "id": "...", ... }]
///     }
///   ]
/// }
/// ```
///
/// Output structure:
/// ```
/// outputDir/
///   meta.json          (root meta with pattern summaries)
///   pattern_id/
///     meta.json        (pattern meta with feed rules + playlist IDs)
///     playlists/
///       playlist1.json
///       playlist2.json
/// ```
void migrate(String jsonInput, String outputDir) {
  final data = jsonDecode(jsonInput) as Map<String, dynamic>;
  final patterns = data['patterns'] as List<dynamic>;

  final patternSummaries = <Map<String, dynamic>>[];

  for (final raw in patterns) {
    final pattern = raw as Map<String, dynamic>;
    final patternId = pattern['id'] as String;
    final playlists = pattern['playlists'] as List<dynamic>;
    final feedUrls =
        (pattern['feedUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final yearGrouped = (pattern['yearGroupedEpisodes'] as bool?) ?? false;
    final podcastGuid = pattern['podcastGuid'] as String?;

    final playlistDir = Directory('$outputDir/$patternId/playlists');
    playlistDir.createSync(recursive: true);

    final playlistIds = <String>[];
    for (final p in playlists) {
      final playlist = p as Map<String, dynamic>;
      final playlistId = playlist['id'] as String;
      playlistIds.add(playlistId);

      final file = File('$outputDir/$patternId/playlists/$playlistId.json');
      file.writeAsStringSync(_encoder.convert(playlist));
    }

    final patternMeta = <String, dynamic>{
      'version': 1,
      'id': patternId,
      if (podcastGuid != null) 'podcastGuid': podcastGuid,
      'feedUrls': feedUrls,
      if (yearGrouped) 'yearGroupedEpisodes': yearGrouped,
      'playlists': playlistIds,
    };
    File(
      '$outputDir/$patternId/meta.json',
    ).writeAsStringSync(_encoder.convert(patternMeta));

    final displayName = deriveDisplayName(patternId);
    final feedUrlHint = feedUrls.isNotEmpty ? feedUrls[0] : '';

    patternSummaries.add({
      'id': patternId,
      'version': 1,
      'displayName': displayName,
      'feedUrlHint': feedUrlHint,
      'playlistCount': playlistIds.length,
    });
  }

  final rootMeta = {'version': 1, 'patterns': patternSummaries};
  File('$outputDir/meta.json').writeAsStringSync(_encoder.convert(rootMeta));

  // ignore: avoid_print
  print('Migration complete:');
  // ignore: avoid_print
  print('  Patterns: ${patternSummaries.length}');
  for (final summary in patternSummaries) {
    // ignore: avoid_print
    print('  - ${summary['id']}: ${summary['playlistCount']} playlists');
  }
}

/// Converts a snake_case ID into a Title Case display name.
String deriveDisplayName(String id) {
  return id
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

void main(List<String> args) {
  if (args.length != 2) {
    // ignore: avoid_print
    print('Usage: dart run scripts/migrate.dart <input.json> <output_dir>');
    exit(1);
  }
  final input = File(args[0]).readAsStringSync();
  migrate(input, args[1]);
}
