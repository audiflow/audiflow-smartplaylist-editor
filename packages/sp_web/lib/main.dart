import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/app/app.dart';
import 'package:sp_web/app/providers.dart';
import 'package:sp_web/features/auth/controllers/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Extract OAuth token from the URL before the app builds,
  // so auth state is already set when the router initializes.
  final uri = Uri.base;
  final token = uri.queryParameters['token'];

  final container = ProviderContainer();
  if (token != null && token.isNotEmpty) {
    final apiClient = container.read(apiClientProvider);
    apiClient.setToken(token);
    container.read(authControllerProvider.notifier).setToken(token);
  }

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
