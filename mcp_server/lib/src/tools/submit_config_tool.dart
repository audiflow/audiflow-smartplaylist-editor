import 'dart:convert';

import 'package:sp_server/src/services/local_config_repository.dart';
import 'package:sp_shared/sp_shared.dart';

import 'tool_definition.dart';

/// Saves a config to disk in the local data repo.
///
/// Validates the config, then writes each playlist file and
/// pattern meta using [LocalConfigRepository].
const submitConfigTool = ToolDefinition(
  name: 'submit_config',
  description: 'Save a config to disk',
  inputSchema: {
    'type': 'object',
    'properties': {
      'config': {
        'type': 'object',
        'description': 'The SmartPlaylist config to submit',
      },
      'configId': {
        'type': 'string',
        'description': 'The unique identifier for the config',
      },
      'description': {
        'type': 'string',
        'description': 'Description for the PR',
      },
    },
    'required': ['config', 'configId'],
  },
);

/// Executes the submit_config tool.
///
/// Throws [ArgumentError] if the required parameters are missing.
Future<Map<String, dynamic>> executeSubmitConfig(
  LocalConfigRepository repo,
  SmartPlaylistValidator validator,
  Map<String, dynamic> arguments,
) async {
  final config = arguments['config'];
  if (config is! Map<String, dynamic>) {
    throw ArgumentError('Missing or invalid required parameter: config');
  }
  final configId = arguments['configId'] as String?;
  if (configId == null || configId.isEmpty) {
    throw ArgumentError('Missing required parameter: configId');
  }

  // Wrap in root schema envelope for validation, since the
  // validator expects {version, patterns} at the top level.
  final envelope = {
    'version': 1,
    'patterns': [config],
  };
  final errors = validator.validateString(jsonEncode(envelope));
  if (errors.isNotEmpty) {
    return {'success': false, 'errors': errors};
  }

  // Parse and save each playlist (model round-trip normalizes JSON)
  final patternConfig = SmartPlaylistPatternConfig.fromJson(config);
  for (final playlist in patternConfig.playlists) {
    await repo.savePlaylist(configId, playlist.id, playlist.toJson());
  }

  // Sync pattern meta: preserve existing version, update other fields
  final existingPatternMeta = await repo.getPatternMetaJson(configId);
  final updatedPatternMeta = <String, dynamic>{
    ...existingPatternMeta,
    'id': configId,
    'feedUrls': patternConfig.feedUrls ?? existingPatternMeta['feedUrls'],
    'playlists': patternConfig.playlists.map((p) => p.id).toList(),
    'yearGroupedEpisodes': patternConfig.yearGroupedEpisodes,
  };
  updatedPatternMeta['version'] = existingPatternMeta['version'];
  await repo.savePatternMeta(configId, updatedPatternMeta);

  // Sync root meta: update playlistCount, preserve all versions
  final rootMeta = await repo.getRootMetaJson();
  final patterns = rootMeta['patterns'] as List<dynamic>;
  for (var i = 0; i < patterns.length; i++) {
    final entry = patterns[i] as Map<String, dynamic>;
    if (entry['id'] == configId) {
      patterns[i] = <String, dynamic>{
        ...entry,
        'playlistCount': patternConfig.playlists.length,
      };
      break;
    }
  }
  await repo.saveRootMeta(rootMeta);

  return {'success': true, 'patternId': configId};
}
