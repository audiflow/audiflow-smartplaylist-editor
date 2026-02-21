import 'dart:convert';

import 'package:test/test.dart';

import 'package:sp_server/src/services/github_app_service.dart';

void main() {
  group('GitHubAppService', () {
    group('getDefaultBranchSha', () {
      test('returns SHA on success', () async {
        final service = GitHubAppService(
          token: 'test-token',
          owner: 'owner',
          repo: 'repo',
          httpFn: (method, url, {headers, body}) async {
            expect(method, equals('GET'));
            expect(url.path, contains('/repos/owner/repo/git/ref'));
            return GitHubHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'ref': 'refs/heads/main',
                'object': {'sha': 'abc123def456', 'type': 'commit'},
              }),
            );
          },
        );

        final sha = await service.getDefaultBranchSha();
        expect(sha, equals('abc123def456'));
      });

      test('throws on non-200 response', () async {
        final service = GitHubAppService(
          token: 'test-token',
          owner: 'owner',
          repo: 'repo',
          httpFn: (method, url, {headers, body}) async {
            return GitHubHttpResponse(
              statusCode: 404,
              body: '{"message":"Not Found"}',
            );
          },
        );

        expect(
          () => service.getDefaultBranchSha(),
          throwsA(isA<GitHubApiException>()),
        );
      });

      test('sends auth headers', () async {
        String? capturedAuth;
        final service = GitHubAppService(
          token: 'my-pat',
          owner: 'o',
          repo: 'r',
          httpFn: (method, url, {headers, body}) async {
            capturedAuth = headers?['Authorization'];
            return GitHubHttpResponse(
              statusCode: 200,
              body: jsonEncode({
                'ref': 'refs/heads/main',
                'object': {'sha': 'abc', 'type': 'commit'},
              }),
            );
          },
        );

        await service.getDefaultBranchSha();
        expect(capturedAuth, equals('Bearer my-pat'));
      });
    });

    group('createBranch', () {
      test('succeeds on 201 response', () async {
        String? capturedBody;
        final service = GitHubAppService(
          token: 'tok',
          owner: 'owner',
          repo: 'repo',
          httpFn: (method, url, {headers, body}) async {
            expect(method, equals('POST'));
            capturedBody = body as String?;
            return GitHubHttpResponse(
              statusCode: 201,
              body: '{"ref":"refs/heads/test-branch"}',
            );
          },
        );

        await service.createBranch('test-branch', 'sha123');

        final parsed = jsonDecode(capturedBody!) as Map<String, dynamic>;
        expect(parsed['ref'], equals('refs/heads/test-branch'));
        expect(parsed['sha'], equals('sha123'));
      });

      test('throws on failure', () async {
        final service = GitHubAppService(
          token: 'tok',
          owner: 'owner',
          repo: 'repo',
          httpFn: (method, url, {headers, body}) async {
            return GitHubHttpResponse(
              statusCode: 422,
              body: '{"message":"Reference already exists"}',
            );
          },
        );

        expect(
          () => service.createBranch('br', 'sha'),
          throwsA(isA<GitHubApiException>()),
        );
      });
    });

    group('commitFile', () {
      test('creates new file on 201 response', () async {
        Map<String, dynamic>? capturedBody;
        final service = GitHubAppService(
          token: 'tok',
          owner: 'owner',
          repo: 'repo',
          httpFn: (method, url, {headers, body}) async {
            if (method == 'GET') {
              // File does not exist.
              return GitHubHttpResponse(statusCode: 404, body: '{}');
            }
            expect(method, equals('PUT'));
            expect(url.path, contains('contents/configs/test.json'));
            capturedBody = jsonDecode(body as String) as Map<String, dynamic>;
            return GitHubHttpResponse(
              statusCode: 201,
              body: '{"content":{"path":"configs/test.json"}}',
            );
          },
        );

        await service.commitFile(
          branchName: 'feat-branch',
          filePath: 'configs/test.json',
          content: '{"id":"test"}',
          message: 'Add test config',
        );

        expect(capturedBody!['message'], equals('Add test config'));
        expect(capturedBody!['branch'], equals('feat-branch'));
        expect(capturedBody, isNot(contains('sha')));

        // Verify content is base64 encoded.
        final decoded = utf8.decode(
          base64Decode(capturedBody!['content'] as String),
        );
        expect(decoded, equals('{"id":"test"}'));
      });

      test('updates existing file with sha', () async {
        Map<String, dynamic>? capturedBody;
        final service = GitHubAppService(
          token: 'tok',
          owner: 'owner',
          repo: 'repo',
          httpFn: (method, url, {headers, body}) async {
            if (method == 'GET') {
              // File exists with known SHA.
              return GitHubHttpResponse(
                statusCode: 200,
                body: '{"sha":"abc123","path":"configs/test.json"}',
              );
            }
            capturedBody = jsonDecode(body as String) as Map<String, dynamic>;
            return GitHubHttpResponse(
              statusCode: 200,
              body: '{"content":{"path":"configs/test.json"}}',
            );
          },
        );

        await service.commitFile(
          branchName: 'feat-branch',
          filePath: 'configs/test.json',
          content: '{"id":"updated"}',
          message: 'Update config',
        );

        expect(capturedBody!['sha'], equals('abc123'));
      });

      test('throws on failure', () async {
        final service = GitHubAppService(
          token: 'tok',
          owner: 'owner',
          repo: 'repo',
          httpFn: (method, url, {headers, body}) async {
            if (method == 'GET') {
              return GitHubHttpResponse(statusCode: 404, body: '{}');
            }
            return GitHubHttpResponse(
              statusCode: 500,
              body: '{"message":"Internal Server Error"}',
            );
          },
        );

        expect(
          () => service.commitFile(
            branchName: 'b',
            filePath: 'f.json',
            content: 'c',
            message: 'm',
          ),
          throwsA(isA<GitHubApiException>()),
        );
      });
    });

    group('createPullRequest', () {
      test('returns PR URL on success', () async {
        Map<String, dynamic>? capturedBody;
        final service = GitHubAppService(
          token: 'tok',
          owner: 'owner',
          repo: 'repo',
          httpFn: (method, url, {headers, body}) async {
            expect(method, equals('POST'));
            capturedBody = jsonDecode(body as String) as Map<String, dynamic>;
            return GitHubHttpResponse(
              statusCode: 201,
              body: jsonEncode({
                'html_url': 'https://github.com/owner/repo/pull/42',
                'number': 42,
              }),
            );
          },
        );

        final prUrl = await service.createPullRequest(
          title: 'Add config',
          body: 'Description',
          head: 'feat-branch',
        );

        expect(prUrl, equals('https://github.com/owner/repo/pull/42'));
        expect(capturedBody!['title'], equals('Add config'));
        expect(capturedBody!['head'], equals('feat-branch'));
        expect(capturedBody!['base'], equals('main'));
      });

      test('uses custom base branch', () async {
        String? capturedBase;
        final service = GitHubAppService(
          token: 'tok',
          owner: 'owner',
          repo: 'repo',
          httpFn: (method, url, {headers, body}) async {
            final parsed = jsonDecode(body as String) as Map<String, dynamic>;
            capturedBase = parsed['base'] as String?;
            return GitHubHttpResponse(
              statusCode: 201,
              body: jsonEncode({
                'html_url': 'https://github.com/pr/1',
                'number': 1,
              }),
            );
          },
        );

        await service.createPullRequest(
          title: 't',
          body: 'b',
          head: 'h',
          base: 'develop',
        );

        expect(capturedBase, equals('develop'));
      });

      test('throws on failure', () async {
        final service = GitHubAppService(
          token: 'tok',
          owner: 'owner',
          repo: 'repo',
          httpFn: (method, url, {headers, body}) async {
            return GitHubHttpResponse(
              statusCode: 422,
              body: '{"message":"Validation Failed"}',
            );
          },
        );

        expect(
          () => service.createPullRequest(title: 't', body: 'b', head: 'h'),
          throwsA(isA<GitHubApiException>()),
        );
      });
    });

    group('GitHubApiException', () {
      test('has descriptive toString', () {
        const e = GitHubApiException('Test error', 422, 'body');
        expect(e.toString(), contains('Test error'));
        expect(e.toString(), contains('422'));
      });
    });
  });
}
