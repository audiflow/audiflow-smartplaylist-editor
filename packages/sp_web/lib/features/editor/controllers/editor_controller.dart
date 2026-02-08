import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:sp_web/app/providers.dart';

/// State for the editor screen.
class EditorState {
  const EditorState({
    this.config,
    this.configJson = '',
    this.isJsonMode = false,
    this.feedUrl,
    this.isLoadingFeed = false,
    this.isLoadingConfig = false,
    this.isSaving = false,
    this.isSavingDraft = false,
    this.isSubmitting = false,
    this.error,
  });

  /// The current config being edited.
  final SmartPlaylistPatternConfig? config;

  /// Raw JSON text representation.
  final String configJson;

  /// Whether the editor is in raw JSON mode.
  final bool isJsonMode;

  /// Feed URL entered by the user.
  final String? feedUrl;

  /// Whether a feed is currently being loaded.
  final bool isLoadingFeed;

  /// Whether a config is being loaded from the server.
  final bool isLoadingConfig;

  /// Whether the config is being saved.
  final bool isSaving;

  /// Whether a draft is currently being saved.
  final bool isSavingDraft;

  /// Whether a PR submission is in progress.
  final bool isSubmitting;

  /// Current error message, if any.
  final String? error;

  EditorState copyWith({
    SmartPlaylistPatternConfig? config,
    String? configJson,
    bool? isJsonMode,
    String? feedUrl,
    bool? isLoadingFeed,
    bool? isLoadingConfig,
    bool? isSaving,
    bool? isSavingDraft,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool clearConfig = false,
  }) {
    return EditorState(
      config: clearConfig ? null : (config ?? this.config),
      configJson: configJson ?? this.configJson,
      isJsonMode: isJsonMode ?? this.isJsonMode,
      feedUrl: feedUrl ?? this.feedUrl,
      isLoadingFeed: isLoadingFeed ?? this.isLoadingFeed,
      isLoadingConfig: isLoadingConfig ?? this.isLoadingConfig,
      isSaving: isSaving ?? this.isSaving,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages editor state including config, JSON mode toggle,
/// and server interactions.
class EditorController extends Notifier<EditorState> {
  @override
  EditorState build() => const EditorState();

  /// Creates a new empty config with default values.
  void createNew() {
    final config = SmartPlaylistPatternConfig(id: '', playlists: const []);
    final json = _formatJson(config.toJson());
    state = EditorState(config: config, configJson: json);
  }

  /// Updates the config from form changes.
  void updateConfig(SmartPlaylistPatternConfig config) {
    state = state.copyWith(
      config: config,
      configJson: _formatJson(config.toJson()),
      clearError: true,
    );
  }

  /// Updates the raw JSON text.
  void updateJson(String json) {
    state = state.copyWith(configJson: json, clearError: true);
  }

  /// Toggles between form and JSON editing modes.
  ///
  /// When switching from JSON to form, parses the JSON and
  /// updates the config. When switching from form to JSON,
  /// serializes the config.
  void toggleJsonMode() {
    if (state.isJsonMode) {
      // Switching from JSON to form: parse JSON
      try {
        final map = jsonDecode(state.configJson) as Map<String, dynamic>;
        final config = SmartPlaylistPatternConfig.fromJson(map);
        state = state.copyWith(
          isJsonMode: false,
          config: config,
          clearError: true,
        );
      } on FormatException catch (e) {
        state = state.copyWith(error: 'Invalid JSON: ${e.message}');
      } on Object catch (e) {
        state = state.copyWith(error: 'Parse error: $e');
      }
    } else {
      // Switching from form to JSON: serialize config
      final json = state.config != null
          ? _formatJson(state.config!.toJson())
          : state.configJson;
      state = state.copyWith(isJsonMode: true, configJson: json);
    }
  }

  /// Loads an existing config from the server by [configId].
  Future<void> loadConfig(String configId) async {
    final client = ref.read(apiClientProvider);
    state = state.copyWith(isLoadingConfig: true, clearError: true);

    try {
      final response = await client.get(
        '/api/configs/patterns/$configId/assembled',
      );
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final config = SmartPlaylistPatternConfig.fromJson(map);
        state = state.copyWith(
          config: config,
          configJson: _formatJson(config.toJson()),
          isLoadingConfig: false,
        );
      } else {
        state = state.copyWith(
          isLoadingConfig: false,
          error: 'Failed to load config: ${response.statusCode}',
        );
      }
    } on Object catch (e) {
      state = state.copyWith(
        isLoadingConfig: false,
        error: 'Failed to load config: $e',
      );
    }
  }

  /// Loads a feed from the server to populate initial config.
  Future<void> loadFeed(String feedUrl) async {
    final client = ref.read(apiClientProvider);
    state = state.copyWith(
      feedUrl: feedUrl,
      isLoadingFeed: true,
      clearError: true,
    );

    try {
      final encodedUrl = Uri.encodeQueryComponent(feedUrl);
      final response = await client.get('/api/feeds?url=$encodedUrl');
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        // The feed response may contain config data or feed metadata.
        // For now, just store the JSON for reference.
        state = state.copyWith(
          isLoadingFeed: false,
          configJson: _formatJson(map),
        );
      } else {
        state = state.copyWith(
          isLoadingFeed: false,
          error: 'Failed to load feed: ${response.statusCode}',
        );
      }
    } on Object catch (e) {
      state = state.copyWith(
        isLoadingFeed: false,
        error: 'Failed to load feed: $e',
      );
    }
  }

  /// Saves the current config to the server.
  Future<void> saveConfig() async {
    final config = state.config;
    if (config == null) return;

    final client = ref.read(apiClientProvider);
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final body = config.toJson();
      final response = config.id.isNotEmpty
          ? await client.put('/api/configs/${config.id}', body: body)
          : await client.post('/api/configs', body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        state = state.copyWith(isSaving: false);
      } else {
        state = state.copyWith(
          isSaving: false,
          error: 'Failed to save: ${response.statusCode}',
        );
      }
    } on Object catch (e) {
      state = state.copyWith(isSaving: false, error: 'Failed to save: $e');
    }
  }

