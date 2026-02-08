import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:sp_web/app/providers.dart';

/// State for the browse screen.
class BrowseState {
  const BrowseState({
    this.patterns = const [],
    this.isLoading = false,
    this.error,
  });

  final List<PatternSummary> patterns;
  final bool isLoading;
  final String? error;

  BrowseState copyWith({
    List<PatternSummary>? patterns,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return BrowseState(
      patterns: patterns ?? this.patterns,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages browse screen state including fetching
/// and displaying pattern summaries.
class BrowseController extends Notifier<BrowseState> {
  @override
  BrowseState build() => const BrowseState();

  /// Fetches pattern summaries from the server.
  Future<void> loadPatterns() async {
    final client = ref.read(apiClientProvider);
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await client.get('/api/configs/patterns');
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        final patterns = list
            .whereType<Map<String, dynamic>>()
            .map(PatternSummary.fromJson)
            .toList();
        state = state.copyWith(patterns: patterns, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load patterns: ${response.statusCode}',
        );
      }
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load patterns: $e',
      );
    }
  }
}

/// Provider for [BrowseController].
final browseControllerProvider =
    NotifierProvider<BrowseController, BrowseState>(BrowseController.new);
