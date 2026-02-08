import 'dart:convert';

import 'package:http/http.dart' as http;

/// Interface for making HTTP requests to the sp_server REST API.
///
/// Extracted as an abstract interface to allow faking in tests.
abstract interface class McpHttpClient {
  String get baseUrl;
  String? get apiKey;

  /// Sends a GET request to [path] and returns the decoded JSON body.
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? queryParameters,
  ]);

  /// Sends a POST request to [path] with a JSON [body]
  /// and returns the decoded JSON body.
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body);

  /// Returns the raw response body as a string for
  /// endpoints that return non-JSON data.
  Future<String> getRaw(String path, [Map<String, String>? queryParameters]);

  /// Releases underlying resources.
  void close();
}

/// Production implementation of [McpHttpClient] backed by
/// the `http` package.
final class McpHttpClientImpl implements McpHttpClient {
  McpHttpClientImpl({required this.baseUrl, this.apiKey})
    : _client = http.Client();

  @override
  final String baseUrl;

  @override
  final String? apiKey;

  final http.Client _client;

  @override
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? queryParameters,
  ]) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParameters);
    final response = await _client.get(uri, headers: _headers);
    return _decodeResponse(response);
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.post(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  @override
  Future<String> getRaw(
    String path, [
    Map<String, String>? queryParameters,
  ]) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParameters);
    final response = await _client.get(uri, headers: _headers);
    _checkStatus(response);
    return response.body;
  }

  @override
  void close() => _client.close();

  Map<String, String> get _headers {
    final headers = <String, String>{'Accept': 'application/json'};
    if (apiKey != null) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    _checkStatus(response);
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    // Wrap non-object responses so callers always get a Map.
    return {'data': decoded};
  }

  void _checkStatus(http.Response response) {
    if (400 <= response.statusCode) {
      throw HttpException(statusCode: response.statusCode, body: response.body);
    }
  }
}

/// Exception thrown when an HTTP response has a non-success status code.
final class HttpException implements Exception {
  const HttpException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() => 'HttpException($statusCode): $body';
}
