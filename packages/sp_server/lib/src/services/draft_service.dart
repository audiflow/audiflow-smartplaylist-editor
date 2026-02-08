import '../models/draft.dart';

/// Service for managing draft smart playlist
/// configurations using in-memory storage.
///
/// Drafts are scoped per user. Each user can only
/// access their own drafts.
class DraftService {
  final Map<String, Draft> _draftsById = {};
  final Map<String, List<String>> _draftIdsByUser = {};

  /// Saves a new draft for [userId].
  ///
  /// Returns the created [Draft] with a generated ID
  /// and timestamps.
  Draft saveDraft(
    String userId,
    String name,
    Map<String, dynamic> configJson, {
    String? feedUrl,
  }) {
    final now = DateTime.now();
    final id = 'draft_${now.microsecondsSinceEpoch}';

    final draft = Draft(
      id: id,
      userId: userId,
      name: name,
      configJson: configJson,
      feedUrl: feedUrl,
      createdAt: now,
      updatedAt: now,
    );

    _draftsById[id] = draft;
    _draftIdsByUser.putIfAbsent(userId, () => []).add(id);

    return draft;
  }

  /// Lists all drafts for [userId], sorted by
  /// [updatedAt] descending (newest first).
  List<Draft> listDrafts(String userId) {
    final ids = _draftIdsByUser[userId];
    if (ids == null) return [];

    final drafts = ids.map((id) => _draftsById[id]).whereType<Draft>().toList();

    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return drafts;
  }

  /// Returns a specific draft by [draftId] for
  /// [userId], or `null` if not found.
  Draft? getDraft(String userId, String draftId) {
    final draft = _draftsById[draftId];
    if (draft == null || draft.userId != userId) {
      return null;
    }
    return draft;
  }

  /// Deletes a draft by [draftId] for [userId].
  ///
  /// Returns `true` if the draft existed and was
  /// deleted, `false` otherwise.
  bool deleteDraft(String userId, String draftId) {
    final draft = _draftsById[draftId];
    if (draft == null || draft.userId != userId) {
      return false;
    }

    _draftsById.remove(draftId);
    _draftIdsByUser[userId]?.remove(draftId);

    return true;
  }
}
