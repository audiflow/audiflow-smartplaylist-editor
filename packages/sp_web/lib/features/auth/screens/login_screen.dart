import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/features/auth/controllers/auth_controller.dart';

/// Login screen with GitHub OAuth sign-in button.
///
/// After the OAuth flow completes, the server redirects
/// back to this route with a token query parameter that
/// is handled by the router.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('SmartPlaylist Editor', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Create and manage podcast '
              'smart playlists',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                ref.read(authControllerProvider.notifier).loginWithGitHub();
              },
              icon: const Icon(Icons.login),
              label: const Text('Sign in with GitHub'),
            ),
          ],
        ),
      ),
    );
  }
}
