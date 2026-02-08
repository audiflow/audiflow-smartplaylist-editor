import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/key_routes.dart';
import 'package:sp_server/src/services/api_key_service.dart';
import 'package:sp_server/src/services/jwt_service.dart';

void main() {
  group('keyRouter', () {
    late JwtService jwtService;
    late ApiKeyService apiKeyService;
    late Handler handler;
    late String validToken;

    setUp(() {
      jwtService = JwtService(secret: 'test-secret');
      apiKeyService = ApiKeyService();
      validToken = jwtService.createToken('user-1');

      final router = keyRouter(
        jwtService: jwtService,
        apiKeyService: apiKeyService,
      );
      handler = router.call;
    });

    group('POST /api/keys', () {
      test('creates key and returns plaintext', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/keys'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'name': 'My Key'}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(201));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['key'], isNotEmpty);
        expect(body['metadata']['name'], equals('My Key'));
      });

      test('rejects without auth', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/keys'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': 'My Key'}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });

      test('rejects missing name', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/keys'),
          headers: {
            'Authorization': 'Bearer $validToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({}),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['error'], contains('Name'));
      });

      test('rejects empty body', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/keys'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(400));
      });

      test('rejects invalid JSON', () async {
        final request = Request(
          'POST',
          Uri.parse('http://localhost/api/keys'),
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
    });

    group('GET /api/keys', () {
      test('returns empty list initially', () async {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/keys'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['keys'], isEmpty);
      });

      test('returns masked keys after creation', () async {
        apiKeyService.generateKey('user-1', 'Key A');
        apiKeyService.generateKey('user-1', 'Key B');

        final request = Request(
          'GET',
          Uri.parse('http://localhost/api/keys'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        final keys = body['keys'] as List;
        expect(keys.length, equals(2));

        // Verify keys are masked.
        for (final key in keys) {
          final keyMap = key as Map<String, dynamic>;
          expect(keyMap['maskedKey'] as String, startsWith('****'));
          // Ensure no hashedKey is exposed.
          expect(keyMap, isNot(contains('hashedKey')));
        }
      });

      test('rejects without auth', () async {
        final request = Request('GET', Uri.parse('http://localhost/api/keys'));

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });
    });

    group('DELETE /api/keys/<id>', () {
      test('deletes existing key', () async {
        final result = apiKeyService.generateKey('user-1', 'ToDelete');

        final request = Request(
          'DELETE',
          Uri.parse('http://localhost/api/keys/${result.apiKey.id}'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(200));
        final body =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(body['deleted'], isTrue);

        // Verify key is gone.
        expect(apiKeyService.listKeys('user-1'), isEmpty);
      });

      test('returns 404 for non-existent key', () async {
        final request = Request(
          'DELETE',
          Uri.parse('http://localhost/api/keys/fake-id'),
          headers: {'Authorization': 'Bearer $validToken'},
        );

        final response = await handler(request);

        expect(response.statusCode, equals(404));
      });

      test('rejects without auth', () async {
        final request = Request(
          'DELETE',
          Uri.parse('http://localhost/api/keys/some-id'),
        );

        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });
    });
  });
}
