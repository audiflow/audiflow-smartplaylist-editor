import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:sp_web/features/editor/controllers/editor_controller.dart';
import 'package:sp_web/features/editor/widgets/playlist_definition_form.dart';

/// Top-level form for editing a [SmartPlaylistPatternConfig].
///
/// Displays config-level fields (id, podcastGuid, feedUrlPatterns,
/// yearGroupedEpisodes) followed by a list of playlist definition
/// forms and an "Add Playlist" button.
class ConfigForm extends ConsumerStatefulWidget {
  const ConfigForm({super.key});

  @override
  ConsumerState<ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<ConfigForm> {
  late final TextEditingController _idController;
  late final TextEditingController _podcastGuidController;
  late final TextEditingController _feedUrlPatternsController;

  @override
  void initState() {
    super.initState();
    final config = ref.read(editorControllerProvider).config;
    _idController = TextEditingController(text: config?.id ?? '');
    _podcastGuidController = TextEditingController(
      text: config?.podcastGuid ?? '',
    );
    _feedUrlPatternsController = TextEditingController(
      text: config?.feedUrlPatterns?.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _podcastGuidController.dispose();
    _feedUrlPatternsController.dispose();
    super.dispose();
  }

  SmartPlaylistPatternConfig _buildConfig({
    bool? yearGroupedEpisodes,
    List<SmartPlaylistDefinition>? playlists,
  }) {
    final currentConfig = ref.read(editorControllerProvider).config;
    final patterns = _parseFeedUrlPatterns(_feedUrlPatternsController.text);

    return SmartPlaylistPatternConfig(
      id: _idController.text.trim(),
      podcastGuid: _nullIfEmpty(_podcastGuidController.text),
      feedUrlPatterns: patterns.isEmpty ? null : patterns,
      yearGroupedEpisodes:
          yearGroupedEpisodes ?? currentConfig?.yearGroupedEpisodes ?? false,
      playlists: playlists ?? currentConfig?.playlists ?? const [],
    );
  }

  void _onFieldChanged() {
    ref.read(editorControllerProvider.notifier).updateConfig(_buildConfig());
  }

  List<String> _parseFeedUrlPatterns(String text) {
    return text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorControllerProvider);
    final config = editorState.config;

    if (config == null) {
      return const Center(child: Text('No config loaded'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildConfigFields(config),
          const SizedBox(height: 24),
          Text(
            'Playlists (${config.playlists.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...List.generate(config.playlists.length, (index) {
            return PlaylistDefinitionForm(
              key: ValueKey('playlist-$index-${config.playlists[index].id}'),
              index: index,
              definition: config.playlists[index],
              onChanged: (updated) {
                ref
                    .read(editorControllerProvider.notifier)
                    .updatePlaylist(index, updated);
              },
              onDelete: () {
                ref
                    .read(editorControllerProvider.notifier)
                    .removePlaylist(index);
              },
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(editorControllerProvider.notifier).addPlaylist();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Playlist'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigFields(SmartPlaylistPatternConfig config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Config Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Config ID',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _onFieldChanged(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _podcastGuidController,
              decoration: const InputDecoration(
                labelText: 'Podcast GUID (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _onFieldChanged(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedUrlPatternsController,
              decoration: const InputDecoration(
                labelText: 'Feed URL Patterns (comma-separated)',
                hintText: 'pattern1, pattern2',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _onFieldChanged(),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Year Grouped Episodes'),
              value: config.yearGroupedEpisodes,
              onChanged: (value) {
                ref
                    .read(editorControllerProvider.notifier)
                    .updateConfig(
                      _buildConfig(yearGroupedEpisodes: value ?? false),
                    );
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
