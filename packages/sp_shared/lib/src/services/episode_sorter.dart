import '../models/episode_data.dart';

/// Sorts episode IDs by [EpisodeData.publishedAt] ascending (oldest first).
///
/// - Episodes with non-null dates sort before those with null dates.
/// - IDs not found in [episodeById] sort after all known episodes.
/// - The sort is stable: episodes with equal keys retain their input order.
List<int> sortEpisodeIdsByPublishedAt(
  List<int> episodeIds,
  Map<int, EpisodeData> episodeById,
) {
  if (episodeIds.length < 2) return List.of(episodeIds);

  // Assign each id to one of three tiers:
  //   0 = has publishedAt
  //   1 = in map but publishedAt is null
  //   2 = not found in map
  final sorted = List.of(episodeIds);
  sorted.sort((a, b) {
    final epA = episodeById[a];
    final epB = episodeById[b];
    final tierA = epA == null ? 2 : (epA.publishedAt == null ? 1 : 0);
    final tierB = epB == null ? 2 : (epB.publishedAt == null ? 1 : 0);

    if (tierA != tierB) return tierA.compareTo(tierB);

    // Both in the same tier
    if (tierA == 0) {
      return epA!.publishedAt!.compareTo(epB!.publishedAt!);
    }

    // Same tier (1 or 2) -- preserve original order (stable)
    return 0;
  });
  return sorted;
}
