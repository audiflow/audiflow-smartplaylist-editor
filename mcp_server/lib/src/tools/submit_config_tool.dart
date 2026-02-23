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

  // Parse and save each playlist
  final patternConfig = SmartPlaylistPatternConfig.fromJson(config);
  for (final playlist in patternConfig.playlists) {
    await repo.savePlaylist(configId, playlist.id, playlist.toJson());
  }

  return {'success': true, 'patternId': configId};
}
