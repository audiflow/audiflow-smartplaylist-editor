import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

import 'package:sp_server/src/routes/schema_routes.dart';

void main() {
  group('GET /api/schema', () {
    late Handler handler;

    setUp(() {
      final validator = SmartPlaylistValidator();
      handler = schemaRouter(validator: validator).call;
    });

    test('returns 200', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/schema'));

      final response = await handler(request);

      expect(response.statusCode, equals(200));
    });

    test('returns valid JSON body with all three schemas', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/schema'));

      final response = await handler(request);
      final body = await response.readAsString();

      final parsed = jsonDecode(body) as Map<String, dynamic>;
      expect(parsed, contains('pattern-index'));
      expect(parsed, contains('pattern-meta'));
      expect(parsed, contains('playlist-definition'));
    });

    test('each schema contains expected metadata fields', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/schema'));

      final response = await handler(request);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;

      final playlistSchema =
          body['playlist-definition'] as Map<String, dynamic>;
      expect(playlistSchema, contains(r'$schema'));
      expect(playlistSchema, contains('type'));
      expect(playlistSchema, contains('properties'));
    });

    test('returns application/json content type', () async {
      final request = Request('GET', Uri.parse('http://localhost/api/schema'));

      final response = await handler(request);

      expect(response.headers['content-type'], equals('application/json'));
    });
  });
}
