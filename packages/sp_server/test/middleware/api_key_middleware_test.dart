import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/middleware/api_key_middleware.dart';
import 'package:sp_server/src/middleware/auth_middleware.dart';
import 'package:sp_server/src/services/api_key_service.dart';
import 'package:sp_server/src/services/jwt_service.dart';

void main() {
  group('apiKeyMiddleware', () {
    late ApiKeyService apiKeyService;
    late Handler protectedHandler;

    setUp(() {
      apiKeyService = ApiKeyService();

      final inner = (Request request) {
        final userId = request.context[userIdContextKey] as String?;
        return Response.ok(
          jsonEncode({'userId': userId}),
          headers: _jsonHeaders,
        );
      };

      protectedHandler = const Pipeline()
          .addMiddleware(apiKeyMiddleware(apiKeyService))
          .addHandler(inner);
    });

    test('rejects request without X-API-Key header', () async {
      final request = Request('GET', Uri.parse('http://localhost/protected'));

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(401));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('Missing'));
    });

    test('rejects request with invalid API key', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'X-API-Key': 'invalid-key'},
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(401));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('Invalid'));
    });

    test('passes valid API key and sets userId', () async {
      final result = apiKeyService.generateKey('user-99', 'Test Key');

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'X-API-Key': result.plaintext},
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(200));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['userId'], equals('user-99'));
    });
  });

  group('unifiedAuthMiddleware', () {
    late JwtService jwtService;
    late ApiKeyService apiKeyService;
    late Handler protectedHandler;

    setUp(() {
      jwtService = JwtService(secret: 'test-secret');
      apiKeyService = ApiKeyService();

      final inner = (Request request) {
        final userId = request.context[userIdContextKey] as String?;
        return Response.ok(
          jsonEncode({'userId': userId}),
          headers: _jsonHeaders,
        );
      };

      protectedHandler = const Pipeline()
          .addMiddleware(
            unifiedAuthMiddleware(
              jwtService: jwtService,
              apiKeyService: apiKeyService,
            ),
          )
          .addHandler(inner);
    });

    test('rejects request with no credentials', () async {
      final request = Request('GET', Uri.parse('http://localhost/protected'));

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(401));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('required'));
    });

    test('accepts valid JWT token', () async {
      final token = jwtService.createToken('user-jwt');

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(200));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['userId'], equals('user-jwt'));
    });

    test('accepts valid API key', () async {
      final result = apiKeyService.generateKey('user-api', 'Key');

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'X-API-Key': result.plaintext},
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(200));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['userId'], equals('user-api'));
    });

    test('prefers JWT over API key', () async {
      final token = jwtService.createToken('jwt-user');
      final result = apiKeyService.generateKey('api-user', 'Key');

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-API-Key': result.plaintext,
        },
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(200));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      // JWT takes priority.
      expect(body['userId'], equals('jwt-user'));
    });

    test('falls back to API key when JWT is invalid', () async {
      final result = apiKeyService.generateKey('api-user', 'Fallback');

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {
          'Authorization': 'Bearer invalid.token.here',
          'X-API-Key': result.plaintext,
        },
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(200));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['userId'], equals('api-user'));
    });

    test('rejects when both JWT and API key are invalid', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {
          'Authorization': 'Bearer invalid.token.here',
          'X-API-Key': 'bad-key',
        },
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('rejects refresh token in JWT slot', () async {
      final refreshToken = jwtService.createRefreshToken('user-jwt');

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'Authorization': 'Bearer $refreshToken'},
      );

      final response = await protectedHandler(request);

      // Refresh token fails JWT validation, no API key
      // fallback provided, so 401.
      expect(response.statusCode, equals(401));
    });

    test('falls back to API key when refresh token used as JWT', () async {
      final refreshToken = jwtService.createRefreshToken('user-jwt');
      final result = apiKeyService.generateKey('user-api', 'Fallback');

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {
          'Authorization': 'Bearer $refreshToken',
          'X-API-Key': result.plaintext,
        },
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(200));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['userId'], equals('user-api'));
    });
  });
}

const _jsonHeaders = {'Content-Type': 'application/json'};
