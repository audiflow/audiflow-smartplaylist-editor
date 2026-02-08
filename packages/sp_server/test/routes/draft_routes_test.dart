import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/draft_routes.dart';
import 'package:sp_server/src/services/api_key_service.dart';
import 'package:sp_server/src/services/draft_service.dart';
import 'package:sp_server/src/services/jwt_service.dart';

void main() {
  group('draftRouter', () {
    late JwtService jwtService;
    late ApiKeyService apiKeyService;
    late DraftService draftService;
    late Handler handler;
    late String validToken;

    setUp(() {
      jwtService = JwtService(secret: 'test-secret');
      apiKeyService = ApiKeyService();
      draftService = DraftService();
      validToken = jwtService.createToken('user-1');

      final router = draftRouter(
        draftService: draftService,
        jwtService: jwtService,
        apiKeyService: apiKeyService,
      );
      handler = router.call;
    });

    group('POST /api/drafts', () {
      test('creates draft and returns 201', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/drafts'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'name': 'My Draft',
            'config': {'key': 'value'},
            'feedUrl': 'https://example.com/feed',
          }),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(201));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['name'], equals('My Draft'));
        expect(body['config'], equals({'key': 'value'}));
        expect(body['feedUrl'], equals('https://example.com/feed'));
        expect(body['id'], startsWith('draft_'));
      });

      test('creates draft without feedUrl', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/drafts'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'name': 'No Feed',
            'config': {'key': 'value'},
          }),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(201));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['feedUrl'], isNull);
      });

      test('rejects without auth', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/drafts'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': 'Test',
            'config': {'key': 'value'},
          }),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });

      test('rejects empty body', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/drafts'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('rejects invalid JSON', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/drafts'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: 'not-json',
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('Invalid JSON'));
      });

      test('rejects missing name', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/drafts'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'config': {'key': 'value'},
          }),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('Name'));
      });

      test('rejects missing config', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/drafts'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'name': 'No Config'}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('Config'));
      });

      test('works with API key auth', () async {
        final keyResult = apiKeyService.generateKey('user-1', 'test-key');

        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/drafts'),
          headers: {
            'X-API-Key': keyResult.plaintext,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'name': 'API Key Draft',
            'config': {'via': 'apiKey'},
          }),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(201));
      });
    });

    group('GET /api/drafts', () {
      test('returns empty list initially', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/drafts'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['drafts'], isEmpty);
      });

      test('returns drafts after creation', () async {
        draftService.saveDraft('user-1', 'Draft A', {'a': 1});
        draftService.saveDraft('user-1', 'Draft B', {'b': 2});

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/drafts'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        final drafts = body['drafts'] as List;
        expect(drafts.length, equals(2));
      });

      test('does not return other users drafts', () async {
        draftService.saveDraft('user-1', 'Mine', {'a': 1});
        draftService.saveDraft('user-2', 'Theirs', {'b': 2});

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/drafts'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        final drafts = body['drafts'] as List;
        expect(drafts.length, equals(1));

        final draft = drafts.first as Map<String, dynamic>;
        expect(draft['name'], equals('Mine'));
      });

      test('rejects without auth', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/drafts'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });
    });

    group('GET /api/drafts/<id>', () {
      test('returns specific draft', () async {
        final saved = draftService.saveDraft('user-1', 'Target', {
          'key': 'val',
        });

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/drafts/${saved.id}'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['name'], equals('Target'));
        expect(body['id'], equals(saved.id));
      });

      test('returns 404 for unknown id', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/drafts/fake-id'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(404));
      });

      test('returns 404 for other users draft', () async {
        final saved = draftService.saveDraft('user-2', 'Private', {
          'secret': true,
        });

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/drafts/${saved.id}'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(404));
      });

      test('rejects without auth', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/drafts/some-id'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });
    });

    group('DELETE /api/drafts/<id>', () {
      test('deletes existing draft', () async {
        final saved = draftService.saveDraft('user-1', 'ToDelete', {
          'key': 'val',
        });

        final request = Request(
          'DELETE',
          Uri.parse('http://localhost/api/drafts/${saved.id}'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(204));

        // Verify draft is gone.
        expect(draftService.listDrafts('user-1'), isEmpty);
      });

      test('returns 404 for non-existent draft', () async {
        final request = Request(
          'DELETE',
          Uri.parse('http://localhost/api/drafts/fake-id'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(404));
      });

      test('returns 404 for other users draft', () async {
        final saved = draftService.saveDraft('user-2', 'NotMine', {
          'key': 'val',
        });

        final request = Request(
          'DELETE',
          Uri.parse('http://localhost/api/drafts/${saved.id}'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(404));

        // Draft should still exist for user-2.
        expect(draftService.listDrafts('user-2').length, equals(1));
      });

      test('rejects without auth', () async {
        final request = Request(
          'DELETE',
          Uri.parse('http://localhost/api/drafts/some-id'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });
    });
  });
}
