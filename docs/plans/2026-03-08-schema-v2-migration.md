# Schema v2 Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate sp_shared models, sp_react Zod schema, and UI forms from v1 to v2 schema as defined in the CHANGELOG.

**Architecture:** Bottom-up migration: update the canonical JSON schema asset first, then Dart models + constants + resolver service, then React Zod schema + form components. Conformance tests catch drift at each layer.

**Tech Stack:** Dart (sp_shared models, tests), TypeScript/React (sp_react Zod, forms, i18n)

---

## Summary of v2 Changes

| v1 | v2 |
|----|-----|
| `contentType` (`episodes`/`groups`) | `playlistStructure` (`split`/`grouped`) |
| `yearHeaderMode` (`firstEpisode`/`perEpisode`) | `groupList.yearBinding` (`pinToYear`/`splitByYear`) |
| `showSortOrderToggle` | `groupList.userSortable` (default: `true`) |
| `showDateRange` (top-level) | `groupList.showDateRange` |
| `episodeYearHeaders` (top-level) | `episodeList.showYearHeaders` |
| `showSeasonNumber` | `prependSeasonNumber` |
| `titleFilter` / `requireFilter` | `episodeFilters.require: [{ title }]` |
| `excludeFilter` | `episodeFilters.exclude: [{ title }]` |
| `customSort` (SortSpec with rules array + SortCondition) | `groupList.sort` (single SortRule, no condition) |
| `smartPlaylistEpisodeExtractor` | `episodeExtractor` |
| `GroupDef.episodeYearHeaders` | `GroupDef.episodeList.showYearHeaders` |
| `GroupDef.showDateRange` | `GroupDef.display.showDateRange` |
| `SortField.progress` | (removed) |
| `SortCondition` / `SortSpec` | (removed -- single SortRule replaces) |
| (new) | `GroupDef.display.yearBinding` |
| (new) | `GroupDef.episodeList.sort` (EpisodeSortRule) |
| (new) | `GroupDef.episodeList.titleExtractor` |
| (new) | `GroupDef.episodeExtractor` |
| (new) | `episodeList.sort` (EpisodeSortRule) |
| (new) | `episodeList.titleExtractor` |

---

## Task 1: Update vendored JSON schema in sp_shared

**Files:**
- Modify: `packages/sp_shared/assets/playlist-definition.schema.json`

**Step 1:** Copy the v2 schema from the dev data repo into sp_shared assets.

```bash
cp ~/Documents/src/projects/audiflow/audiflow-smartplaylist-dev/schema/playlist-definition.schema.json \
   packages/sp_shared/assets/playlist-definition.schema.json
```

**Step 2:** Regenerate schema_data.dart from the updated asset.

```bash
dart run packages/sp_shared/tool/update_schema_data.dart
```

**Step 3:** Verify the regenerated file compiles.

```bash
cd packages/sp_shared && dart analyze lib/src/schema/schema_data.dart
```

**Step 4:** Commit.

```
feat: update playlist-definition schema to v2
```

---

## Task 2: Update SmartPlaylistSchemaConstants

**Files:**
- Modify: `packages/sp_shared/lib/src/schema/smart_playlist_schema.dart`

**Step 1:** Update constants to match v2 schema.

Replace the entire file contents with:

