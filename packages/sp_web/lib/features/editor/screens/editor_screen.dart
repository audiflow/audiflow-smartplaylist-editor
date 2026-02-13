import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sp_web/features/editor/controllers/editor_controller.dart';
import 'package:sp_web/services/local_draft_service.dart';
import 'package:sp_web/features/editor/widgets/config_form.dart';
import 'package:sp_web/features/editor/widgets/feed_url_input.dart';
import 'package:sp_web/features/editor/widgets/json_editor.dart';
import 'package:sp_web/features/editor/widgets/submit_dialog.dart';
import 'package:sp_web/features/preview/widgets/preview_panel.dart';
import 'package:sp_web/routing/app_router.dart';

/// Minimum width (in logical pixels) for the side-by-side layout.
const _kSideBySideBreakpoint = 600.0;

/// Main editor screen for creating and editing SmartPlaylist configs.
///
/// On wide screens (600+ px), shows the editor and preview panel
/// side by side. On narrow screens, uses a tabbed layout with
/// an "Editor" and "Preview" tab.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.configId});

  /// Optional config ID for editing an existing config.
  final String? configId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Defer to after build so the notifier is ready.
    Future.microtask(_initializeEditor);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeEditor() {
    final controller = ref.read(editorControllerProvider.notifier);
    if (widget.configId != null) {
      controller.loadConfig(widget.configId!);
    } else {
      controller.createNew();
    }
  }

  Future<void> _handleSubmitPr() async {
    final prUrl = await showDialog<String?>(
      context: context,
      builder: (_) => const SubmitDialog(),
    );
    if (!mounted) return;

    if (prUrl != null) {
      ref.read(editorControllerProvider.notifier).clearDraftOnSubmit();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PR created: $prUrl'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _showRestoreDialog(DraftEntry draft) async {
    final savedAt = DateTime.tryParse(draft.savedAt);
    final timeText = savedAt != null
        ? '${savedAt.toLocal().hour.toString().padLeft(2, '0')}'
              ':${savedAt.toLocal().minute.toString().padLeft(2, '0')}'
        : draft.savedAt;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes Found'),
        content: Text(
          'You have unsaved changes from $timeText. '
          'Would you like to restore them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    final controller = ref.read(editorControllerProvider.notifier);
    if (result == true) {
      await controller.restoreDraft();
    } else {
      controller.discardDraft();
    }
  }

  String _formatAutoSaveTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return 'Auto-saved '
        '${dt.hour.toString().padLeft(2, '0')}'
        ':${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorControllerProvider);
    final theme = Theme.of(context);

    // Listen for pending draft changes to show restore dialog.
    ref.listen<EditorState>(editorControllerProvider, (previous, next) {
      if (previous?.pendingDraft == null && next.pendingDraft != null) {
        _showRestoreDialog(next.pendingDraft!);
      }
    });

    final title = widget.configId != null
        ? 'Edit: ${widget.configId}'
        : 'New Config';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // Auto-save indicator
          if (editorState.lastAutoSavedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  _formatAutoSaveTime(editorState.lastAutoSavedAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          // Form / JSON toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Form')),
              ButtonSegment(value: true, label: Text('JSON')),
            ],
            selected: {editorState.isJsonMode},
            onSelectionChanged: (selection) {
              ref.read(editorControllerProvider.notifier).toggleJsonMode();
            },
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: editorState.isSubmitting ? null : _handleSubmitPr,
            icon: editorState.isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Submit PR'),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(RoutePaths.settings),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error banner
          if (editorState.error != null)
            MaterialBanner(
              content: Text(editorState.error!),
              backgroundColor: theme.colorScheme.errorContainer,
              actions: [
                TextButton(
                  onPressed: () {
                    ref
                        .read(editorControllerProvider.notifier)
                        .updateConfig(editorState.config!);
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          // Feed URL input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: const FeedUrlInput(),
          ),
          const Divider(height: 24),
          // Loading indicator
          if (editorState.isLoadingConfig)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_kSideBySideBreakpoint <= constraints.maxWidth) {
                    return _buildSideBySideLayout(editorState);
                  }
                  return _buildTabbedLayout(editorState);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Wide layout: editor on the left, preview on the right.
  Widget _buildSideBySideLayout(EditorState editorState) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildEditorContent(editorState)),
        const VerticalDivider(width: 1),
        Expanded(child: const PreviewPanel()),
      ],
    );
  }

  /// Narrow layout: tabbed editor and preview.
  Widget _buildTabbedLayout(EditorState editorState) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Editor'),
            Tab(text: 'Preview'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildEditorContent(editorState), const PreviewPanel()],
          ),
        ),
      ],
    );
  }

  /// The form or JSON editor content area.
  Widget _buildEditorContent(EditorState editorState) {
    // Use configVersion as Key so form widgets re-create their
    // TextEditingControllers when a draft is restored.
    final formKey = ValueKey(editorState.configVersion);
    if (editorState.isJsonMode) {
      return Padding(
        key: formKey,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: const JsonEditor(),
      );
    }
    return ConfigForm(key: formKey);
  }
}
