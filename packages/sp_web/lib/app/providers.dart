import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/services/api_client.dart';

/// Base URL for the API server.
/// Override via --dart-define=API_URL=... at build time.
final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );
});

/// Provides the singleton [ApiClient] instance.
final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return ApiClient(baseUrl: baseUrl);
});
