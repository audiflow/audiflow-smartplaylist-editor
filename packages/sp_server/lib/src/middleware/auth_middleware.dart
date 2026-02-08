import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../services/jwt_service.dart';

/// Key used to store the authenticated user ID
/// in the request context.
const String userIdContextKey = 'userId';

/// Middleware that extracts and validates a JWT from the
/// `Authorization: Bearer <token>` header.
///
/// On success, attaches the userId to the request context
/// under [userIdContextKey].
/// On failure, returns 401 Unauthorized.
Middleware authMiddleware(JwtService jwtService) {
  return (Handler handler) {
    return (Request request) {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(
          401,
          body: jsonEncode({'error': 'Missing or invalid authorization'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = authHeader.substring('Bearer '.length);
      final userId = jwtService.validateToken(token);
      if (userId == null) {
        return Response(
          401,
          body: jsonEncode({'error': 'Invalid or expired token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final updatedRequest = request.change(
        context: {userIdContextKey: userId},
      );
      return handler(updatedRequest);
    };
  };
}
