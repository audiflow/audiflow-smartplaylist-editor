import '../models/user.dart';

/// In-memory user storage and lookup service.
class UserService {
  final Map<String, User> _usersById = {};
  final Map<int, String> _idByGithubId = {};

  /// Finds an existing user by GitHub ID or creates a new one.
  ///
  /// If the user already exists, updates [githubUsername],
  /// [avatarUrl], and [lastLoginAt].
  User findOrCreateUser({
    required int githubId,
    required String githubUsername,
    required String? avatarUrl,
  }) {
    final existingId = _idByGithubId[githubId];
    if (existingId != null) {
      final existing = _usersById[existingId]!;
      final updated = existing.copyWith(
        githubUsername: githubUsername,
        avatarUrl: avatarUrl,
        lastLoginAt: DateTime.now(),
      );
      _usersById[existingId] = updated;
      return updated;
    }

    final now = DateTime.now();
    final id = 'user_${now.microsecondsSinceEpoch}';
    final user = User(
      id: id,
      githubId: githubId,
      githubUsername: githubUsername,
      avatarUrl: avatarUrl,
      createdAt: now,
      lastLoginAt: now,
    );
    _usersById[id] = user;
    _idByGithubId[githubId] = id;
    return user;
  }

  /// Looks up a user by internal ID.
  User? findById(String id) => _usersById[id];
}
