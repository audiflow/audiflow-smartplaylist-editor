import 'package:test/test.dart';

import 'package:sp_server/src/services/jwt_service.dart';

void main() {
  group('JwtService', () {
    late JwtService jwtService;

    setUp(() {
      jwtService = JwtService(secret: 'test-secret');
    });

    test('createToken returns a three-part token', () {
      final token = jwtService.createToken('user-123');
      final parts = token.split('.');

      expect(parts.length, equals(3));
      expect(parts[0].isNotEmpty, isTrue);
      expect(parts[1].isNotEmpty, isTrue);
      expect(parts[2].isNotEmpty, isTrue);
    });

    test('validateToken returns userId for valid token', () {
      final token = jwtService.createToken('user-abc');
      final userId = jwtService.validateToken(token);

      expect(userId, equals('user-abc'));
    });

    test('validateToken returns null for tampered token', () {
      final token = jwtService.createToken('user-abc');
      final tampered = '${token}x';
      final userId = jwtService.validateToken(tampered);

      expect(userId, isNull);
    });

    test('validateToken returns null for expired token', () {
      final token = jwtService.createToken(
        'user-abc',
        expiry: const Duration(seconds: -1),
      );
      final userId = jwtService.validateToken(token);

      expect(userId, isNull);
    });

    test('validateToken returns null for wrong secret', () {
      final otherService = JwtService(secret: 'other-secret');
      final token = jwtService.createToken('user-abc');
      final userId = otherService.validateToken(token);

      expect(userId, isNull);
    });

    test('validateToken returns null for garbage input', () {
      expect(jwtService.validateToken(''), isNull);
      expect(jwtService.validateToken('a.b'), isNull);
      expect(jwtService.validateToken('not-a-jwt'), isNull);
    });

    test('roundtrip preserves userId', () {
      const ids = ['id-1', 'user_12345', 'abc-def-ghi'];
      for (final id in ids) {
        final token = jwtService.createToken(id);
        expect(jwtService.validateToken(token), equals(id));
      }
    });
  });
}
