import '../models/episode_data.dart';
import '../models/smart_playlist.dart';
import '../models/smart_playlist_sort.dart';

/// Sorts groups within a playlist according to a [SmartPlaylistSortRule].
///
/// Returns the groups unchanged when [sortRule] is null or the list has
/// fewer than two elements.
List<SmartPlaylistGroup> sortGroups(
  List<SmartPlaylistGroup> groups,
  SmartPlaylistSortRule? sortRule,
  Map<int, EpisodeData> episodeById,
) {
  if (sortRule == null || groups.length < 2) return groups;

  final sorted = List.of(groups);
  sorted.sort(
    (a, b) => _compareByField(sortRule.field, a, b, episodeById, sortRule.order),
  );
  return sorted;
}

int _compareByField(
  SmartPlaylistSortField field,
  SmartPlaylistGroup a,
  SmartPlaylistGroup b,
  Map<int, EpisodeData> episodeById,
  SortOrder order,
) {
  final result = switch (field) {
    SmartPlaylistSortField.playlistNumber => a.sortKey.compareTo(b.sortKey),
    SmartPlaylistSortField.newestEpisodeDate => _compareNewestDate(
      a,
      b,
      episodeById,
    ),
    SmartPlaylistSortField.alphabetical => a.displayName.compareTo(
      b.displayName,
    ),
  };

  return order == SortOrder.descending ? -result : result;
}

int _compareNewestDate(
  SmartPlaylistGroup a,
  SmartPlaylistGroup b,
  Map<int, EpisodeData> episodeById,
) {
  final dateA = _newestDate(a, episodeById);
  final dateB = _newestDate(b, episodeById);

  if (dateA == null && dateB == null) return 0;
  if (dateA == null) return 1;
  if (dateB == null) return -1;

  return dateA.compareTo(dateB);
}

DateTime? _newestDate(
  SmartPlaylistGroup group,
  Map<int, EpisodeData> episodeById,
) {
  DateTime? newest;
  for (final id in group.episodeIds) {
    final date = episodeById[id]?.publishedAt;
    if (date != null && (newest == null || newest.isBefore(date))) {
      newest = date;
    }
  }
  return newest;
}
