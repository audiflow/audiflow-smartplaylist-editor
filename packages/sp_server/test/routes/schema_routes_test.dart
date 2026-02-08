import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/schema_routes.dart';

void main() {
  group('GET /api/schema', () {
    late Handler handler;

    setUp(() {
      handler = schemaRouter().call;
    });

    test('returns 200', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/schema'));

      final response = await handler(request);

      expect(response.statusCode, equals(200));
    });

    test('returns valid JSON body', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/schema'));

      final response = await handler(request);
      final body = await response.readAsString();

      // Must not throw.
      final parsed = jsonDecode(body);
      expect(parsed, isA<Map<String, dynamic>>());
    });

    test('contains schema metadata fields', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/schema'));

      final response = await handler(request);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;

      expect(body, contains(r'$schema'));
      expect(body, contains('type'));
      expect(body, contains('properties'));
    });

    test('returns application/json content type', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/schema'));

      final response = await handler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });
  });
}
