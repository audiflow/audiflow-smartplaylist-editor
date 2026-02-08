import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:sp_web/app/providers.dart';

/// State for the preview panel.
class PreviewState {
  const PreviewState({this.isLoading = false, this.result, this.error});

  /// Whether a preview request is in progress.
  final bool isLoading;

  /// Server response containing playlists, ungrouped, and debug info.
  final Map<String, dynamic>? result;

  /// Error message from the last preview attempt.
  final String? error;

  /// Whether results are available.
  bool get hasResult => result != null;

  /// Playlist entries from the result.
  List<dynamic> get playlists =>
      (result?['playlists'] as List<dynamic>?) ?? const [];

  /// Episodes that did not match any playlist.
  List<dynamic> get ungrouped =>
      (result?['ungrouped'] as List<dynamic>?) ?? const [];

  /// Debug statistics from the resolver run.
  Map<String, dynamic> get debug =>
      (result?['debug'] as Map<String, dynamic>?) ?? const {};

  PreviewState copyWith({
    bool? isLoading,
    Map<String, dynamic>? result,
    String? error,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return PreviewState(
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages preview state by sending the current config to the
/// server's preview endpoint and displaying the results.
class PreviewController extends Notifier<PreviewState> {
  @override
  PreviewState build() => const PreviewState();

  /// Fetches episodes from [feedUrl], then sends them with [config]
  /// to the preview endpoint and updates state with the result.
  Future<void> runPreview(
    SmartPlaylistPatternConfig config,
    String feedUrl,
  ) async {
    if (feedUrl.isEmpty) {
      state = state.copyWith(
        error: 'Please enter a feed URL first.',
        clearResult: true,
      );
      return;
    }

    final client = ref.read(apiClientProvider);
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Fetch episodes from the feed endpoint first.
      final encodedUrl = Uri.encodeQueryComponent(feedUrl);
      final feedResponse = await client.get('/api/feeds?url=$encodedUrl');
      if (feedResponse.statusCode != 200) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to fetch feed: ${feedResponse.statusCode}',
        );
        return;
      }

      final feedData =
          jsonDecode(feedResponse.body) as Map<String, dynamic>;
      final episodes = feedData['episodes'] as List<dynamic>? ?? const [];

      // Send config + episodes to the preview endpoint.
      final body = {'config': config.toJson(), 'episodes': episodes};
      final response = await client.post('/api/configs/preview', body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        state = state.copyWith(isLoading: false, result: data);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Preview failed: ${response.statusCode}',
        );
      }
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: 'Preview error: $e');
    }
  }

  /// Clears the current preview results.
  void clearPreview() {
    state = const PreviewState();
  }
}

/// Provider for [PreviewController].
final previewControllerProvider =
    NotifierProvider<PreviewController, PreviewState>(PreviewController.new);
