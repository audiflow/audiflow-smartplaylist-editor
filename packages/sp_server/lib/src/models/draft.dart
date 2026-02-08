/// Represents a saved draft of a smart playlist
/// configuration.
class Draft {
  Draft({
    required this.id,
    required this.userId,
    required this.name,
    required this.configJson,
    required this.createdAt,
    required this.updatedAt,
    this.feedUrl,
  });

  final String id;
  final String userId;
  final String name;
  final Map<String, dynamic> configJson;
  final String? feedUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Serializes the draft to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'config': configJson,
      'feedUrl': feedUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
