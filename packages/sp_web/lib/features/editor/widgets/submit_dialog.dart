import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/features/editor/controllers/editor_controller.dart';
import 'package:web/web.dart' as web;

/// Confirmation dialog for submitting a SmartPlaylist config as a
/// GitHub pull request.
///
/// Returns the PR URL on success, or null if cancelled.
class SubmitDialog extends ConsumerStatefulWidget {
  const SubmitDialog({super.key});

  @override
  ConsumerState<SubmitDialog> createState() => _SubmitDialogState();
}

class _SubmitDialogState extends ConsumerState<SubmitDialog> {
  bool _isSubmitting = false;
  String? _prUrl;
  String? _error;

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final controller = ref.read(editorControllerProvider.notifier);
    final prUrl = await controller.submitAsPr();

    if (!mounted) return;

    if (prUrl != null) {
      setState(() {
        _isSubmitting = false;
        _prUrl = prUrl;
      });
    } else {
      final editorState = ref.read(editorControllerProvider);
      setState(() {
        _isSubmitting = false;
        _error = editorState.error ?? 'Unknown error occurred';
      });
    }
  }

  void _openPrUrl() {
    if (_prUrl == null) return;
    web.window.open(_prUrl!, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorControllerProvider);
    final theme = Theme.of(context);

    // Success state: show the PR URL
    if (_prUrl != null) {
      return AlertDialog(
        icon: Icon(Icons.check_circle, color: theme.colorScheme.primary),
        title: const Text('PR Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your pull request has been created successfully.'),
            const SizedBox(height: 16),
            InkWell(
              onTap: _openPrUrl,
              child: Text(
                _prUrl!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_prUrl),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: _openPrUrl,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open PR'),
          ),
        ],
      );
    }

    final configId = editorState.config?.id ?? '(new)';
    final feedUrl = editorState.feedUrl ?? '(none)';

    return AlertDialog(
      icon: const Icon(Icons.send),
      title: const Text('Submit as Pull Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Config ID: $configId', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('Feed URL: $feedUrl', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(
            'This will create a pull request on GitHub with your '
            'SmartPlaylist configuration.',
            style: theme.textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _handleSubmit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(_error != null ? 'Retry' : 'Submit'),
        ),
      ],
    );
  }
}
