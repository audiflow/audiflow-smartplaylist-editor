import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/features/editor/controllers/editor_controller.dart';

/// Input widget for selecting or entering a podcast feed URL and
/// loading it.
///
/// When the config has [feedUrls], shows a dropdown populated from
/// those URLs. Otherwise falls back to a free-text TextField.
class FeedUrlInput extends ConsumerStatefulWidget {
  const FeedUrlInput({super.key});

  @override
  ConsumerState<FeedUrlInput> createState() => _FeedUrlInputState();
}

class _FeedUrlInputState extends ConsumerState<FeedUrlInput> {
  final _controller = TextEditingController();
  String? _selectedUrl;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLoadFeed() {
    final url = _selectedUrl ?? _controller.text.trim();
    if (url.isEmpty) return;
    ref.read(editorControllerProvider.notifier).loadFeed(url);
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorControllerProvider);
    final feedUrls = editorState.config?.feedUrls ?? [];
    final isLoading = editorState.isLoadingFeed;

    return Row(
      children: [
        Expanded(
          child: feedUrls.isEmpty
              ? TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Feed URL',
                    hintText: 'https://example.com/feed.xml',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _onLoadFeed(),
                )
              : DropdownButtonFormField<String>(
                  initialValue: _selectedUrl ?? feedUrls.first,
                  decoration: const InputDecoration(
                    labelText: 'Feed URL',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: feedUrls
                      .map(
                        (url) => DropdownMenuItem(
                          value: url,
                          child: Text(url, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedUrl = value);
                    if (value != null) {
                      ref
                          .read(editorControllerProvider.notifier)
                          .loadFeed(value);
                    }
                  },
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
