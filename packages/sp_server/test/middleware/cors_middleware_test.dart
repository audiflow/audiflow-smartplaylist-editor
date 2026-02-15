import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/middleware/cors_middleware.dart';

void main() {
  group('corsMiddleware', () {
    test('adds CORS headers to successful responses', () async {
      final handler = const Pipeline()
          .addMiddleware(corsMiddleware())
          .addHandler((_) => Response.ok('ok'));

      final request = Request('GET', Uri.parse('http://localhost/test'));
      final response = await handler(request);

      expect(response.statusCode, equals(200));
      expect(response.headers['access-control-allow-origin'], equals('*'));
      expect(response.headers['access-control-allow-methods'], contains('GET'));
    });

    test('handles OPTIONS preflight requests', () async {
      final handler = const Pipeline()
          .addMiddleware(corsMiddleware())
          .addHandler((_) => Response.ok('should not reach'));

      final request = Request('OPTIONS', Uri.parse('http://localhost/test'));
      final response = await handler(request);

      expect(response.statusCode, equals(200));
      expect(response.headers['access-control-allow-origin'], equals('*'));
      expect(
        response.headers['access-control-allow-headers'],
        contains('Authorization'),
      );
    });

    test('adds CORS headers to error responses', () async {
      final handler = const Pipeline()
          .addMiddleware(corsMiddleware())
          .addHandler((_) => Response(502, body: 'error'));

      final request = Request('GET', Uri.parse('http://localhost/test'));
      final response = await handler(request);

      expect(response.statusCode, equals(502));
      expect(response.headers['access-control-allow-origin'], equals('*'));
    });

    test('adds CORS headers when handler throws Exception', () async {
      final handler = const Pipeline()
          .addMiddleware(corsMiddleware())
          .addHandler((_) => throw Exception('boom'));

      final request = Request('GET', Uri.parse('http://localhost/test'));
      final response = await handler(request);

      expect(response.statusCode, equals(500));
      expect(response.headers['access-control-allow-origin'], equals('*'));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], contains('boom'));
    });

    test('adds CORS headers when handler throws Error', () async {
      final handler = const Pipeline()
          .addMiddleware(corsMiddleware())
          .addHandler((_) => throw TypeError());

      final request = Request('GET', Uri.parse('http://localhost/test'));
      final response = await handler(request);

      expect(response.statusCode, equals(500));
      expect(response.headers['access-control-allow-origin'], equals('*'));
    });

    test('uses custom allowedOrigin', () async {
      final handler = const Pipeline()
          .addMiddleware(corsMiddleware(allowedOrigin: 'https://example.com'))
          .addHandler((_) => Response.ok('ok'));

      final request = Request('GET', Uri.parse('http://localhost/test'));
      final response = await handler(request);

      expect(
        response.headers['access-control-allow-origin'],
        equals('https://example.com'),
      );
    });
  });
}
