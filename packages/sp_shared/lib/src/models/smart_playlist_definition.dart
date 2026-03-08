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
      prependSeasonNumber: (json['prependSeasonNumber'] as bool?) ?? false,
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

  /// Whether this definition has any effective episode filters.
  bool get hasFilters {
    if (episodeFilters == null) return false;
    final f = episodeFilters!;
    final hasRequire = f.require != null && f.require!.isNotEmpty;
    final hasExclude = f.exclude != null && f.exclude!.isNotEmpty;
    return hasRequire || hasExclude;
  }

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
          ?.map((e) => EpisodeFilterEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      exclude: (json['exclude'] as List<dynamic>?)
          ?.map((e) => EpisodeFilterEntry.fromJson(e as Map<String, dynamic>))
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
          ? SmartPlaylistSortRule.fromJson(json['sort'] as Map<String, dynamic>)
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
