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
  const GroupDefDisplay({this.showDateRange, this.yearBinding});

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
