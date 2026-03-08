/// Fields by which smart playlist groups can be sorted.
enum SmartPlaylistSortField {
  /// Sort by playlist/group number.
  playlistNumber,

  /// Sort by newest episode date in group.
  newestEpisodeDate,

  /// Sort alphabetically by display name.
  alphabetical,
}

/// Fields by which episodes can be sorted within a group.
enum EpisodeSortField {
  /// Sort by publication date.
  publishedAt,

  /// Sort by episode number.
  episodeNumber,

  /// Sort alphabetically by title.
  title,
}

/// Sort direction.
enum SortOrder { ascending, descending }

/// A single sort rule for ordering groups.
final class SmartPlaylistSortRule {
  const SmartPlaylistSortRule({required this.field, required this.order});

  factory SmartPlaylistSortRule.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistSortRule(
      field: SmartPlaylistSortField.values.byName(json['field'] as String),
      order: SortOrder.values.byName(json['order'] as String),
    );
  }

  final SmartPlaylistSortField field;
  final SortOrder order;

  Map<String, dynamic> toJson() => {'field': field.name, 'order': order.name};
}

/// A sort rule for ordering episodes within a group or playlist.
final class EpisodeSortRule {
  const EpisodeSortRule({required this.field, required this.order});

  factory EpisodeSortRule.fromJson(Map<String, dynamic> json) {
    return EpisodeSortRule(
      field: EpisodeSortField.values.byName(json['field'] as String),
      order: SortOrder.values.byName(json['order'] as String),
    );
  }

  final EpisodeSortField field;
  final SortOrder order;

  Map<String, dynamic> toJson() => {'field': field.name, 'order': order.name};
}
