import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// HTTP client wrapper for API calls.
///
/// Handles authentication headers, JSON
/// encoding/decoding, and silent token refresh
/// for all requests.
///
/// When the access token expires (401), the client
/// attempts to refresh it using the stored refresh
/// token. If refresh fails, [onUnauthorized] is
/// called so the app can redirect to login.
class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
  String? _token;
  String? _refreshToken;

  /// Called when authentication fails permanently
  /// (no refresh token or refresh itself failed).
  void Function()? onUnauthorized;

  /// Called when a silent refresh succeeds with a new
  /// token pair, so the auth controller can persist them.
  void Function(String accessToken, String refreshToken)? onTokensRefreshed;

  /// Deduplicates concurrent refresh attempts.
  Completer<bool>? _refreshing;

  /// Sets the JWT access token for authenticated
  /// requests.
  void setToken(String token) {
    _token = token;
  }

  /// Clears the stored JWT access token.
  void clearToken() {
    _token = null;
  }

  /// Sets the JWT refresh token.
  void setRefreshToken(String token) {
    _refreshToken = token;
  }

  /// Clears the stored refresh token.
  void clearRefreshToken() {
    _refreshToken = null;
  }

  /// Whether an access token is currently stored.
  bool get hasToken => _token != null;

  /// Sends a GET request to [path].
  Future<http.Response> get(String path) {
    return _send(
      () => http.get(Uri.parse('$baseUrl$path'), headers: _buildHeaders()),
    );
  }

  /// Sends a POST request to [path] with optional
  /// JSON [body].
  Future<http.Response> post(String path, {Map<String, dynamic>? body}) {
    return _send(
      () => http.post(
        Uri.parse('$baseUrl$path'),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Sends a PUT request to [path] with optional
  /// JSON [body].
  Future<http.Response> put(String path, {Map<String, dynamic>? body}) {
    return _send(
      () => http.put(
        Uri.parse('$baseUrl$path'),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Sends a DELETE request to [path].
  Future<http.Response> delete(String path) {
    return _send(
      () => http.delete(Uri.parse('$baseUrl$path'), headers: _buildHeaders()),
    );
  }

  /// Executes [request], and on 401 attempts a silent
  /// refresh before retrying once.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final response = await request();
    if (response.statusCode != 401) return response;

    // No refresh token: fail immediately.
    if (_refreshToken == null) {
      _token = null;
      onUnauthorized?.call();
      return response;
    }

    // Attempt refresh (deduplicated).
    final refreshed = await _tryRefresh();
    if (!refreshed) {
      _token = null;
      _refreshToken = null;
      onUnauthorized?.call();
      return response;
    }

    // Retry the original request with the new token.
    return request();
  }

  /// Posts to `/api/auth/refresh` and updates tokens on
  /// success. Returns `true` if the refresh succeeded.
  ///
  /// Concurrent callers share a single in-flight refresh
  /// via [_refreshing].
  Future<bool> _tryRefresh() async {
    if (_refreshing != null) return _refreshing!.future;

    final completer = Completer<bool>();
    _refreshing = completer;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );

      if (response.statusCode != 200) {
        completer.complete(false);
        return false;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final newAccess = body['accessToken'] as String;
      final newRefresh = body['refreshToken'] as String;

      _token = newAccess;
      _refreshToken = newRefresh;
      onTokensRefreshed?.call(newAccess, newRefresh);

      completer.complete(true);
      return true;
    } on Object {
      completer.complete(false);
      return false;
    } finally {
      _refreshing = null;
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }
}
