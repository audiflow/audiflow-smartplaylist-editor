import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/app/providers.dart';

/// State for the settings screen.
class SettingsState {
  const SettingsState({
    this.keys = const [],
    this.isLoading = false,
    this.newlyGeneratedKey,
    this.error,
  });

  /// List of API keys belonging to the current user.
  final List<Map<String, dynamic>> keys;

  /// Whether the key list is currently loading.
  final bool isLoading;

  /// Full key string shown once after generation.
  final String? newlyGeneratedKey;

  /// Current error message, if any.
  final String? error;

  SettingsState copyWith({
    List<Map<String, dynamic>>? keys,
    bool? isLoading,
    String? newlyGeneratedKey,
    String? error,
    bool clearNewKey = false,
    bool clearError = false,
  }) {
    return SettingsState(
      keys: keys ?? this.keys,
      isLoading: isLoading ?? this.isLoading,
      newlyGeneratedKey: clearNewKey
          ? null
          : (newlyGeneratedKey ?? this.newlyGeneratedKey),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages API key state: listing, generating, and
/// revoking keys.
class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  /// Fetches the user's API keys from the server.
  Future<void> loadKeys() async {
    final client = ref.read(apiClientProvider);
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await client.get('/api/keys');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawKeys = body['keys'] as List<dynamic>;
        final keys = rawKeys
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        state = state.copyWith(keys: keys, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load keys: ${response.statusCode}',
        );
      }
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load keys: $e',
      );
    }
  }

  /// Generates a new API key on the server.
  ///
  /// The full key is stored in [SettingsState.newlyGeneratedKey]
  /// and shown to the user once.
  Future<void> generateKey() async {
    final client = ref.read(apiClientProvider);
    state = state.copyWith(clearError: true);

    try {
      final response = await client.post('/api/keys');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final fullKey = body['key'] as String;
        state = state.copyWith(newlyGeneratedKey: fullKey);
        // Refresh the key list to include the new entry.
        await loadKeys();
      } else {
        state = state.copyWith(
          error: 'Failed to generate key: ${response.statusCode}',
        );
      }
    } on Object catch (e) {
      state = state.copyWith(error: 'Failed to generate key: $e');
    }
  }

  /// Revokes the API key with the given [id].
  Future<void> revokeKey(String id) async {
    final client = ref.read(apiClientProvider);
    state = state.copyWith(clearError: true);

    try {
      final response = await client.delete('/api/keys/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await loadKeys();
      } else {
        state = state.copyWith(
          error: 'Failed to revoke key: ${response.statusCode}',
        );
      }
    } on Object catch (e) {
      state = state.copyWith(error: 'Failed to revoke key: $e');
    }
  }

  /// Hides the newly generated key banner.
  void clearNewKey() {
    state = state.copyWith(clearNewKey: true);
  }
}

/// Provider for [SettingsController].
final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
