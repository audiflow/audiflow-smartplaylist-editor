/// Represents an authenticated user in the system.
class User {
  User({
    required this.id,
    required this.githubId,
    required this.githubUsername,
    required this.avatarUrl,
    required this.createdAt,
    required this.lastLoginAt,
  });

  final String id;
  final int githubId;
  final String githubUsername;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  /// Creates a copy with updated fields.
  User copyWith({
    String? id,
    int? githubId,
    String? githubUsername,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      githubId: githubId ?? this.githubId,
      githubUsername: githubUsername ?? this.githubUsername,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  /// Serializes the user to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'githubId': githubId,
      'githubUsername': githubUsername,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
    };
  }
}
