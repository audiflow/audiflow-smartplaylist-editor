/// Fields by which smart playlists can be sorted.
enum SmartPlaylistSortField {
  /// Sort by playlist number.
  playlistNumber,

  /// Sort by newest episode date in smart playlist.
  newestEpisodeDate,

  /// Sort by playback progress (least complete first).
  progress,

  /// Sort alphabetically by display name.
  alphabetical,
}

/// Sort direction.
enum SortOrder { ascending, descending }

/// Specification for how to sort smart playlists.
sealed class SmartPlaylistSortSpec {
  const SmartPlaylistSortSpec();

  /// Deserializes from JSON using a `type` discriminator.
  factory SmartPlaylistSortSpec.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'simple' => SimpleSmartPlaylistSort.fromJson(json),
      'composite' => CompositeSmartPlaylistSort.fromJson(json),
      _ => throw FormatException('Unknown SmartPlaylistSortSpec type: $type'),
    };
  }

  /// Serializes to JSON with a `type` discriminator.
  Map<String, dynamic> toJson();
}

/// Simple single-field sort.
final class SimpleSmartPlaylistSort extends SmartPlaylistSortSpec {
  const SimpleSmartPlaylistSort(this.field, this.order);

  /// Deserializes from JSON.
  factory SimpleSmartPlaylistSort.fromJson(Map<String, dynamic> json) {
    return SimpleSmartPlaylistSort(
      SmartPlaylistSortField.values.byName(json['field'] as String),
      SortOrder.values.byName(json['order'] as String),
    );
  }

  final SmartPlaylistSortField field;
  final SortOrder order;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'simple',
    'field': field.name,
    'order': order.name,
  };
}

/// Composite sort with multiple rules and optional conditions.
final class CompositeSmartPlaylistSort extends SmartPlaylistSortSpec {
  const CompositeSmartPlaylistSort(this.rules);

  /// Deserializes from JSON.
  factory CompositeSmartPlaylistSort.fromJson(Map<String, dynamic> json) {
    final rulesJson = json['rules'] as List<dynamic>;
    return CompositeSmartPlaylistSort(
      rulesJson
          .map((e) => SmartPlaylistSortRule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<SmartPlaylistSortRule> rules;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'composite',
    'rules': rules.map((r) => r.toJson()).toList(),
  };
}

/// A single rule in a composite sort.
final class SmartPlaylistSortRule {
  const SmartPlaylistSortRule({
    required this.field,
    required this.order,
    this.condition,
  });

  /// Deserializes from JSON.
  factory SmartPlaylistSortRule.fromJson(Map<String, dynamic> json) {
    final conditionJson = json['condition'] as Map<String, dynamic>?;
    return SmartPlaylistSortRule(
      field: SmartPlaylistSortField.values.byName(json['field'] as String),
      order: SortOrder.values.byName(json['order'] as String),
      condition: conditionJson != null
          ? SmartPlaylistSortCondition.fromJson(conditionJson)
          : null,
    );
  }

  final SmartPlaylistSortField field;
  final SortOrder order;

  /// Optional condition for when this rule applies.
  final SmartPlaylistSortCondition? condition;

  /// Serializes to JSON.
  Map<String, dynamic> toJson() => {
    'field': field.name,
    'order': order.name,
    if (condition != null) 'condition': condition!.toJson(),
  };
}

/// Conditions for conditional sorting rules.
sealed class SmartPlaylistSortCondition {
  const SmartPlaylistSortCondition();

  /// Deserializes from JSON using a `type` discriminator.
  factory SmartPlaylistSortCondition.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'sortKeyGreaterThan' ||
      'greaterThan' => SortKeyGreaterThan.fromJson(json),
      _ => throw FormatException(
        'Unknown SmartPlaylistSortCondition type: $type',
      ),
    };
  }

  /// Serializes to JSON with a `type` discriminator.
  Map<String, dynamic> toJson();
}

/// Condition: smart playlist sort key greater than value.
final class SortKeyGreaterThan extends SmartPlaylistSortCondition {
  const SortKeyGreaterThan(this.value);

  /// Deserializes from JSON.
  factory SortKeyGreaterThan.fromJson(Map<String, dynamic> json) {
    return SortKeyGreaterThan(json['value'] as int);
  }

  final int value;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'sortKeyGreaterThan',
    'value': value,
  };
}
