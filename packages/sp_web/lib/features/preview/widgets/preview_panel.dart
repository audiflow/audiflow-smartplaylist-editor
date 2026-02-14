import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/features/editor/controllers/editor_controller.dart';
import 'package:sp_web/features/preview/controllers/preview_controller.dart';
import 'package:sp_web/features/preview/widgets/debug_info_panel.dart';
import 'package:sp_web/features/preview/widgets/playlist_tree.dart';

/// Main preview wrapper that contains the run button,
/// playlist tree results, and debug info panel.
class PreviewPanel extends ConsumerWidget {
  const PreviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewState = ref.watch(previewControllerProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, ref, previewState),
        const Divider(height: 1),
        Expanded(child: _buildContent(context, previewState, theme)),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    PreviewState previewState,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text('Preview', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          FilledButton.icon(
            onPressed: previewState.isLoading ? null : () => _runPreview(ref),
            icon: previewState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Run Preview'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PreviewState previewState,
    ThemeData theme,
  ) {
    if (previewState.error != null) {
      return _buildError(context, previewState.error!, theme);
    }

    if (previewState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!previewState.hasResult) {
      return _buildEmptyState(theme);
    }

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PlaylistTree(playlists: previewState.playlists),
            const SizedBox(height: 12),
            if (previewState.ungrouped.isNotEmpty) ...[
              _buildUngroupedSection(previewState.ungrouped, theme),
              const SizedBox(height: 12),
            ],
            DebugInfoPanel(
              debug: previewState.debug,
              playlists: previewState.playlists,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            SelectableText(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.preview, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Click "Run Preview" to see how your\n'
              'config resolves episodes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUngroupedSection(List<dynamic> ungrouped, ThemeData theme) {
    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      child: ExpansionTile(
        leading: Icon(
          Icons.warning_amber_rounded,
          color: theme.colorScheme.error,
          size: 20,
        ),
        title: Text(
          'Ungrouped Episodes (${ungrouped.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        children: [
          for (final episode in ungrouped)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 56),
              title: Text(
                (episode as Map<String, dynamic>)['title'] as String? ??
                    'Untitled',
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }

  void _runPreview(WidgetRef ref) {
    final editorState = ref.read(editorControllerProvider);
    final config = editorState.config;
    final feedUrl = editorState.feedUrl ?? '';

    if (config == null) return;

    ref.read(previewControllerProvider.notifier).runPreview(config, feedUrl);
  }
}
