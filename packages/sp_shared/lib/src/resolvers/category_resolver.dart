import '../models/episode_data.dart';
import '../models/smart_playlist.dart';
import '../models/smart_playlist_definition.dart';
import '../models/smart_playlist_group_def.dart';
import '../models/smart_playlist_sort.dart';
import 'smart_playlist_resolver.dart';

/// Resolver that groups episodes into predefined categories
/// by title pattern.
///
/// Reads group definitions from the definition's [groups] field.
/// Each group has a regex pattern, display name, and sort key.
/// Episodes are matched against groups in order (first match wins).
/// Groups without a pattern act as catch-all fallbacks.
class CategoryResolver implements SmartPlaylistResolver {
  @override
  String get type => 'category';

  @override
  SmartPlaylistSortRule get defaultSort => const SmartPlaylistSortRule(
    field: SmartPlaylistSortField.playlistNumber,
    order: SortOrder.ascending,
  );

  @override
  SmartPlaylistGrouping? resolve(
    List<EpisodeData> episodes,
    SmartPlaylistDefinition? definition,
  ) {
    if (definition == null) return null;

    final groupDefs = definition.groups;
    if (groupDefs == null || groupDefs.isEmpty) return null;

    return _resolveWithGroups(episodes, groupDefs);
  }

  SmartPlaylistGrouping? _resolveWithGroups(
    List<EpisodeData> episodes,
    List<SmartPlaylistGroupDef> groupDefs,
  ) {
    final patternGroups = _buildPatternGroups(groupDefs);
    String? fallbackId;
    String? fallbackDisplayName;
    bool? fallbackShowYearHeaders;

    for (final g in groupDefs) {
      if (g.pattern == null) {
        fallbackId = g.id;
        fallbackDisplayName = g.displayName;
        fallbackShowYearHeaders = g.episodeList?.showYearHeaders;
        break;
      }
    }

    final grouped = <String, List<int>>{};
    final fallbackIds = <int>[];
    final ungrouped = <int>[];

    for (final episode in episodes) {
      var matched = false;
      for (final pg in patternGroups) {
        if (pg.regex.hasMatch(episode.title)) {
          grouped.putIfAbsent(pg.id, () => []).add(episode.id);
          matched = true;
          break;
        }
      }
      if (!matched) {
        if (fallbackId != null) {
          fallbackIds.add(episode.id);
        } else {
          ungrouped.add(episode.id);
        }
      }
    }

    final groups = _buildGroups(patternGroups, grouped);
    if (fallbackIds.isNotEmpty) {
      groups.add(
        SmartPlaylistGroup(
          id: fallbackId!,
          displayName: fallbackDisplayName!,
          sortKey: groups.length + 1,
          episodeIds: fallbackIds,
          showYearHeaders: fallbackShowYearHeaders,
        ),
      );
    }

    if (groups.isEmpty && ungrouped.isEmpty) return null;

    final playlists = groups
        .map(
          (g) => SmartPlaylist(
            id: g.id,
            displayName: g.displayName,
            sortKey: g.sortKey,
            episodeIds: g.episodeIds,
          ),
        )
        .toList();

    return SmartPlaylistGrouping(
      playlists: playlists,
      ungroupedEpisodeIds: ungrouped,
      resolverType: type,
    );
  }

  List<_PatternGroup> _buildPatternGroups(
    List<SmartPlaylistGroupDef> groupDefs,
  ) {
    return groupDefs
        .where((g) => g.pattern != null)
        .map(
          (g) => _PatternGroup(
            regex: RegExp(g.pattern!),
            id: g.id,
            displayName: g.displayName,
            showYearHeaders: g.episodeList?.showYearHeaders,
          ),
        )
        .toList();
  }

  List<SmartPlaylistGroup> _buildGroups(
    List<_PatternGroup> patternGroups,
    Map<String, List<int>> grouped,
  ) {
    final groups = <SmartPlaylistGroup>[];
    var sortKey = 1;
    for (final pg in patternGroups) {
      final ids = grouped[pg.id];
      if (ids != null && ids.isNotEmpty) {
        groups.add(
          SmartPlaylistGroup(
            id: pg.id,
            displayName: pg.displayName,
            sortKey: sortKey,
            episodeIds: ids,
            showYearHeaders: pg.showYearHeaders,
          ),
        );
        sortKey++;
      }
    }
    return groups;
  }

  static PlaylistStructure parsePlaylistStructure(String? value) {
    return switch (value) {
      'grouped' => PlaylistStructure.grouped,
      _ => PlaylistStructure.split,
    };
  }

  static YearBinding parseYearBinding(String? value) {
    return switch (value) {
      'pinToYear' => YearBinding.pinToYear,
      'splitByYear' => YearBinding.splitByYear,
      _ => YearBinding.none,
    };
  }
}

class _PatternGroup {
  const _PatternGroup({
    required this.regex,
    required this.id,
    required this.displayName,
    this.showYearHeaders,
  });

  final RegExp regex;
  final String id;
  final String displayName;
  final bool? showYearHeaders;
}
