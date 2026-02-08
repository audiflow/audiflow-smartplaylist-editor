import 'dart:convert';

import 'package:http/http.dart' as http;

/// HTTP client wrapper for API calls.
///
/// Handles authentication headers and JSON
/// encoding/decoding for all requests.
class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
  String? _token;

  /// Sets the JWT token for authenticated requests.
  void setToken(String token) {
    _token = token;
  }

  /// Clears the stored JWT token.
  void clearToken() {
    _token = null;
  }

  /// Whether a token is currently stored.
  bool get hasToken => _token != null;

  /// Sends a GET request to [path].
  Future<http.Response> get(String path) {
    return http.get(Uri.parse('$baseUrl$path'), headers: _buildHeaders());
  }

  /// Sends a POST request to [path] with optional
  /// JSON [body].
  Future<http.Response> post(String path, {Map<String, dynamic>? body}) {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Sends a PUT request to [path] with optional
  /// JSON [body].
  Future<http.Response> put(String path, {Map<String, dynamic>? body}) {
    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Sends a DELETE request to [path].
  Future<http.Response> delete(String path) {
    return http.delete(Uri.parse('$baseUrl$path'), headers: _buildHeaders());
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }
}
