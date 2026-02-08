import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sp_web/features/auth/controllers/auth_controller.dart';
import 'package:sp_web/features/auth/screens/login_screen.dart';
import 'package:sp_web/features/editor/screens/editor_screen.dart';
import 'package:sp_web/features/settings/screens/settings_screen.dart';

/// Route paths used throughout the app.
abstract final class RoutePaths {
  static const login = '/login';
  static const editor = '/editor';
  static const settings = '/settings';
}

/// Notifier that triggers GoRouter redirect re-evaluation
/// when auth state changes.
class _AuthNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Provides the [GoRouter] instance with auth-aware
/// redirect logic.
///
/// Unauthenticated users are redirected to [RoutePaths.login].
/// Authenticated users on the login page are redirected
/// to [RoutePaths.editor].
///
/// When the login route receives a `token` query parameter
/// (from the OAuth callback), it is extracted and stored
/// in the [AuthController].
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier();

  ref.listen(authControllerProvider, (_, __) {
    authNotifier.notify();
  });

  return GoRouter(
    initialLocation: RoutePaths.login,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authControllerProvider) is Authenticated;
      final isLoginRoute = state.matchedLocation == RoutePaths.login;

      if (!isLoggedIn && !isLoginRoute) {
        return RoutePaths.login;
      }
      if (isLoggedIn && isLoginRoute) {
        return RoutePaths.editor;
      }

      return null;
    },
    routes: [
      GoRoute(path: RoutePaths.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: RoutePaths.editor,
        builder: (_, __) => const EditorScreen(),
      ),
      GoRoute(
        path: '${RoutePaths.editor}/:id',
        builder: (_, state) =>
            EditorScreen(configId: state.pathParameters['id']),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
  );
});
