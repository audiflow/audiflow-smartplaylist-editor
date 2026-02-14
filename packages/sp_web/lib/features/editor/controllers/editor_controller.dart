import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:sp_web/app/providers.dart';
import 'package:sp_web/features/preview/controllers/preview_controller.dart';
import 'package:sp_web/services/json_merge.dart';
import 'package:sp_web/services/local_draft_service.dart';

/// State for the editor screen.
class EditorState {
  const EditorState({
    this.config,
    this.configJson = '',
    this.configVersion = 0,
    this.isJsonMode = false,
    this.feedUrl,
    this.isLoadingFeed = false,
    this.isLoadingConfig = false,
    this.isSubmitting = false,
    this.lastAutoSavedAt,
    this.pendingDraft,
    this.error,
  });

  /// The current config being edited.
  final SmartPlaylistPatternConfig? config;

  /// Raw JSON text representation.
  final String configJson;

  /// Incremented when the config is externally replaced (e.g. draft restore)
  /// so form widgets can use it as a Key to re-initialize their controllers.
  final int configVersion;

  /// Whether the editor is in raw JSON mode.
  final bool isJsonMode;

  /// Feed URL entered by the user.
  final String? feedUrl;

  /// Whether a feed is currently being loaded.
  final bool isLoadingFeed;

  /// Whether a config is being loaded from the server.
  final bool isLoadingConfig;

  /// Whether a PR submission is in progress.
  final bool isSubmitting;

  /// ISO-8601 timestamp of the last auto-save, if any.
  final String? lastAutoSavedAt;

  /// Pending draft awaiting user decision (restore or discard).
  final DraftEntry? pendingDraft;

  /// Current error message, if any.
  final String? error;

  EditorState copyWith({
    SmartPlaylistPatternConfig? config,
    String? configJson,
    int? configVersion,
    bool? isJsonMode,
    String? feedUrl,
    bool? isLoadingFeed,
    bool? isLoadingConfig,
    bool? isSubmitting,
    String? lastAutoSavedAt,
    DraftEntry? pendingDraft,
    String? error,
    bool clearError = false,
    bool clearConfig = false,
    bool clearPendingDraft = false,
    bool clearLastAutoSavedAt = false,
  }) {
    return EditorState(
      config: clearConfig ? null : (config ?? this.config),
      configJson: configJson ?? this.configJson,
      configVersion: configVersion ?? this.configVersion,
      isJsonMode: isJsonMode ?? this.isJsonMode,
      feedUrl: feedUrl ?? this.feedUrl,
      isLoadingFeed: isLoadingFeed ?? this.isLoadingFeed,
      isLoadingConfig: isLoadingConfig ?? this.isLoadingConfig,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      lastAutoSavedAt: clearLastAutoSavedAt
          ? null
          : (lastAutoSavedAt ?? this.lastAutoSavedAt),
      pendingDraft: clearPendingDraft
          ? null
          : (pendingDraft ?? this.pendingDraft),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages editor state including config, JSON mode toggle,
/// auto-save to localStorage, and server interactions.
class EditorController extends Notifier<EditorState> {
  /// The config as loaded from the server, used as the merge base.
  Map<String, dynamic>? _baseConfigJson;

  /// The config ID being edited (null for new configs).
  String? _configId;

  Timer? _debounceTimer;

  static const _debounceDuration = Duration(seconds: 2);

  @override
  EditorState build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return const EditorState();
  }

  /// Creates a new empty config with default values.
  void createNew() {
    final config = SmartPlaylistPatternConfig(id: '', playlists: const []);
    final json = _formatJson(config.toJson());
    _baseConfigJson = config.toJson();
    _configId = null;
    state = EditorState(config: config, configJson: json);

    _checkForDraft();
  }

  /// Updates the config from form changes.
  void updateConfig(SmartPlaylistPatternConfig config) {
    state = state.copyWith(
      config: config,
      configJson: _formatJson(config.toJson()),
      clearError: true,
    );
    _scheduleAutoSave();
  }

  /// Updates the raw JSON text.
  void updateJson(String json) {
    state = state.copyWith(configJson: json, clearError: true);
    _scheduleAutoSave();
  }

  /// Toggles between form and JSON editing modes.
  void toggleJsonMode() {
    if (state.isJsonMode) {
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
      final json = state.config != null
          ? _formatJson(state.config!.toJson())
          : state.configJson;
      state = state.copyWith(isJsonMode: true, configJson: json);
    }
  }

  /// Loads an existing config from the server by [configId].
  Future<void> loadConfig(String configId) async {
    _configId = configId;
    final client = ref.read(apiClientProvider);
    state = state.copyWith(isLoadingConfig: true, clearError: true);

    try {
      final response = await client.get(
        '/api/configs/patterns/$configId/assembled',
      );
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        _baseConfigJson = map;
        final config = SmartPlaylistPatternConfig.fromJson(map);
        state = state.copyWith(
          config: config,
          configJson: _formatJson(config.toJson()),
          isLoadingConfig: false,
        );
        _checkForDraft();

        final urls = config.feedUrls;
        if (urls != null && urls.isNotEmpty) {
          unawaited(loadFeed(urls.first));
        }
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
        state = state.copyWith(isLoadingFeed: false);
        // Auto-run preview when config is available.
        final config = state.config;
        if (config != null) {
          unawaited(
            ref
                .read(previewControllerProvider.notifier)
                .runPreview(config, feedUrl),
          );
        }
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
      feedUrls: config.feedUrls,
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
      feedUrls: config.feedUrls,
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
      feedUrls: config.feedUrls,
      yearGroupedEpisodes: config.yearGroupedEpisodes,
      playlists: playlists,
    );

    updateConfig(updated);
  }

  /// Restores the pending draft by merging with the latest server config.
  Future<void> restoreDraft() async {
    final draft = state.pendingDraft;
    if (draft == null) return;

    final latestJson = _baseConfigJson;
    if (latestJson == null) return;

    final merged = JsonMerge.merge(
      base: draft.base,
      latest: latestJson,
      modified: draft.modified,
    );

    try {
      final config = SmartPlaylistPatternConfig.fromJson(merged);
      state = state.copyWith(
        config: config,
        configJson: _formatJson(config.toJson()),
        configVersion: state.configVersion + 1,
        clearPendingDraft: true,
        clearError: true,
      );
    } on Object catch (e) {
      state = state.copyWith(
        error: 'Failed to restore draft: $e',
        clearPendingDraft: true,
      );
    }
  }

  /// Discards the pending draft without applying it.
  void discardDraft() {
    final draftService = ref.read(localDraftServiceProvider);
    draftService.clearDraft(_configId);
    state = state.copyWith(clearPendingDraft: true);
  }

  /// Clears the draft after a successful PR submission.
  void clearDraftOnSubmit() {
    final draftService = ref.read(localDraftServiceProvider);
    draftService.clearDraft(_configId);
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

  // -- Private helpers --

  void _scheduleAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _performAutoSave);
  }

  void _performAutoSave() {
    final config = state.config;
    final baseJson = _baseConfigJson;
    if (config == null || baseJson == null) return;

    // Validate JSON is parseable before saving.
    final modifiedJson = config.toJson();

    final draftService = ref.read(localDraftServiceProvider);
    draftService.saveDraft(
      configId: _configId,
      base: baseJson,
      modified: modifiedJson,
    );

    state = state.copyWith(
      lastAutoSavedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  void _checkForDraft() {
    final draftService = ref.read(localDraftServiceProvider);
    final draft = draftService.loadDraft(_configId);
    if (draft != null) {
      state = state.copyWith(pendingDraft: draft);
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
