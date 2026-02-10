import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/middleware/auth_middleware.dart';
import 'package:sp_server/src/services/jwt_service.dart';

void main() {
  group('authMiddleware', () {
    late JwtService jwtService;
    late Handler protectedHandler;

    setUp(() {
      jwtService = JwtService(secret: 'test-secret');

      // Simple handler that echoes back the userId
      // from context.
      final inner = (Request request) {
        final userId = request.context[userIdContextKey] as String?;
        return Response.ok(
          jsonEncode({'userId': userId}),
          headers: {'Content-Type': 'application/json'},
        );
      };

      protectedHandler = const Pipeline()
          .addMiddleware(authMiddleware(jwtService))
          .addHandler(inner);
    });

    test('rejects request without Authorization header', () async {
      final request = Request('GET', Uri.parse('http://localhost/protected'));

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(401));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('Missing'));
    });

    test('rejects request with non-Bearer auth', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'Authorization': 'Basic abc123'},
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('rejects request with invalid token', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'Authorization': 'Bearer invalid.token.here'},
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(401));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('Invalid'));
    });

    test('rejects request with expired token', () async {
      final token = jwtService.createToken(
        'user-1',
        expiry: const Duration(seconds: -1),
      );
      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(401));
    });

    test('passes valid token and sets userId in context', () async {
      final token = jwtService.createToken('user-42');
      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(200));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['userId'], equals('user-42'));
    });

    test('rejects refresh token', () async {
      final refreshToken = jwtService.createRefreshToken('user-42');
      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'Authorization': 'Bearer $refreshToken'},
      );

      final response = await protectedHandler(request);

      expect(response.statusCode, equals(401));
    });
  });
}
