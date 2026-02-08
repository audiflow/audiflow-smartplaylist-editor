import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/app/providers.dart';
import 'package:web/web.dart' as web;

/// Authentication state.
sealed class AuthState {
  const AuthState();
}

/// User is not authenticated.
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// User is authenticated with a JWT token.
class Authenticated extends AuthState {
  const Authenticated({required this.token});

  final String token;
}

/// Manages authentication state and JWT tokens.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const Unauthenticated();

  /// Redirects the browser to the server's GitHub
  /// OAuth endpoint to begin the login flow.
  void loginWithGitHub() {
    final apiClient = ref.read(apiClientProvider);
    final url = '${apiClient.baseUrl}/api/auth/github';
    web.window.location.href = url;
  }

  /// Stores the JWT [token] received from the OAuth
  /// callback and updates the API client.
  void setToken(String token) {
    final apiClient = ref.read(apiClientProvider);
    apiClient.setToken(token);
    state = Authenticated(token: token);
  }

  /// Clears the stored token and returns to
  /// unauthenticated state.
  void logout() {
    final apiClient = ref.read(apiClientProvider);
    apiClient.clearToken();
    state = const Unauthenticated();
  }
}

/// Provider for [AuthController].
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
