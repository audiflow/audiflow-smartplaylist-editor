import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/health_routes.dart';

void main() {
  group('GET /api/health', () {
    late Handler handler;

    setUp(() {
      handler = healthRouter().call;
    });

    test('returns 200 with status ok', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/health'));

      final response = await handler(request);

      expect(response.statusCode, equals(200));

      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['status'], equals('ok'));
    });

    test('returns application/json content type', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/health'));

      final response = await handler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });
  });
}
