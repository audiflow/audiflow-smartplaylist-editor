import 'package:sp_server/src/services/local_config_repository.dart';

import 'tool_definition.dart';

/// Searches SmartPlaylist configs by keyword.
///
/// Reads patterns from the local data repo and filters by id,
/// displayName, or feedUrlHint.
const searchConfigsTool = ToolDefinition(
  name: 'search_configs',
  description: 'Search SmartPlaylist configs by keyword',
  inputSchema: {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': 'Search keyword to filter configs',
      },
    },
  },
);

/// Executes the search_configs tool.
Future<Map<String, dynamic>> executeSearchConfigs(
  LocalConfigRepository repo,
  Map<String, dynamic> arguments,
) async {
  final query = (arguments['query'] as String? ?? '').toLowerCase();
  final patterns = await repo.listPatterns();
  final filtered = query.isEmpty
      ? patterns
      : patterns.where((p) {
          return p.id.toLowerCase().contains(query) ||
              p.displayName.toLowerCase().contains(query) ||
              p.feedUrlHint.toLowerCase().contains(query);
        }).toList();
  return {'configs': filtered.map((p) => p.toJson()).toList()};
}
