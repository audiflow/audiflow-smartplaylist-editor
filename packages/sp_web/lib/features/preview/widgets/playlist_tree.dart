import 'package:flutter/material.dart';

/// Expandable tree widget displaying playlists, their groups,
/// and episodes from a preview result.
///
/// Structure:
/// - Level 1: Playlist name + resolver type badge
/// - Level 2: Group name + episode count
/// - Level 3: Episode titles
class PlaylistTree extends StatelessWidget {
  const PlaylistTree({super.key, required this.playlists});

  /// List of playlist maps from the server response.
  final List<dynamic> playlists;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No playlists in result.'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index] as Map<String, dynamic>;
        return _PlaylistTile(playlist: playlist);
      },
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist});

  final Map<String, dynamic> playlist;

  @override
  Widget build(BuildContext context) {
    final displayName = playlist['displayName'] as String? ?? 'Unnamed';
    final resolverType = playlist['resolverType'] as String? ?? 'unknown';
    final groups = (playlist['groups'] as List<dynamic>?) ?? const <dynamic>[];
    final theme = Theme.of(context);

    return ExpansionTile(
      leading: const Icon(Icons.queue_music, size: 20),
      title: Row(
        children: [
          Flexible(child: Text(displayName, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          _ResolverBadge(resolverType: resolverType),
        ],
      ),
      subtitle: Text(
        '${groups.length} group${groups.length == 1 ? '' : 's'}',
        style: theme.textTheme.bodySmall,
      ),
      initiallyExpanded: true,
      children: [
        for (final group in groups)
          _GroupTile(group: group as Map<String, dynamic>),
      ],
    );
  }
}

class _ResolverBadge extends StatelessWidget {
  const _ResolverBadge({required this.resolverType});

  final String resolverType;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        resolverType,
        style: TextStyle(fontSize: 11, color: colorScheme.onSecondaryContainer),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final Map<String, dynamic> group;

  @override
  Widget build(BuildContext context) {
    final displayName = group['displayName'] as String? ?? 'Ungrouped';
    final episodes = (group['episodes'] as List<dynamic>?) ?? const <dynamic>[];
    final theme = Theme.of(context);

    return ExpansionTile(
      leading: const SizedBox(width: 20),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName,
              style: theme.textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${episodes.length})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      children: [
        for (final episode in episodes)
          _EpisodeItem(episode: episode as Map<String, dynamic>),
      ],
    );
  }
}

class _EpisodeItem extends StatelessWidget {
  const _EpisodeItem({required this.episode});

  final Map<String, dynamic> episode;

  @override
  Widget build(BuildContext context) {
    final title = episode['title'] as String? ?? 'Untitled';
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 56),
      leading: Icon(
        Icons.audiotrack,
        size: 16,
        color: theme.colorScheme.outline,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodySmall,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
