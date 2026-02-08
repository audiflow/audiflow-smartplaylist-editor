import 'package:test/test.dart';

import 'package:sp_server/src/services/api_key_service.dart';

void main() {
  group('ApiKeyService', () {
    late ApiKeyService service;

    setUp(() {
      service = ApiKeyService();
    });

    group('generateKey', () {
      test('returns plaintext and metadata', () {
        final result = service.generateKey('user-1', 'My Key');

        expect(result.plaintext, isNotEmpty);
        expect(result.apiKey.id, startsWith('key_'));
        expect(result.apiKey.userId, equals('user-1'));
        expect(result.apiKey.name, equals('My Key'));
        expect(result.apiKey.maskedKey, isNotEmpty);
        expect(result.apiKey.createdAt, isA<DateTime>());
      });

      test('returns base64url-encoded key', () {
        final result = service.generateKey('user-1', 'test');
        // base64url chars: A-Z, a-z, 0-9, -, _
        expect(result.plaintext, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      });

      test('generates unique keys', () {
        final key1 = service.generateKey('user-1', 'key-a');
        final key2 = service.generateKey('user-1', 'key-b');

        expect(key1.plaintext, isNot(equals(key2.plaintext)));
        expect(key1.apiKey.id, isNot(equals(key2.apiKey.id)));
      });

      test('masks key showing last 8 chars', () {
        final result = service.generateKey('user-1', 'test');
        final masked = result.apiKey.maskedKey;
        final plaintext = result.plaintext;

        expect(masked, startsWith('****'));
        final visiblePart = masked.substring(4);
        expect(visiblePart.length, equals(8));
        expect(plaintext, endsWith(visiblePart));
      });
    });

    group('listKeys', () {
      test('returns empty list for unknown user', () {
        final keys = service.listKeys('nobody');
        expect(keys, isEmpty);
      });

      test('returns keys for user', () {
        service.generateKey('user-1', 'Key A');
        service.generateKey('user-1', 'Key B');
        service.generateKey('user-2', 'Other');

        final keys = service.listKeys('user-1');
        expect(keys.length, equals(2));
        expect(keys.map((k) => k.name), containsAll(['Key A', 'Key B']));
      });

      test('does not include other users keys', () {
        service.generateKey('user-1', 'Mine');
        service.generateKey('user-2', 'Theirs');

        final keys = service.listKeys('user-1');
        expect(keys.length, equals(1));
        expect(keys.first.name, equals('Mine'));
      });
    });

    group('deleteKey', () {
      test('deletes existing key', () {
        final result = service.generateKey('user-1', 'Temp');
        final deleted = service.deleteKey('user-1', result.apiKey.id);

        expect(deleted, isTrue);
        expect(service.listKeys('user-1'), isEmpty);
      });

      test('returns false for non-existent key', () {
        final deleted = service.deleteKey('user-1', 'fake-id');
        expect(deleted, isFalse);
      });

      test('returns false when userId does not match', () {
        final result = service.generateKey('user-1', 'Mine');
        final deleted = service.deleteKey('user-2', result.apiKey.id);

        expect(deleted, isFalse);
        // Key should still exist for user-1.
        expect(service.listKeys('user-1').length, equals(1));
      });

      test('invalidates key after deletion', () {
        final result = service.generateKey('user-1', 'Temp');
        service.deleteKey('user-1', result.apiKey.id);

        final userId = service.validateKey(result.plaintext);
        expect(userId, isNull);
      });
    });

    group('validateKey', () {
      test('returns userId for valid key', () {
        final result = service.generateKey('user-42', 'Valid');
        final userId = service.validateKey(result.plaintext);

        expect(userId, equals('user-42'));
      });

      test('returns null for invalid key', () {
        final userId = service.validateKey('not-a-real-key');
        expect(userId, isNull);
      });

      test('returns null for empty key', () {
        final userId = service.validateKey('');
        expect(userId, isNull);
      });
    });

    group('toJson', () {
      test('excludes hashedKey from output', () {
        final result = service.generateKey('user-1', 'Safe');
        final json = result.apiKey.toJson();

        expect(json, isNot(contains('hashedKey')));
        expect(json, contains('id'));
        expect(json, contains('name'));
        expect(json, contains('maskedKey'));
        expect(json, contains('createdAt'));
      });
    });
  });
}
