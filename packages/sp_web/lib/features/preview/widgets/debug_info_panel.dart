import 'package:flutter/material.dart';

/// Compact card displaying debug statistics from a preview run.
///
/// Shows total, grouped, and ungrouped episode counts plus
/// the resolver types used across playlists.
class DebugInfoPanel extends StatelessWidget {
  const DebugInfoPanel({
    super.key,
    required this.debug,
    required this.playlists,
  });

  /// Debug statistics map from the server response.
  final Map<String, dynamic> debug;

  /// Playlist entries used to extract resolver types.
  final List<dynamic> playlists;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalEpisodes = debug['totalEpisodes'] as int? ?? 0;
    final groupedEpisodes = debug['groupedEpisodes'] as int? ?? 0;
    final ungroupedEpisodes = debug['ungroupedEpisodes'] as int? ?? 0;
    final resolverTypes = _extractResolverTypes();

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug Info',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _StatRow(label: 'Total episodes', value: '$totalEpisodes'),
            _StatRow(label: 'Grouped', value: '$groupedEpisodes'),
            _StatRow(label: 'Ungrouped', value: '$ungroupedEpisodes'),
            const Divider(height: 16),
            _ResolverTypesRow(resolverTypes: resolverTypes),
          ],
        ),
      ),
    );
  }

  List<String> _extractResolverTypes() {
    final types = <String>{};
    for (final playlist in playlists) {
      if (playlist is Map<String, dynamic>) {
        final type = playlist['resolverType'] as String?;
        if (type != null) {
          types.add(type);
        }
      }
    }
    return types.toList()..sort();
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolverTypesRow extends StatelessWidget {
  const _ResolverTypesRow({required this.resolverTypes});

  final List<String> resolverTypes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resolver types', style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final type in resolverTypes)
              Chip(
                label: Text(type),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSecondaryContainer,
                ),
                backgroundColor: colorScheme.secondaryContainer,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ],
    );
  }
}
