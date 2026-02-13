import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sp_web/app/providers.dart';
import 'package:sp_web/main.dart'
    show initialOAuthRefreshToken, initialOAuthToken;
import 'package:web/web.dart' as web;

/// Authentication state.
sealed class AuthState {
  const AuthState();
}

/// User is not authenticated.
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// User is authenticated with a JWT token pair.
class Authenticated extends AuthState {
  const Authenticated({required this.token, required this.refreshToken});

  final String token;
  final String refreshToken;
}

/// Manages authentication state and JWT tokens.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Consume the tokens extracted from the OAuth
    // redirect URL in main(). This runs before the
    // widget tree builds, so the initial state is
    // already Authenticated.
    final token = initialOAuthToken;
    final refreshToken = initialOAuthRefreshToken;
    if (token != null && refreshToken != null) {
      initialOAuthToken = null;
      initialOAuthRefreshToken = null;
      final client = ref.read(apiClientProvider);
      client.setToken(token);
      client.setRefreshToken(refreshToken);
      return Authenticated(token: token, refreshToken: refreshToken);
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

  /// Stores the JWT token pair and updates the API
  /// client.
  void setTokens(String token, String refreshToken) {
    final apiClient = ref.read(apiClientProvider);
    apiClient.setToken(token);
    apiClient.setRefreshToken(refreshToken);
    web.window.localStorage.setItem('auth_token', token);
    web.window.localStorage.setItem('refresh_token', refreshToken);
    state = Authenticated(token: token, refreshToken: refreshToken);
  }

  /// Clears the stored tokens and returns to
  /// unauthenticated state.
  void logout() {
    final apiClient = ref.read(apiClientProvider);
    apiClient.clearToken();
    apiClient.clearRefreshToken();
    web.window.localStorage.removeItem('auth_token');
    web.window.localStorage.removeItem('refresh_token');
    state = const Unauthenticated();
  }
}

/// Provider for [AuthController].
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
