import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:sp_web/features/browse/controllers/browse_controller.dart';
import 'package:sp_web/routing/app_router.dart';

/// Browse screen for discovering and selecting patterns.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(browseControllerProvider.notifier).loadPatterns();
    });
  }

  @override
  Widget build(BuildContext context) {
    final browseState = ref.watch(browseControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push(RoutePaths.editor),
            tooltip: 'Create New',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(RoutePaths.settings),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(browseState, theme),
    );
  }

  Widget _buildBody(BrowseState browseState, ThemeData theme) {
    if (browseState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (browseState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              browseState.error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(browseControllerProvider.notifier).loadPatterns();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (browseState.patterns.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No patterns found'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push(RoutePaths.editor),
              icon: const Icon(Icons.add),
              label: const Text('Create New'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: browseState.patterns.length,
      itemBuilder: (context, index) {
        return _PatternCard(pattern: browseState.patterns[index]);
      },
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.pattern});

  final PatternSummary pattern;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(pattern.displayName, style: theme.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pattern.feedUrlHint,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${pattern.playlistCount} playlist'
              '${pattern.playlistCount != 1 ? 's' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push('${RoutePaths.editor}/${pattern.id}');
        },
      ),
    );
  }
}
