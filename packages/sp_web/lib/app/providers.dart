import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/features/auth/controllers/auth_controller.dart';
import 'package:sp_web/services/api_client.dart';
import 'package:sp_web/services/local_draft_service.dart';
import 'package:sp_web/services/web_storage_access.dart';

/// Base URL for the API server.
/// Override via --dart-define=API_URL=... at build time.
final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );
});

/// Provides the singleton [ApiClient] instance.
///
/// Wires up automatic logout on 401 responses so the
/// user is redirected to login when the token expires.
final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final client = ApiClient(baseUrl: baseUrl);
  client.onUnauthorized = () {
    ref.read(authControllerProvider.notifier).logout();
  };
  client.onTokensRefreshed = (accessToken, refreshToken) {
    ref
        .read(authControllerProvider.notifier)
        .setTokens(accessToken, refreshToken);
  };
  return client;
});

/// Provides the singleton [LocalDraftService] instance.
final localDraftServiceProvider = Provider<LocalDraftService>((ref) {
  return const LocalDraftService(storage: WebStorageAccess());
});
