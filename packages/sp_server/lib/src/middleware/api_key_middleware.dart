import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../services/api_key_service.dart';
import '../services/jwt_service.dart';
import 'auth_middleware.dart';

/// Middleware that authenticates requests via the
/// `X-API-Key` header.
///
/// On success, attaches the userId to the request
/// context under [userIdContextKey].
/// On failure, returns 401 Unauthorized.
Middleware apiKeyMiddleware(ApiKeyService apiKeyService) {
  return (Handler handler) {
    return (Request request) {
      final apiKey = request.headers['x-api-key'];
      if (apiKey == null || apiKey.isEmpty) {
        return Response(
          401,
          body: jsonEncode({'error': 'Missing X-API-Key header'}),
          headers: _jsonHeaders,
        );
      }

      final userId = apiKeyService.validateKey(apiKey);
      if (userId == null) {
        return Response(
          401,
          body: jsonEncode({'error': 'Invalid API key'}),
          headers: _jsonHeaders,
        );
      }

      final updatedRequest = request.change(
        context: {userIdContextKey: userId},
      );
      return handler(updatedRequest);
    };
  };
}

/// Middleware that accepts either JWT or API key
/// authentication.
///
/// Tries JWT (`Authorization: Bearer <token>`) first.
/// Falls back to API key (`X-API-Key` header).
/// Returns 401 if neither succeeds.
Middleware unifiedAuthMiddleware({
  required JwtService jwtService,
  required ApiKeyService apiKeyService,
}) {
  return (Handler handler) {
    return (Request request) {
      // Try JWT first.
      final authHeader = request.headers['authorization'];
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        final token = authHeader.substring('Bearer '.length);
        final userId = jwtService.validateToken(
          token,
          requiredType: JwtService.accessTokenType,
        );
        if (userId != null) {
          final updated = request.change(context: {userIdContextKey: userId});
          return handler(updated);
        }
      }

      // Try API key.
      final apiKey = request.headers['x-api-key'];
      if (apiKey != null && apiKey.isNotEmpty) {
        final userId = apiKeyService.validateKey(apiKey);
        if (userId != null) {
          final updated = request.change(context: {userIdContextKey: userId});
          return handler(updated);
        }
      }

      return Response(
        401,
        body: jsonEncode({'error': 'Authentication required'}),
        headers: _jsonHeaders,
      );
    };
  };
}

const _jsonHeaders = {'Content-Type': 'application/json'};
