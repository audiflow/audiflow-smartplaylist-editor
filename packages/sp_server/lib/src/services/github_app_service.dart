import 'dart:convert';
import 'dart:io';

/// Signature for GitHub API HTTP functions,
/// allowing dependency injection for testability.
typedef GitHubHttpFn =
    Future<GitHubHttpResponse> Function(
      String method,
      Uri url, {
      Map<String, String>? headers,
      Object? body,
    });

/// Minimal response wrapper for GitHub API calls.
class GitHubHttpResponse {
  GitHubHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// Result of a successful PR submission.
class SubmitResult {
  const SubmitResult({required this.prUrl, required this.branch});

  final String prUrl;
  final String branch;

  Map<String, dynamic> toJson() => {'prUrl': prUrl, 'branch': branch};
}

/// Handles GitHub repository operations for PR
/// submission using a Personal Access Token.
///
/// Reads `GITHUB_TOKEN`, `CONFIG_OWNER`, and
/// `CONFIG_REPO` from the environment.
class GitHubAppService {
  GitHubAppService({
    String? token,
    String? owner,
    String? repo,
    GitHubHttpFn? httpFn,
  }) : _token = token ?? Platform.environment['GITHUB_TOKEN'] ?? '',
       _owner = owner ?? Platform.environment['CONFIG_OWNER'] ?? '',
       _repo = repo ?? Platform.environment['CONFIG_REPO'] ?? '',
       _httpFn = httpFn ?? _defaultHttp;

  final String _token;
  final String _owner;
  final String _repo;
  final GitHubHttpFn _httpFn;

  Uri _apiUrl(String path) => Uri.https('api.github.com', path);

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Accept': 'application/vnd.github+json',
    'Content-Type': 'application/json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  /// Gets the HEAD SHA of the default branch.
  Future<String> getDefaultBranchSha() async {
    final url = _apiUrl('/repos/$_owner/$_repo/git/ref/heads/main');

    final response = await _httpFn('GET', url, headers: _headers);

    if (response.statusCode != 200) {
      throw GitHubApiException(
        'Failed to get default branch SHA: ${url}',
        response.statusCode,
        response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final obj = data['object'] as Map<String, dynamic>;
    return obj['sha'] as String;
  }

  /// Creates a new branch from [baseSha].
  Future<void> createBranch(String branchName, String baseSha) async {
    final url = _apiUrl('/repos/$_owner/$_repo/git/refs');

    final response = await _httpFn(
      'POST',
      url,
      headers: _headers,
      body: jsonEncode({'ref': 'refs/heads/$branchName', 'sha': baseSha}),
    );

    if (response.statusCode != 201) {
      throw GitHubApiException(
        'Failed to create branch: $branchName',
        response.statusCode,
        response.body,
      );
    }
  }

  /// Creates or updates a file on [branchName]
  /// via the Contents API.
  ///
  /// Automatically fetches the existing blob SHA when
  /// the file already exists (required by GitHub API for
  /// updates).
  Future<void> commitFile({
    required String branchName,
    required String filePath,
    required String content,
    required String message,
  }) async {
    final url = _apiUrl('/repos/$_owner/$_repo/contents/$filePath');

    // Check if file exists on the branch to get its SHA.
    final existingSha = await _getFileSha(filePath, branchName);

    final encoded = base64Encode(utf8.encode(content));
    final payload = <String, dynamic>{
      'message': message,
      'content': encoded,
      'branch': branchName,
    };
    if (existingSha != null) {
      payload['sha'] = existingSha;
    }

    final response = await _httpFn(
      'PUT',
      url,
      headers: _headers,
      body: jsonEncode(payload),
    );

    // 200 = updated existing file, 201 = created new file.
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw GitHubApiException(
        'Failed to commit file: $filePath',
        response.statusCode,
        response.body,
      );
    }
  }

  /// Returns the blob SHA of [filePath] on [branch], or
  /// null if the file does not exist.
  Future<String?> _getFileSha(String filePath, String branch) async {
    final url = _apiUrl('/repos/$_owner/$_repo/contents/$filePath');
    final queryUrl = url.replace(queryParameters: {'ref': branch});

    final response = await _httpFn('GET', queryUrl, headers: _headers);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['sha'] as String?;
  }

  /// Opens a pull request on the repository.
  Future<String> createPullRequest({
    required String title,
    required String body,
    required String head,
    String base = 'main',
  }) async {
    final url = _apiUrl('/repos/$_owner/$_repo/pulls');

    final response = await _httpFn(
      'POST',
      url,
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'body': body,
        'head': head,
        'base': base,
      }),
    );

    if (response.statusCode != 201) {
      throw GitHubApiException(
        'Failed to create pull request',
        response.statusCode,
        response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['html_url'] as String;
  }

  // Default HTTP implementation using dart:io.
  static Future<GitHubHttpResponse> _defaultHttp(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, url);
      headers?.forEach(request.headers.set);
      if (body != null) {
        request.write(body);
      }
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      return GitHubHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close();
    }
  }
}

/// Exception thrown when a GitHub API call fails.
class GitHubApiException implements Exception {
  const GitHubApiException(this.message, this.statusCode, this.responseBody);

  final String message;
  final int statusCode;
  final String responseBody;

  @override
  String toString() =>
      'GitHubApiException: $message '
      '(status: $statusCode)';
}
