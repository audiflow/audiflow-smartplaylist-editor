import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/features/editor/controllers/editor_controller.dart';

/// Raw JSON text editor for the SmartPlaylist config.
///
/// Displays the config as formatted JSON with inline
/// validation error feedback.
class JsonEditor extends ConsumerStatefulWidget {
  const JsonEditor({super.key});

  @override
  ConsumerState<JsonEditor> createState() => _JsonEditorState();
}

class _JsonEditorState extends ConsumerState<JsonEditor> {
  late final TextEditingController _controller;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final json = ref.read(editorControllerProvider).configJson;
    _controller = TextEditingController(text: json);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(editorControllerProvider.notifier).updateJson(value);
    _validate(value);
  }

  void _validate(String value) {
    if (value.trim().isEmpty) {
      setState(() => _validationError = null);
      return;
    }
    try {
      jsonDecode(value);
      setState(() => _validationError = null);
    } on FormatException catch (e) {
      setState(() => _validationError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_validationError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _validationError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        Expanded(
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
              hintText: '{\n  "id": "...",\n  "playlists": []\n}',
            ),
          ),
        ),
      ],
    );
  }
}
