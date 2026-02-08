import 'package:sp_mcp_server/src/http_client.dart';

/// A fake [McpHttpClient] that records calls and returns
/// preconfigured responses for use in unit tests.
class FakeHttpClient implements McpHttpClient {
  Map<String, dynamic> getResponse = {};
  Map<String, dynamic> postResponse = {};
  String getRawResponse = '{}';

  String? lastGetPath;
  Map<String, String>? lastGetQueryParams;

  String? lastPostPath;
  Map<String, dynamic>? lastPostBody;

  String? lastGetRawPath;
  Map<String, String>? lastGetRawQueryParams;

  @override
  String get baseUrl => 'http://localhost:8080';

  @override
  String? get apiKey => null;

  @override
  Future<Map<String, dynamic>> get(
    String path, [
    Map<String, String>? queryParameters,
  ]) async {
    lastGetPath = path;
    lastGetQueryParams = queryParameters ?? {};
    return getResponse;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    lastPostPath = path;
    lastPostBody = body;
    return postResponse;
  }

  @override
  Future<String> getRaw(
    String path, [
    Map<String, String>? queryParameters,
  ]) async {
    lastGetRawPath = path;
    lastGetRawQueryParams = queryParameters ?? {};
    return getRawResponse;
  }

  @override
  void close() {}
}
