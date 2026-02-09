import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/app/providers.dart';
import 'package:sp_web/main.dart' show initialOAuthToken;
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
  AuthState build() {
    // Consume the token extracted from the OAuth redirect
    // URL in main(). This runs before the widget tree
    // builds, so the initial state is already Authenticated.
    final token = initialOAuthToken;
    if (token != null) {
      initialOAuthToken = null;
      ref.read(apiClientProvider).setToken(token);
      return Authenticated(token: token);
    }
    return const Unauthenticated();
  }

  /// Redirects the browser to the server's GitHub
  /// OAuth endpoint to begin the login flow.
  ///
  /// Passes the current origin as `redirect_uri` so
  /// the server knows where to redirect after auth.
  void loginWithGitHub() {
    final apiClient = ref.read(apiClientProvider);
    final redirectUri = Uri.encodeComponent(
      '${web.window.location.origin}/login',
    );
    final url =
        '${apiClient.baseUrl}/api/auth/github'
        '?redirect_uri=$redirectUri';
    web.window.location.href = url;
  }

  /// Stores the JWT [token] received from the OAuth
  /// callback and updates the API client.
  void setToken(String token) {
    final apiClient = ref.read(apiClientProvider);
    apiClient.setToken(token);
    web.window.localStorage.setItem('auth_token', token);
    state = Authenticated(token: token);
  }

  /// Clears the stored token and returns to
  /// unauthenticated state.
  void logout() {
    final apiClient = ref.read(apiClientProvider);
    apiClient.clearToken();
    web.window.localStorage.removeItem('auth_token');
    state = const Unauthenticated();
  }
}

/// Provider for [AuthController].
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
