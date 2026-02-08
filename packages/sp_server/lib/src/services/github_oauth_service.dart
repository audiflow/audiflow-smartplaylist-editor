import 'dart:convert';
import 'dart:io';

/// Signature for an HTTP POST function, allowing dependency
/// injection for testability.
typedef HttpPostFn =
    Future<HttpPostResponse> Function(
      Uri url, {
      Map<String, String>? headers,
      Object? body,
    });

/// Signature for an HTTP GET function, allowing dependency
/// injection for testability.
typedef HttpGetFn =
    Future<HttpGetResponse> Function(Uri url, {Map<String, String>? headers});

/// Minimal response wrapper for POST requests.
class HttpPostResponse {
  HttpPostResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// Minimal response wrapper for GET requests.
class HttpGetResponse {
  HttpGetResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// Handles GitHub OAuth authorization flow:
/// building the authorize URL, exchanging the code for
/// an access token, and fetching user info.
class GitHubOAuthService {
  GitHubOAuthService({
    String? clientId,
    String? clientSecret,
    String? redirectUri,
    HttpPostFn? httpPost,
    HttpGetFn? httpGet,
  }) : _clientId = clientId ?? Platform.environment['GITHUB_CLIENT_ID'] ?? '',
       _clientSecret =
           clientSecret ?? Platform.environment['GITHUB_CLIENT_SECRET'] ?? '',
       _redirectUri =
           redirectUri ?? Platform.environment['GITHUB_REDIRECT_URI'] ?? '',
       _httpPost = httpPost ?? _defaultPost,
       _httpGet = httpGet ?? _defaultGet;

  final String _clientId;
  final String _clientSecret;
  final String _redirectUri;
  final HttpPostFn _httpPost;
  final HttpGetFn _httpGet;

  /// Builds the GitHub authorization URL that the user
  /// should be redirected to.
  Uri getAuthorizationUrl(String state) {
    return Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': 'read:user',
      'state': state,
    });
  }

  /// Exchanges an authorization [code] for an access token.
  ///
  /// Returns the access token string on success, or `null`
  /// if the exchange fails.
  Future<String?> exchangeCode(String code) async {
    final url = Uri.https('github.com', '/login/oauth/access_token');

    final response = await _httpPost(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'code': code,
      }),
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['access_token'] as String?;
  }

  /// Fetches the authenticated user's info from GitHub API.
  ///
  /// Returns a map with `id`, `login`, and `avatar_url`
  /// on success, or `null` on failure.
  Future<Map<String, dynamic>?> fetchUserInfo(String accessToken) async {
    final url = Uri.https('api.github.com', '/user');

    final response = await _httpGet(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) return null;

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // Default HTTP implementations using dart:io HttpClient.
  static Future<HttpPostResponse> _defaultPost(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(url);
      headers?.forEach(request.headers.set);
      if (body != null) {
        request.write(body);
      }
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      return HttpPostResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close();
    }
  }

  static Future<HttpGetResponse> _defaultGet(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      headers?.forEach(request.headers.set);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      return HttpGetResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close();
    }
  }
}
