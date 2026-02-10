import 'dart:convert';

/// Abstraction over browser localStorage for testability.
abstract interface class StorageAccess {
  String? getItem(String key);
  void setItem(String key, String value);
  void removeItem(String key);
}

/// A draft entry stored in localStorage.
final class DraftEntry {
  const DraftEntry({
    required this.base,
    required this.modified,
    required this.savedAt,
  });

  /// The original config JSON at edit start.
  final Map<String, dynamic> base;

  /// The user's edited config JSON.
  final Map<String, dynamic> modified;

  /// ISO-8601 UTC timestamp of when the draft was saved.
  final String savedAt;

  Map<String, dynamic> toJson() => {
    'base': base,
    'modified': modified,
    'savedAt': savedAt,
  };

  /// Parses from JSON, returning null if the data is malformed.
  static DraftEntry? fromJson(Map<String, dynamic> json) {
    final base = json['base'];
    final modified = json['modified'];
    final savedAt = json['savedAt'];

    if (base is! Map<String, dynamic>) return null;
    if (modified is! Map<String, dynamic>) return null;
    if (savedAt is! String) return null;

    return DraftEntry(base: base, modified: modified, savedAt: savedAt);
  }
}

/// Manages auto-save drafts in localStorage.
final class LocalDraftService {
  const LocalDraftService({required StorageAccess storage})
    : _storage = storage;

  final StorageAccess _storage;

  static const _prefix = 'autosave:';

  String _key(String? configId) => '$_prefix${configId ?? '__new__'}';

  /// Saves a draft for the given config.
  void saveDraft({
    required String? configId,
    required Map<String, dynamic> base,
    required Map<String, dynamic> modified,
  }) {
    final entry = DraftEntry(
      base: base,
      modified: modified,
      savedAt: DateTime.now().toUtc().toIso8601String(),
    );
    _storage.setItem(_key(configId), jsonEncode(entry.toJson()));
  }

  /// Loads a draft for the given config, or null if none exists.
  DraftEntry? loadDraft(String? configId) {
    final raw = _storage.getItem(_key(configId));
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return DraftEntry.fromJson(json);
    } on Object {
      return null;
    }
  }

  /// Removes a stored draft.
  void clearDraft(String? configId) {
    _storage.removeItem(_key(configId));
  }

  /// Whether a draft exists for the given config.
  bool hasDraft(String? configId) {
    return _storage.getItem(_key(configId)) != null;
  }
}
