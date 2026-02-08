import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/features/editor/controllers/editor_controller.dart';

/// Input widget for entering a podcast feed URL and loading it.
class FeedUrlInput extends ConsumerStatefulWidget {
  const FeedUrlInput({super.key});

  @override
  ConsumerState<FeedUrlInput> createState() => _FeedUrlInputState();
}

class _FeedUrlInputState extends ConsumerState<FeedUrlInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLoadFeed() {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    ref.read(editorControllerProvider.notifier).loadFeed(url);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      editorControllerProvider.select((s) => s.isLoadingFeed),
    );

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Feed URL',
              hintText: 'https://example.com/feed.xml',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _onLoadFeed(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: isLoading ? null : _onLoadFeed,
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: const Text('Load Feed'),
        ),
      ],
    );
  }
}