  /// Adds a new empty playlist definition to the config.
  void addPlaylist() {
    final config = state.config;
    if (config == null) return;

    final newPlaylist = SmartPlaylistDefinition(
      id: 'playlist-${config.playlists.length + 1}',
      displayName: 'New Playlist',
      resolverType: 'rss',
    );

    final updated = SmartPlaylistPatternConfig(
      id: config.id,
      podcastGuid: config.podcastGuid,
      feedUrlPatterns: config.feedUrlPatterns,
      yearGroupedEpisodes: config.yearGroupedEpisodes,
      playlists: [...config.playlists, newPlaylist],
    );

    updateConfig(updated);
  }

  /// Removes the playlist at [index] from the config.
  void removePlaylist(int index) {
    final config = state.config;
    if (config == null) return;
    if (index < 0 || config.playlists.length <= index) return;

    final playlists = [...config.playlists]..removeAt(index);
    final updated = SmartPlaylistPatternConfig(
      id: config.id,
      podcastGuid: config.podcastGuid,
      feedUrlPatterns: config.feedUrlPatterns,
      yearGroupedEpisodes: config.yearGroupedEpisodes,
      playlists: playlists,
    );

    updateConfig(updated);
  }

  /// Updates a specific playlist definition at [index].
  void updatePlaylist(int index, SmartPlaylistDefinition playlist) {
    final config = state.config;
    if (config == null) return;
    if (index < 0 || config.playlists.length <= index) return;

    final playlists = [...config.playlists];
    playlists[index] = playlist;
    final updated = SmartPlaylistPatternConfig(
      id: config.id,
      podcastGuid: config.podcastGuid,
      feedUrlPatterns: config.feedUrlPatterns,
      yearGroupedEpisodes: config.yearGroupedEpisodes,
      playlists: playlists,
    );

    updateConfig(updated);
  }

  /// Saves the current config as a draft.
  Future<void> saveDraft() async {
    final config = state.config;
    if (config == null) return;

    final client = ref.read(apiClientProvider);
    state = state.copyWith(isSavingDraft: true, clearError: true);

    try {
      final body = <String, dynamic>{
        'feedUrl': state.feedUrl ?? '',
        'config': config.toJson(),
      };
      final response = await client.post('/api/drafts', body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        state = state.copyWith(isSavingDraft: false);
      } else {
        state = state.copyWith(
          isSavingDraft: false,
          error: 'Failed to save draft: ${response.statusCode}',
        );
      }
    } on Object catch (e) {
      state = state.copyWith(
        isSavingDraft: false,
        error: 'Failed to save draft: $e',
      );
    }
  }

  /// Submits the current config as a PR.
  ///
  /// Returns the PR URL on success, or null on failure.
  Future<String?> submitAsPr() async {
    final config = state.config;
    if (config == null) return null;

    final client = ref.read(apiClientProvider);
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final body = <String, dynamic>{
        'config': config.toJson(),
        'feedUrl': state.feedUrl ?? '',
      };
      final response = await client.post('/api/configs/submit', body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final prUrl = data['prUrl'] as String?;
        state = state.copyWith(isSubmitting: false);
        return prUrl;
      } else {
        state = state.copyWith(
          isSubmitting: false,
          error: 'Failed to submit PR: ${response.statusCode}',
        );
        return null;
      }
    } on Object catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Failed to submit PR: $e',
      );
      return null;
    }
  }

  String _formatJson(Map<String, dynamic> map) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(map);
  }
}

/// Provider for [EditorController].
final editorControllerProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);
