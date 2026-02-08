/// Represents a stored API key with metadata.
///
/// The [hashedKey] stores the SHA-256 hash of the
/// plaintext key. The plaintext is never stored.
class ApiKey {
  ApiKey({
    required this.id,
    required this.userId,
    required this.name,
    required this.hashedKey,
    required this.maskedKey,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String hashedKey;
  final String maskedKey;
  final DateTime createdAt;

  /// Serializes to JSON for API responses.
  ///
  /// Excludes [hashedKey] to avoid exposing
  /// sensitive data.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'maskedKey': maskedKey,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
