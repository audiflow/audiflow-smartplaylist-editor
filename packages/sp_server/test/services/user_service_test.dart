import 'package:test/test.dart';

import 'package:sp_server/src/services/user_service.dart';

void main() {
  group('UserService', () {
    late UserService service;

    setUp(() {
      service = UserService();
    });

    test('creates a new user', () {
      final user = service.findOrCreateUser(
        githubId: 1,
        githubUsername: 'octocat',
        avatarUrl: 'https://img/1',
      );

      expect(user.githubId, equals(1));
      expect(user.githubUsername, equals('octocat'));
      expect(user.avatarUrl, equals('https://img/1'));
      expect(user.id, isNotEmpty);
    });

    test('returns same user on duplicate githubId', () {
      final first = service.findOrCreateUser(
        githubId: 42,
        githubUsername: 'user1',
        avatarUrl: null,
      );
      final second = service.findOrCreateUser(
        githubId: 42,
        githubUsername: 'user1-updated',
        avatarUrl: 'https://img/new',
      );

      expect(second.id, equals(first.id));
      expect(second.githubUsername, equals('user1-updated'));
      expect(second.avatarUrl, equals('https://img/new'));
    });

    test('findById returns stored user', () {
      final created = service.findOrCreateUser(
        githubId: 10,
        githubUsername: 'dev',
        avatarUrl: null,
      );

      final found = service.findById(created.id);

      expect(found, isNotNull);
      expect(found!.githubId, equals(10));
    });

    test('findById returns null for unknown id', () {
      expect(service.findById('nonexistent'), isNull);
    });
  });
}
