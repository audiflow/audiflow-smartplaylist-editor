import '../models/episode_data.dart';
import '../models/smart_playlist.dart';
import '../models/smart_playlist_sort.dart';

/// Sorts groups within a playlist according to a [SmartPlaylistSortSpec].
///
/// Returns the groups unchanged when [sortSpec] is null or the list has
/// fewer than two elements. The `progress` field is mobile-only and
/// treated as a no-op in preview.
List<SmartPlaylistGroup> sortGroups(
  List<SmartPlaylistGroup> groups,
  SmartPlaylistSortSpec? sortSpec,
  Map<int, EpisodeData> episodeById,
) {
  if (sortSpec == null || groups.length < 2) return groups;

  final rules = sortSpec.rules;
  if (rules.isEmpty) return groups;

  // Single unconditional rule: simple sort.
  if (rules.length == 1 && rules.first.condition == null) {
    return _sortByRule(groups, rules.first, episodeById);
  }

  return _sortComposite(groups, rules, episodeById);
}

List<SmartPlaylistGroup> _sortByRule(
  List<SmartPlaylistGroup> groups,
  SmartPlaylistSortRule rule,
  Map<int, EpisodeData> episodeById,
) {
  final sorted = List.of(groups);
  sorted.sort(
    (a, b) => _compareByField(rule.field, a, b, episodeById, rule.order),
  );
  return sorted;
}

List<SmartPlaylistGroup> _sortComposite(
  List<SmartPlaylistGroup> groups,
  List<SmartPlaylistSortRule> rules,
  Map<int, EpisodeData> episodeById,
) {
  SmartPlaylistSortRule? conditionalRule;
  SmartPlaylistSortRule? unconditionalRule;

  for (final rule in rules) {
    if (rule.condition != null && conditionalRule == null) {
      conditionalRule = rule;
    } else if (rule.condition == null && unconditionalRule == null) {
      unconditionalRule = rule;
    }
  }

  if (conditionalRule == null) {
    if (unconditionalRule == null) return groups;
    return _sortByRule(groups, unconditionalRule, episodeById);
  }

  final matching = <SmartPlaylistGroup>[];
  final nonMatching = <SmartPlaylistGroup>[];

  for (final group in groups) {
    if (_matchesCondition(group, conditionalRule.condition!)) {
      matching.add(group);
    } else {
      nonMatching.add(group);
    }
  }

  matching.sort(
    (a, b) => _compareByField(
      conditionalRule!.field,
      a,
      b,
      episodeById,
      conditionalRule.order,
    ),
  );

  if (unconditionalRule != null) {
    nonMatching.sort(
      (a, b) => _compareByField(
        unconditionalRule!.field,
        a,
        b,
        episodeById,
        unconditionalRule.order,
      ),
    );
  }

  return [...matching, ...nonMatching];
}

bool _matchesCondition(
  SmartPlaylistGroup group,
  SmartPlaylistSortCondition condition,
) {
  return switch (condition) {
    SortKeyGreaterThan(:final value) => value < group.sortKey,
  };
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
    SmartPlaylistSortField.progress => 0,
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