```dart
/// Constants for SmartPlaylist config schema values.
///
/// Provides enum value lists and version info used by both
/// validation and runtime code. The authoritative schemas are
/// the vendored `assets/*.schema.json` files.
final class SmartPlaylistSchemaConstants {
  SmartPlaylistSchemaConstants._();

  /// Schema URI for pattern-index.schema.json.
  static const String patternIndexSchemaId =
      'https://audiflow.app/schema/v$currentSchemaVersion/pattern-index.json';

  /// Schema URI for pattern-meta.schema.json.
  static const String patternMetaSchemaId =
      'https://audiflow.app/schema/v$currentSchemaVersion/pattern-meta.json';

  /// Schema URI for playlist-definition.schema.json.
  static const String playlistDefinitionSchemaId =
      'https://audiflow.app/schema/v$currentSchemaVersion/playlist-definition.json';

  /// Current data format version.
  static const int currentDataVersion = 1;

  /// Current schema definition version.
  /// Bumped when fields are added or changed.
  static const int currentSchemaVersion = 2;

  /// Valid resolver types for playlist definitions.
  static const List<String> validResolverTypes = [
    'rss',
    'category',
    'year',
    'titleAppearanceOrder',
  ];

  /// Valid playlist structure types.
  static const List<String> validPlaylistStructures = ['split', 'grouped'];

  /// Valid year binding modes.
  static const List<String> validYearBindings = [
    'none',
    'pinToYear',
    'splitByYear',
  ];

  /// Valid group sort fields.
  static const List<String> validSortFields = [
    'playlistNumber',
    'newestEpisodeDate',
    'alphabetical',
  ];

  /// Valid episode sort fields.
  static const List<String> validEpisodeSortFields = [
    'publishedAt',
    'episodeNumber',
    'title',
  ];

  /// Valid sort orders.
  static const List<String> validSortOrders = ['ascending', 'descending'];

  /// Valid title extractor sources.
  static const List<String> validTitleExtractorSources = [
    'title',
    'description',
    'seasonNumber',
    'episodeNumber',
  ];

  /// Valid episode extractor sources.
  static const List<String> validEpisodeExtractorSources = [
    'title',
    'description',
  ];
}
```

Key changes:
- `currentSchemaVersion` 1 -> 2
- `validContentTypes` -> `validPlaylistStructures` with `['split', 'grouped']`
- `validYearHeaderModes` -> `validYearBindings` with `['none', 'pinToYear', 'splitByYear']`
- `validSortFields` removed `'progress'`
- Added `validEpisodeSortFields` with `['publishedAt', 'episodeNumber', 'title']`
- Removed `validSortConditionTypes` (SortCondition removed in v2)

**Step 2:** Verify it compiles.

```bash
cd packages/sp_shared && dart analyze lib/src/schema/smart_playlist_schema.dart
```

**Step 3:** Commit.

```
feat: update SmartPlaylistSchemaConstants for v2 schema
```

---

## Task 3: Update SmartPlaylistSort models

**Files:**
- Modify: `packages/sp_shared/lib/src/models/smart_playlist_sort.dart`

In v2, the sort model simplifies significantly:
- `SortSpec` (wrapper with rules array) is removed
- `SortCondition` and `SortKeyGreaterThan` are removed
- `SmartPlaylistSortField.progress` is removed
- `SmartPlaylistSortRule` loses its `condition` field
- New `EpisodeSortField` enum and `EpisodeSortRule` class added

**Step 1:** Replace the entire file:

```dart
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
  const SmartPlaylistSortRule({
    required this.field,
    required this.order,
  });

  factory SmartPlaylistSortRule.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistSortRule(
      field: SmartPlaylistSortField.values.byName(json['field'] as String),
      order: SortOrder.values.byName(json['order'] as String),
    );
  }

  final SmartPlaylistSortField field;
  final SortOrder order;

  Map<String, dynamic> toJson() => {
    'field': field.name,
    'order': order.name,
  };
}

/// A sort rule for ordering episodes within a group or playlist.
final class EpisodeSortRule {
  const EpisodeSortRule({
    required this.field,
    required this.order,
  });

  factory EpisodeSortRule.fromJson(Map<String, dynamic> json) {
    return EpisodeSortRule(
      field: EpisodeSortField.values.byName(json['field'] as String),
      order: SortOrder.values.byName(json['order'] as String),
    );
  }

  final EpisodeSortField field;
  final SortOrder order;

  Map<String, dynamic> toJson() => {
    'field': field.name,
    'order': order.name,
  };
}
```

**Step 2:** Fix all compile errors from removing `SmartPlaylistSortSpec`, `SmartPlaylistSortCondition`, `SortKeyGreaterThan`, `SmartPlaylistSortField.progress`. These references exist in:
- `smart_playlist_definition.dart` (field type, fromJson, toJson)
- `group_sorter.dart` (function signature, condition matching, progress case)
- `smart_playlist_resolver_service.dart` (passes `definition.customSort`)
- `rss_metadata_resolver.dart` (defaultSort)
- `sp_shared.dart` (exports are fine, just type changes)
- Various test files

These will be fixed in subsequent tasks.

**Step 3:** Commit.

```
feat: replace sort models with v2 SortRule and EpisodeSortRule
```

---

## Task 4: Update SmartPlaylistGroupDef

**Files:**
- Modify: `packages/sp_shared/lib/src/models/smart_playlist_group_def.dart`

In v2, GroupDef gains nested `display`, `episodeList`, and `episodeExtractor` fields, replacing flat `episodeYearHeaders` and `showDateRange`.

**Step 1:** Replace the file:

```dart
import 'smart_playlist_episode_extractor.dart';
import 'smart_playlist_sort.dart';
import 'smart_playlist_title_extractor.dart';

/// Static group definition within a playlist.
///
/// Groups with a [pattern] match episodes by title regex.
/// Groups without a pattern act as fallback (catch-all).
final class SmartPlaylistGroupDef {
  const SmartPlaylistGroupDef({
    required this.id,
    required this.displayName,
    this.pattern,
    this.display,
    this.episodeList,
    this.episodeExtractor,
  });

  factory SmartPlaylistGroupDef.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistGroupDef(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      pattern: json['pattern'] as String?,
      display: json['display'] != null
          ? GroupDefDisplay.fromJson(json['display'] as Map<String, dynamic>)
          : null,
      episodeList: json['episodeList'] != null
          ? GroupDefEpisodeList.fromJson(
              json['episodeList'] as Map<String, dynamic>,
            )
          : null,
      episodeExtractor: json['episodeExtractor'] != null
          ? SmartPlaylistEpisodeExtractor.fromJson(
              json['episodeExtractor'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String id;
  final String displayName;
  final String? pattern;

  /// Per-group display overrides for the group card.
  final GroupDefDisplay? display;

  /// Per-group episode list overrides.
  final GroupDefEpisodeList? episodeList;

  /// Per-group episode extractor override.
  final SmartPlaylistEpisodeExtractor? episodeExtractor;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      if (pattern != null) 'pattern': pattern,
      if (display != null) 'display': display!.toJson(),
      if (episodeList != null) 'episodeList': episodeList!.toJson(),
      if (episodeExtractor != null)
        'episodeExtractor': episodeExtractor!.toJson(),
    };
  }
}

/// Per-group display overrides for the group card.
final class GroupDefDisplay {
  const GroupDefDisplay({
    this.showDateRange,
    this.yearBinding,
  });

  factory GroupDefDisplay.fromJson(Map<String, dynamic> json) {
    return GroupDefDisplay(
      showDateRange: json['showDateRange'] as bool?,
      yearBinding: json['yearBinding'] as String?,
    );
  }

  final bool? showDateRange;
  final String? yearBinding;

  Map<String, dynamic> toJson() {
    return {
      if (showDateRange != null) 'showDateRange': showDateRange,
      if (yearBinding != null) 'yearBinding': yearBinding,
    };
  }
}

/// Per-group episode list overrides.
final class GroupDefEpisodeList {
  const GroupDefEpisodeList({
    this.showYearHeaders,
    this.sort,
    this.titleExtractor,
  });

  factory GroupDefEpisodeList.fromJson(Map<String, dynamic> json) {
    return GroupDefEpisodeList(
      showYearHeaders: json['showYearHeaders'] as bool?,
      sort: json['sort'] != null
          ? EpisodeSortRule.fromJson(json['sort'] as Map<String, dynamic>)
          : null,
      titleExtractor: json['titleExtractor'] != null
          ? SmartPlaylistTitleExtractor.fromJson(
              json['titleExtractor'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final bool? showYearHeaders;
  final EpisodeSortRule? sort;
  final SmartPlaylistTitleExtractor? titleExtractor;

  Map<String, dynamic> toJson() {
    return {
      if (showYearHeaders != null) 'showYearHeaders': showYearHeaders,
      if (sort != null) 'sort': sort!.toJson(),
      if (titleExtractor != null) 'titleExtractor': titleExtractor!.toJson(),
    };
  }
}
```

**Step 2:** Commit.

```
feat: update SmartPlaylistGroupDef with v2 nested display/episodeList
```

---

## Task 5: Update SmartPlaylistDefinition

**Files:**
- Modify: `packages/sp_shared/lib/src/models/smart_playlist_definition.dart`

Major restructuring: flat fields move into nested `episodeFilters`, `groupList`, `episodeList` objects.

**Step 1:** Replace the file:

```dart
import 'smart_playlist_episode_extractor.dart';
import 'smart_playlist_group_def.dart';
import 'smart_playlist_sort.dart';
import 'smart_playlist_title_extractor.dart';

/// Unified per-playlist definition with all fields strongly typed.
final class SmartPlaylistDefinition {
  const SmartPlaylistDefinition({
    required this.id,
    required this.displayName,
    required this.resolverType,
    required this.playlistStructure,
    this.priority = 0,
    this.episodeFilters,
    this.nullSeasonGroupKey,
    this.titleExtractor,
    this.prependSeasonNumber = false,
    this.groupList,
    this.episodeList,
    this.episodeExtractor,
    this.groups,
  });

  factory SmartPlaylistDefinition.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistDefinition(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      resolverType: json['resolverType'] as String,
      playlistStructure: json['playlistStructure'] as String,
      priority: (json['priority'] as int?) ?? 0,
      episodeFilters: json['episodeFilters'] != null
          ? EpisodeFilters.fromJson(
              json['episodeFilters'] as Map<String, dynamic>,
            )
          : null,
      nullSeasonGroupKey: json['nullSeasonGroupKey'] as int?,
      titleExtractor: json['titleExtractor'] != null
          ? SmartPlaylistTitleExtractor.fromJson(
              json['titleExtractor'] as Map<String, dynamic>,
            )
          : null,
      prependSeasonNumber:
          (json['prependSeasonNumber'] as bool?) ?? false,
      groupList: json['groupList'] != null
          ? GroupListSettings.fromJson(
              json['groupList'] as Map<String, dynamic>,
            )
          : null,
      episodeList: json['episodeList'] != null
          ? EpisodeListSettings.fromJson(
              json['episodeList'] as Map<String, dynamic>,
            )
          : null,
      episodeExtractor: json['episodeExtractor'] != null
          ? SmartPlaylistEpisodeExtractor.fromJson(
              json['episodeExtractor'] as Map<String, dynamic>,
            )
          : null,
      groups: (json['groups'] as List<dynamic>?)
          ?.map(
            (g) => SmartPlaylistGroupDef.fromJson(g as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String id;
  final String displayName;
  final String resolverType;

  /// How resolver results are organized: 'split' or 'grouped'.
  final String playlistStructure;

  /// Episode claiming order among siblings (lower = first, default: 0).
  final int priority;

  /// Episode filters applied before resolver processing.
  final EpisodeFilters? episodeFilters;

  /// Group key to assign to episodes with null season number.
  final int? nullSeasonGroupKey;

  /// Configuration for extracting playlist/group display names.
  final SmartPlaylistTitleExtractor? titleExtractor;

  /// Whether to prepend "S{n}" to resolver result names.
  final bool prependSeasonNumber;

  /// Settings for the group list view (grouped mode only).
  final GroupListSettings? groupList;

  /// Default episode list display and ordering settings.
  final EpisodeListSettings? episodeList;

  /// Configuration for extracting season and episode numbers.
  final SmartPlaylistEpisodeExtractor? episodeExtractor;

  /// Static group definitions for category-based grouping.
  final List<SmartPlaylistGroupDef>? groups;

  /// Whether this definition has any episode filters.
  bool get hasFilters => episodeFilters != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'resolverType': resolverType,
      'playlistStructure': playlistStructure,
      if (priority != 0) 'priority': priority,
      if (episodeFilters != null) 'episodeFilters': episodeFilters!.toJson(),
      if (nullSeasonGroupKey != null) 'nullSeasonGroupKey': nullSeasonGroupKey,
      if (titleExtractor != null) 'titleExtractor': titleExtractor!.toJson(),
      if (prependSeasonNumber) 'prependSeasonNumber': prependSeasonNumber,
      if (groupList != null) 'groupList': groupList!.toJson(),
      if (episodeList != null) 'episodeList': episodeList!.toJson(),
      if (episodeExtractor != null)
        'episodeExtractor': episodeExtractor!.toJson(),
      if (groups != null) 'groups': groups!.map((g) => g.toJson()).toList(),
    };
  }
}

/// Episode filters applied before resolver processing.
final class EpisodeFilters {
  const EpisodeFilters({this.require, this.exclude});

  factory EpisodeFilters.fromJson(Map<String, dynamic> json) {
    return EpisodeFilters(
      require: (json['require'] as List<dynamic>?)
          ?.map((e) =>
              EpisodeFilterEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      exclude: (json['exclude'] as List<dynamic>?)
          ?.map((e) =>
              EpisodeFilterEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<EpisodeFilterEntry>? require;
  final List<EpisodeFilterEntry>? exclude;

  Map<String, dynamic> toJson() {
    return {
      if (require != null) 'require': require!.map((e) => e.toJson()).toList(),
      if (exclude != null) 'exclude': exclude!.map((e) => e.toJson()).toList(),
    };
  }
}

/// A single filter condition matched against episode fields.
final class EpisodeFilterEntry {
  const EpisodeFilterEntry({this.title, this.description});

  factory EpisodeFilterEntry.fromJson(Map<String, dynamic> json) {
    return EpisodeFilterEntry(
      title: json['title'] as String?,
      description: json['description'] as String?,
    );
  }

  final String? title;
  final String? description;

  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    };
  }
}

/// Settings for the group list view (grouped mode only).
final class GroupListSettings {
  const GroupListSettings({
    this.yearBinding,
    this.userSortable,
    this.showDateRange,
    this.sort,
  });

  factory GroupListSettings.fromJson(Map<String, dynamic> json) {
    return GroupListSettings(
      yearBinding: json['yearBinding'] as String?,
      userSortable: json['userSortable'] as bool?,
      showDateRange: json['showDateRange'] as bool?,
      sort: json['sort'] != null
          ? SmartPlaylistSortRule.fromJson(
              json['sort'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// How groups relate to year headers. Default: 'none'.
  final String? yearBinding;

  /// Allow users to change sort order at runtime. Default: true.
  final bool? userSortable;

  /// Show date range on group cards. Default: false.
  final bool? showDateRange;

  /// Sort rule for ordering groups.
  final SmartPlaylistSortRule? sort;

  Map<String, dynamic> toJson() {
    return {
      if (yearBinding != null) 'yearBinding': yearBinding,
      if (userSortable != null) 'userSortable': userSortable,
      if (showDateRange != null) 'showDateRange': showDateRange,
      if (sort != null) 'sort': sort!.toJson(),
    };
  }
}

/// Default episode list display and ordering settings.
final class EpisodeListSettings {
  const EpisodeListSettings({
    this.showYearHeaders,
    this.sort,
    this.titleExtractor,
  });

  factory EpisodeListSettings.fromJson(Map<String, dynamic> json) {
    return EpisodeListSettings(
      showYearHeaders: json['showYearHeaders'] as bool?,
      sort: json['sort'] != null
          ? EpisodeSortRule.fromJson(json['sort'] as Map<String, dynamic>)
          : null,
      titleExtractor: json['titleExtractor'] != null
          ? SmartPlaylistTitleExtractor.fromJson(
              json['titleExtractor'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final bool? showYearHeaders;
  final EpisodeSortRule? sort;
  final SmartPlaylistTitleExtractor? titleExtractor;

  Map<String, dynamic> toJson() {
    return {
      if (showYearHeaders != null) 'showYearHeaders': showYearHeaders,
      if (sort != null) 'sort': sort!.toJson(),
      if (titleExtractor != null) 'titleExtractor': titleExtractor!.toJson(),
    };
  }
}
```

**Step 2:** Commit.

```
feat: restructure SmartPlaylistDefinition for v2 schema
```

---

## Task 6: Update SmartPlaylist and SmartPlaylistGroup runtime models

**Files:**
- Modify: `packages/sp_shared/lib/src/models/smart_playlist.dart`

Update enums and runtime models to use v2 naming.

**Step 1:** Update the file:

- Rename `SmartPlaylistContentType` to `PlaylistStructure` with values `split`, `grouped`
- Rename `YearHeaderMode` to `YearBinding` with values `none`, `pinToYear`, `splitByYear`
- Update `SmartPlaylist` field `contentType` -> `playlistStructure`, `yearHeaderMode` -> `yearBinding`, `showSeasonNumber` -> `prependSeasonNumber`, `showSortOrderToggle` -> `userSortable`
- Update `SmartPlaylistGroup.episodeYearHeaders` -> `showYearHeaders`
- Update `SmartPlaylist.episodeYearHeaders` -> field in `episodeList` context (or keep as `showYearHeaders` for consistency)

Note: These are runtime models consumed by the mobile app. The field names should align with v2 schema semantics but don't need to match JSON keys exactly (they're constructed in code, not deserialized from JSON).

**Step 2:** Commit.

```
feat: update SmartPlaylist runtime models for v2 naming
```

---

## Task 7: Update group_sorter.dart

**Files:**
- Modify: `packages/sp_shared/lib/src/services/group_sorter.dart`

The `sortGroups` function currently takes `SmartPlaylistSortSpec?` and handles multi-rule composite sorting with conditions. In v2, it takes a single `SmartPlaylistSortRule?`.

**Step 1:** Simplify the function:

```dart
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
  if (sortRule == null || 2 <= groups.length) {
    // Note: intentional -- only sort when 2+ groups exist
  }
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
```

**Step 2:** Commit.

```
refactor: simplify group_sorter for v2 single SortRule
```

---

## Task 8: Update SmartPlaylistResolverService

**Files:**
- Modify: `packages/sp_shared/lib/src/services/smart_playlist_resolver_service.dart`

The resolver service references v1 field names extensively. Update to use v2 fields.

**Step 1:** Key changes:
- `definition.contentType` -> `definition.playlistStructure`
- `definition.yearHeaderMode` -> `definition.groupList?.yearBinding`
- `definition.episodeYearHeaders` -> `definition.episodeList?.showYearHeaders ?? false`
- `definition.showDateRange` -> `definition.groupList?.showDateRange ?? false`
- `definition.customSort` -> `definition.groupList?.sort`
- `RssMetadataResolver.parseContentType()` -> `parsePlaylistStructure()` with `'grouped'`/`'split'` values
- `RssMetadataResolver.parseYearHeaderMode()` -> `parseYearBinding()` with new values
- `_hasFilters(def)` -> `def.hasFilters` (use the new getter)
- `_filterEpisodes()` -> rewrite to use `definition.episodeFilters`
- `SmartPlaylistContentType.groups` -> `PlaylistStructure.grouped`
- Pass `definition.groupList?.sort` to `sortGroups()` instead of `definition.customSort`
- `gDef?.episodeYearHeaders` -> `gDef?.episodeList?.showYearHeaders`
- `gDef?.showDateRange ?? definition.showDateRange` -> `gDef?.display?.showDateRange ?? definition.groupList?.showDateRange ?? false`

**Step 2:** Update `_filterEpisodes()` to work with `EpisodeFilters`:

```dart
List<EpisodeData> _filterEpisodes(
  List<EpisodeData> episodes,
  SmartPlaylistDefinition definition,
  Set<int> claimedIds,
) {
  final unclaimed = episodes.where((e) => !claimedIds.contains(e.id)).toList();
  final filters = definition.episodeFilters;

  if (filters == null) return unclaimed;

  return unclaimed.where((episode) {
    // All require entries must match
    if (filters.require != null) {
      for (final entry in filters.require!) {
        if (!_matchesFilterEntry(episode, entry)) return false;
      }
    }
    // No exclude entry must match
    if (filters.exclude != null) {
      for (final entry in filters.exclude!) {
        if (_matchesFilterEntry(episode, entry)) return false;
      }
    }
    return true;
  }).toList();
}

bool _matchesFilterEntry(EpisodeData episode, EpisodeFilterEntry entry) {
  if (entry.title != null) {
    final regex = RegExp(entry.title!, caseSensitive: false);
    if (!regex.hasMatch(episode.title)) return false;
  }
  if (entry.description != null) {
    final regex = RegExp(entry.description!, caseSensitive: false);
    if (!regex.hasMatch(episode.description ?? '')) return false;
  }
  return true;
}
```

**Step 3:** Update `RssMetadataResolver`:
- `parseContentType` -> `parsePlaylistStructure` accepting `'grouped'`/`'split'`
- `parseYearHeaderMode` -> `parseYearBinding` accepting `'pinToYear'`/`'splitByYear'`

**Step 4:** Commit.

```
feat: update resolver service and filters for v2 schema
```

---

## Task 9: Update Dart tests

**Files:**
- Modify: `packages/sp_shared/test/models/smart_playlist_definition_test.dart`
- Modify: `packages/sp_shared/test/models/smart_playlist_sort_test.dart`
- Modify: `packages/sp_shared/test/models/smart_playlist_sort_json_test.dart`
- Modify: `packages/sp_shared/test/schema/schema_conformance_test.dart`
- Check and update any other test files referencing v1 field names

The conformance test needs major updates because:
- `contentType` property no longer exists; now `playlistStructure`
- `yearHeaderMode` no longer exists; now nested in `groupList.yearBinding`
- `SortCondition` $def no longer exists
- `SortSpec` $def replaced by `SortRule`
- `SortRule.field` no longer contains `progress`
- New `$defs`: `EpisodeSortRule`, `YearBinding`, `SortOrder`
- `sortOrders` now extracted from `$defs/SortOrder` instead of `SortRule.properties.order`

**Step 1:** Update conformance test to match v2 schema structure.

**Step 2:** Update definition tests to use v2 field names (`playlistStructure`, `episodeFilters`, `groupList`, etc.)

**Step 3:** Rewrite sort tests to cover `SmartPlaylistSortRule` and `EpisodeSortRule` (no more `SortSpec`, `SortCondition`).

**Step 4:** Run all tests.

```bash
cd packages/sp_shared && dart test
```

**Step 5:** Commit.

```
test: update sp_shared tests for v2 schema
```

---

## Task 10: Update sp_react Zod schema

**Files:**
- Modify: `packages/sp_react/src/schemas/config-schema.ts`

**Step 1:** Rewrite the Zod schema to match v2:

Key changes:
- `contentTypeSchema` -> `playlistStructureSchema` with `['split', 'grouped']`
- `yearHeaderModeSchema` -> `yearBindingSchema` with `['none', 'pinToYear', 'splitByYear']`
- `sortFieldSchema` remove `'progress'`
- Add `episodeSortFieldSchema` with `['publishedAt', 'episodeNumber', 'title']`
- Remove `sortConditionSchema`
- `sortRuleSchema` loses `condition` field
- Remove `smartPlaylistSortSpecSchema` (no more wrapper with rules array)
- Add `episodeSortRuleSchema`
- Add `episodeFilterEntrySchema`
- Add `episodeFiltersSchema`
- Add `groupListSettingsSchema`
- Add `episodeListSettingsSchema`
- Restructure `groupDefSchema` with nested `display`, `episodeList`, `episodeExtractor`
- Restructure `playlistDefinitionSchema` with new field names

**Step 2:** Update all type exports.

**Step 3:** Commit.

```
feat: update sp_react Zod schema for v2
```

---

## Task 11: Update sp_react conformance tests

**Files:**
- Modify: `packages/sp_react/src/schemas/__tests__/schema-conformance.test.ts`

**Step 1:** Update all enum comparison tests to match v2 schema property locations:
- `playlistStructure` instead of `contentType`
- `$defs/YearBinding` instead of top-level `yearHeaderMode`
- `$defs/SortRule` field without `progress`
- `$defs/SortOrder` instead of inline in SortRule
- Add `EpisodeSortRule.field` test
- Remove `SortCondition` test

**Step 2:** Update validation tests (`minimal` and `full`) to use v2 field names and structure.

**Step 3:** Run tests.

```bash
cd packages/sp_react && pnpm test
```

**Step 4:** Commit.

```
test: update sp_react conformance tests for v2 schema
```

---

## Task 12: Update config-form.ts defaults

**Files:**
- Modify: `packages/sp_react/src/components/editor/config-form.tsx`

**Step 1:** Update `DEFAULT_PLAYLIST`:

```typescript
export const DEFAULT_PLAYLIST = {
  id: '',
  displayName: '',
  resolverType: '',
  playlistStructure: 'grouped',
  priority: 0,
  prependSeasonNumber: false,
} as const;
```

**Step 2:** Commit.

```
feat: update DEFAULT_PLAYLIST for v2 schema
```

---

## Task 13: Update sanitize-config.ts

**Files:**
- Modify: `packages/sp_react/src/lib/sanitize-config.ts`

**Step 1:** Remove the `customSort` special case (no longer needed -- `groupList.sort` is a single object, not an array). The generic empty-string stripping logic already handles the rest.

**Step 2:** Commit.

```
refactor: simplify sanitize-config for v2 schema
```

---

## Task 14: Update PlaylistForm component

**Files:**
- Modify: `packages/sp_react/src/components/editor/playlist-form.tsx`

Major restructuring needed:

**Step 1:** Update `StructureSettings`:
- Change `contentType` select to `playlistStructure` with values `'split'` / `'grouped'`
- Remove the `null` transform (playlistStructure is required, not nullable)
- Update `CONTENT_TYPES` constant -> `PLAYLIST_STRUCTURES = ['split', 'grouped']`

**Step 2:** Update `FilterSettings`:
- Replace three separate filter inputs (`titleFilter`, `excludeFilter`, `requireFilter`) with the new `episodeFilters.require[]` / `episodeFilters.exclude[]` array structure
- Each entry is `{ title?: string, description?: string }`
- Use `useFieldArray` for require and exclude arrays
- Keep regex tester functionality

**Step 3:** Update `DisplayOptions`:
- `episodeYearHeaders` -> `episodeList.showYearHeaders`
- `showDateRange` -> `groupList.showDateRange`
- `showSortOrderToggle` -> `groupList.userSortable`
- `showSeasonNumber` -> `prependSeasonNumber`
- `yearHeaderMode` -> `groupList.yearBinding` with new values (`none`/`pinToYear`/`splitByYear`)

**Step 4:** Commit.

```
feat: update PlaylistForm for v2 schema fields
```

---

## Task 15: Update SortForm and SortRuleCard

**Files:**
- Modify: `packages/sp_react/src/components/editor/sort-form.tsx`
- Modify: `packages/sp_react/src/components/editor/sort-rule-card.tsx`

**Step 1:** Update `SortForm`:
- Change field path from `playlists.${index}.customSort` to `playlists.${index}.groupList.sort`
- Simplify: instead of a rules array, it's now a single sort rule object `{ field, order }`
- Remove `useFieldArray` (no more rules array)
- Change condition check from `contentType === 'groups'` to `playlistStructure === 'grouped'`
- Single sort rule toggle + field/order selects (can inline instead of using SortRuleCard)

**Step 2:** Update `SortRuleCard` or remove it:
- Remove `condition` checkbox and condition value input
- Remove `progress` from SORT_FIELDS
- May be simplified enough to inline into SortForm

**Step 3:** Commit.

```
feat: simplify sort UI for v2 single SortRule
```

---

## Task 16: Update GroupDefCard

**Files:**
- Modify: `packages/sp_react/src/components/editor/group-def-card.tsx`

**Step 1:** Update display overrides section:
- `episodeYearHeaders` -> `episodeList.showYearHeaders`
- `showDateRange` -> `display.showDateRange`
- Add `display.yearBinding` select (optional)
- Add `episodeList.sort` (optional EpisodeSortRule)
- Add `episodeList.titleExtractor` (optional, same shape as top-level)
- Add `episodeExtractor` (optional)

Note: Start with just the boolean overrides (`showYearHeaders`, `showDateRange`). The new optional fields (`yearBinding`, `sort`, `titleExtractor`, `episodeExtractor`) can be added incrementally.

**Step 2:** Commit.

```
feat: update GroupDefCard overrides for v2 schema
```

---

## Task 17: Update i18n files

**Files:**
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`

**Step 1:** Add new keys and update changed keys:

English additions/changes:
```json
{
  "playlistStructure": "Playlist Structure",
  "playlistStructure_split": "Split",
  "playlistStructure_grouped": "Grouped",
  "prependSeasonNumber": "Prepend Season Number",
  "yearBinding": "Year Binding",
  "yearBinding_none": "None",
  "yearBinding_pinToYear": "Pin to Year",
  "yearBinding_splitByYear": "Split by Year",
  "userSortable": "User Sortable",
  "showYearHeaders": "Show Year Headers",
  "episodeFilters": "Episode Filters",
  "requireFilters": "Require Filters",
  "excludeFilters": "Exclude Filters",
  "addFilter": "Add Filter",
  "removeFilter": "Remove",
  "filterTitle": "Title Pattern",
  "filterDescription": "Description Pattern",
  "sortDisabledNote": "Sort only applies when playlist structure is Grouped."
}
```

Japanese equivalents:
```json
{
  "playlistStructure": "プレイリスト構造",
  "playlistStructure_split": "分割",
  "playlistStructure_grouped": "グループ",
  "prependSeasonNumber": "シーズン番号を先頭に表示",
  "yearBinding": "年バインディング",
  "yearBinding_none": "なし",
  "yearBinding_pinToYear": "年に固定",
  "yearBinding_splitByYear": "年ごとに分割",
  "userSortable": "ユーザーソート可能",
  "showYearHeaders": "年ヘッダーを表示",
  "episodeFilters": "エピソードフィルター",
  "requireFilters": "必須フィルター",
  "excludeFilters": "除外フィルター",
  "addFilter": "フィルターを追加",
  "removeFilter": "削除",
  "filterTitle": "タイトルパターン",
  "filterDescription": "説明パターン",
  "sortDisabledNote": "ソートはプレイリスト構造が「グループ」の場合にのみ適用されます。"
}
```

Remove obsolete keys: `contentType`, `contentType_episodes`, `contentType_groups`, `titleFilter`, `excludeFilter`, `requireFilter`, `showSortOrderToggle`, `showSeasonNumber`, `yearHeaderMode`, `yearHeaderMode_none`, `yearHeaderMode_firstEpisode`, `yearHeaderMode_perEpisode`, `episodeYearHeaders`, `sortField_progress`.

**Step 2:** Commit.

```
feat: update i18n keys for v2 schema
```

---

## Task 18: Run full test suite and fix

**Step 1:** Run Dart tests.

```bash
cd packages/sp_shared && dart test
```

**Step 2:** Run React tests.

```bash
cd packages/sp_react && pnpm test
```

**Step 3:** Run Dart analysis.

```bash
cd packages/sp_shared && dart analyze
```

**Step 4:** Fix any remaining issues.

**Step 5:** Commit.

```
fix: resolve remaining v2 migration issues
```

---

## Dependency Order

```
Task 1 (schema asset)
  -> Task 2 (constants)
  -> Task 3 (sort models)
  -> Task 4 (group def)
  -> Task 5 (definition)
  -> Task 6 (runtime models)
  -> Task 7 (group sorter)
  -> Task 8 (resolver service)
  -> Task 9 (Dart tests)
  -> Task 10 (Zod schema)       -> Task 11 (React conformance tests)
  -> Task 12 (config-form defaults)
  -> Task 13 (sanitize-config)
  -> Task 14 (PlaylistForm)
  -> Task 15 (SortForm)
  -> Task 16 (GroupDefCard)
  -> Task 17 (i18n)
  -> Task 18 (full test suite)
```

Tasks 10-17 can be done in parallel after Task 9 completes.
