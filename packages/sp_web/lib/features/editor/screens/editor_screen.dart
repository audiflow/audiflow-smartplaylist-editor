import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sp_web/features/editor/controllers/editor_controller.dart';
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

  Future<void> _handleSaveDraft() async {
    await ref.read(editorControllerProvider.notifier).saveDraft();
    if (!mounted) return;

    final editorState = ref.read(editorControllerProvider);
    if (editorState.error == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved successfully')));
    }
  }

  Future<void> _handleSubmitPr() async {
    final prUrl = await showDialog<String?>(
      context: context,
      builder: (_) => const SubmitDialog(),
    );
    if (!mounted) return;

    if (prUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PR created: $prUrl'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorControllerProvider);
    final theme = Theme.of(context);

    final title = widget.configId != null
        ? 'Edit: ${widget.configId}'
        : 'New Config';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
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
            onPressed: editorState.isSaving
                ? null
                : () {
                    ref.read(editorControllerProvider.notifier).saveConfig();
                  },
            icon: editorState.isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: editorState.isSavingDraft ? null : _handleSaveDraft,
            icon: editorState.isSavingDraft
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.drafts),
            label: const Text('Save Draft'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
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
    if (editorState.isJsonMode) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: JsonEditor(),
      );
    }
    return const ConfigForm();
  }
}
