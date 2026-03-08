import '../models/episode_data.dart';
import '../models/preview_grouping.dart';
import '../models/smart_playlist.dart';
import '../models/smart_playlist_definition.dart';
import '../models/smart_playlist_group_def.dart';
import '../models/smart_playlist_pattern_config.dart';
import '../resolvers/rss_metadata_resolver.dart';
import '../resolvers/smart_playlist_resolver.dart';
import 'episode_sorter.dart';
import 'group_sorter.dart';

/// Service that orchestrates the smart playlist resolver chain.
///
/// When a [SmartPlaylistPatternConfig] matches the podcast, its
/// playlist definitions are used to route episodes through the
/// appropriate resolvers. Otherwise, resolvers are tried in order
/// with no definition (auto-detect mode).
class SmartPlaylistResolverService {
  SmartPlaylistResolverService({
    required List<SmartPlaylistResolver> resolvers,
    required List<SmartPlaylistPatternConfig> patterns,
  }) : _resolvers = resolvers,
       _patterns = patterns;

  final List<SmartPlaylistResolver> _resolvers;
  final List<SmartPlaylistPatternConfig> _patterns;

  /// Attempts to group episodes into smart playlists.
  ///
  /// Returns null if no resolver succeeds.
  SmartPlaylistGrouping? resolveSmartPlaylists({
    required String? podcastGuid,
    required String feedUrl,
    required List<EpisodeData> episodes,
  }) {
    if (episodes.isEmpty) return null;

    final episodeById = {for (final e in episodes) e.id: e};

    final config = _findMatchingConfig(podcastGuid, feedUrl);
    if (config != null) {
      final result = _resolveWithConfig(config, episodes, episodeById);
      if (result != null) return _sortGroupingEpisodes(result, episodeById);
      return null;
    }

    // Fallback: try resolvers in order with no definition
    for (final resolver in _resolvers) {
      final result = resolver.resolve(episodes, null);
      if (result != null) return _sortGroupingEpisodes(result, episodeById);
    }

    return null;
  }

  /// Resolves smart playlists for preview, tracking which episodes
  /// each definition lost to higher-priority definitions.
  ///
  /// Returns null if no config matches or episodes are empty.
  PreviewGrouping? resolveForPreview({
    required String? podcastGuid,
    required String feedUrl,
    required List<EpisodeData> episodes,
  }) {
    if (episodes.isEmpty) return null;

    final config = _findMatchingConfig(podcastGuid, feedUrl);
    if (config == null) return null;

    final episodeById = {for (final e in episodes) e.id: e};
    final result = _resolveWithConfigForPreview(config, episodes, episodeById);
    if (result == null) return null;

    return _sortPreviewGrouping(result, episodeById);
  }

  /// Preview variant of [_resolveWithConfig] that tracks claimed episodes.
  PreviewGrouping? _resolveWithConfigForPreview(
    SmartPlaylistPatternConfig config,
    List<EpisodeData> episodes,
    Map<int, EpisodeData> episodeById,
  ) {
    final playlistResults = <PlaylistPreviewResult>[];
    final allUngroupedIds = <int>{};
    final claimedIds = <int>{};
    final claimedByMap = <int, String>{};
    String? resolverType;

    final sorted = _sortByProcessingOrder(config.playlists);

    for (final definition in sorted) {
      final claimedByOthers = _computeClaimedByOthers(
        definition,
        episodes,
        claimedIds,
        claimedByMap,
      );

      final filtered = _filterEpisodes(episodes, definition, claimedIds);

      if (filtered.isEmpty) {
        _addEmptyPreviewResult(
          playlistResults,
          definition,
          claimedByOthers,
        );
        continue;
      }

      final resolver = _findResolverByType(definition.resolverType);
      if (resolver == null) continue;

      final result = resolver.resolve(filtered, definition);
      if (result == null) continue;

      resolverType ??= result.resolverType;

      final playlist = _buildPreviewPlaylist(
        definition,
        result,
        playlistResults.length,
        episodeById,
      );

      playlistResults.add(
        PlaylistPreviewResult(
          definitionId: definition.id,
          playlist: playlist,
          claimedByOthers: claimedByOthers,
        ),
      );

      allUngroupedIds.addAll(result.ungroupedEpisodeIds);

      if (definition.hasFilters) {
        _claimEpisodes(result, definition.id, claimedIds, claimedByMap);
      }
    }

    if (playlistResults.isEmpty) return null;

    allUngroupedIds.removeAll(claimedIds);

    return PreviewGrouping(
      playlistResults: playlistResults,
      ungroupedEpisodeIds: allUngroupedIds.toList(),
      resolverType: resolverType ?? 'config',
    );
  }

  Map<int, String> _computeClaimedByOthers(
    SmartPlaylistDefinition definition,
    List<EpisodeData> episodes,
    Set<int> claimedIds,
    Map<int, String> claimedByMap,
  ) {
    final claimedByOthers = <int, String>{};
    if (!definition.hasFilters) return claimedByOthers;

    final allCandidates = _filterEpisodes(episodes, definition, {});
    for (final ep in allCandidates) {
      if (claimedIds.contains(ep.id)) {
        claimedByOthers[ep.id] = claimedByMap[ep.id]!;
      }
    }
    return claimedByOthers;
  }

  void _addEmptyPreviewResult(
    List<PlaylistPreviewResult> results,
    SmartPlaylistDefinition definition,
    Map<int, String> claimedByOthers,
  ) {
    results.add(
      PlaylistPreviewResult(
        definitionId: definition.id,
        playlist: SmartPlaylist(
          id: definition.id,
          displayName: definition.displayName,
          sortKey: results.length,
          episodeIds: const [],
        ),
        claimedByOthers: claimedByOthers,
      ),
    );
  }

  SmartPlaylist _buildPreviewPlaylist(
    SmartPlaylistDefinition definition,
    SmartPlaylistGrouping result,
    int sortKey,
    Map<int, EpisodeData> episodeById,
  ) {
    final structure = RssMetadataResolver.parsePlaylistStructure(
      definition.playlistStructure,
    );
    final yearBinding = RssMetadataResolver.parseYearBinding(
      definition.groupList?.yearBinding,
    );

    final unsortedGroups = result.playlists.map((p) {
      return SmartPlaylistGroup(
        id: p.id,
        displayName: p.displayName,
        sortKey: p.sortKey,
        episodeIds: p.episodeIds,
        thumbnailUrl: p.thumbnailUrl,
      );
    }).toList();
    final groups = sortGroups(
      unsortedGroups,
      definition.groupList?.sort,
      episodeById,
    );
    final allEpisodeIds = groups.expand((g) => g.episodeIds).toList();

    return SmartPlaylist(
      id: definition.id,
      displayName: definition.displayName,
      sortKey: sortKey,
      episodeIds: allEpisodeIds,
      playlistStructure: structure,
      yearBinding: yearBinding,
      showYearHeaders: definition.episodeList?.showYearHeaders ?? false,
      showDateRange: definition.groupList?.showDateRange ?? false,
      groups: groups,
    );
  }

  void _claimEpisodes(
    SmartPlaylistGrouping result,
    String definitionId,
    Set<int> claimedIds,
    Map<int, String> claimedByMap,
  ) {
    for (final p in result.playlists) {
      for (final id in p.episodeIds) {
        claimedIds.add(id);
        claimedByMap[id] = definitionId;
      }
    }
  }

  /// Sorts episode IDs in every playlist and group within a
  /// [PreviewGrouping] by [EpisodeData.publishedAt] ascending.
  PreviewGrouping _sortPreviewGrouping(
    PreviewGrouping grouping,
    Map<int, EpisodeData> episodeById,
  ) {
    final sortedResults = grouping.playlistResults.map((previewResult) {
      final playlist = previewResult.playlist;
      final sortedGroups = playlist.groups?.map((group) {
        return group.copyWith(
          episodeIds: sortEpisodeIdsByPublishedAt(
            group.episodeIds,
            episodeById,
          ),
        );
      }).toList();

      return PlaylistPreviewResult(
        definitionId: previewResult.definitionId,
        playlist: playlist.copyWith(
          episodeIds: sortEpisodeIdsByPublishedAt(
            playlist.episodeIds,
            episodeById,
          ),
          groups: sortedGroups,
        ),
        claimedByOthers: previewResult.claimedByOthers,
      );
    }).toList();

    return PreviewGrouping(
      playlistResults: sortedResults,
      ungroupedEpisodeIds: sortEpisodeIdsByPublishedAt(
        grouping.ungroupedEpisodeIds,
        episodeById,
      ),
      resolverType: grouping.resolverType,
    );
  }

  /// Resolves playlists using a matched pattern config.
  SmartPlaylistGrouping? _resolveWithConfig(
    SmartPlaylistPatternConfig config,
    List<EpisodeData> episodes,
    Map<int, EpisodeData> episodeById,
  ) {
    final allPlaylists = <SmartPlaylist>[];
    final allUngroupedIds = <int>{};
    final claimedIds = <int>{};
    String? resolverType;

    final sorted = _sortByProcessingOrder(config.playlists);

    for (final definition in sorted) {
      final filtered = _filterEpisodes(episodes, definition, claimedIds);
      if (filtered.isEmpty) continue;

      final resolver = _findResolverByType(definition.resolverType);
      if (resolver == null) continue;

      final result = resolver.resolve(filtered, definition);
      if (result == null) continue;

      resolverType ??= result.resolverType;

      final structure = RssMetadataResolver.parsePlaylistStructure(
        definition.playlistStructure,
      );
      final yearBinding = RssMetadataResolver.parseYearBinding(
        definition.groupList?.yearBinding,
      );

      if (structure == PlaylistStructure.grouped) {
        _addGroupedPlaylist(
          allPlaylists,
          definition,
          result,
          structure,
          yearBinding,
          episodeById,
        );
      } else {
        _addSplitPlaylists(
          allPlaylists,
          definition,
          result,
          structure,
          yearBinding,
        );
      }

      allUngroupedIds.addAll(result.ungroupedEpisodeIds);

      if (definition.hasFilters) {
        for (final p in result.playlists) {
          claimedIds.addAll(p.episodeIds);
        }
      }
    }

    if (allPlaylists.isEmpty) return null;

    allUngroupedIds.removeAll(claimedIds);

    return SmartPlaylistGrouping(
      playlists: allPlaylists,
      ungroupedEpisodeIds: allUngroupedIds.toList(),
      resolverType: resolverType ?? 'config',
    );
  }

  void _addGroupedPlaylist(
    List<SmartPlaylist> allPlaylists,
    SmartPlaylistDefinition definition,
    SmartPlaylistGrouping result,
    PlaylistStructure structure,
    YearBinding yearBinding,
    Map<int, EpisodeData> episodeById,
  ) {
    final groupDefMap = {
      for (final g in definition.groups ?? <SmartPlaylistGroupDef>[]) g.id: g,
    };
    final unsortedGroups = result.playlists.map((p) {
      final gDef = groupDefMap[p.id];
      return SmartPlaylistGroup(
        id: p.id,
        displayName: p.displayName,
        sortKey: p.sortKey,
        episodeIds: p.episodeIds,
        thumbnailUrl: p.thumbnailUrl,
        showYearHeaders: gDef?.episodeList?.showYearHeaders,
        showDateRange:
            gDef?.display?.showDateRange ??
            definition.groupList?.showDateRange ??
            false,
      );
    }).toList();
    final groups = sortGroups(
      unsortedGroups,
      definition.groupList?.sort,
      episodeById,
    );
    final allEpisodeIds = groups.expand((g) => g.episodeIds).toList();

    allPlaylists.add(
      SmartPlaylist(
        id: definition.id,
        displayName: definition.displayName,
        sortKey: allPlaylists.length,
        episodeIds: allEpisodeIds,
        playlistStructure: structure,
        yearBinding: yearBinding,
        showYearHeaders: definition.episodeList?.showYearHeaders ?? false,
        showDateRange: definition.groupList?.showDateRange ?? false,
        groups: groups,
      ),
    );
  }

  void _addSplitPlaylists(
    List<SmartPlaylist> allPlaylists,
    SmartPlaylistDefinition definition,
    SmartPlaylistGrouping result,
    PlaylistStructure structure,
    YearBinding yearBinding,
  ) {
    final decorated = result.playlists.map((playlist) {
      return playlist.copyWith(
        playlistStructure: structure,
        yearBinding: yearBinding,
        showYearHeaders: definition.episodeList?.showYearHeaders ?? false,
        showDateRange: definition.groupList?.showDateRange ?? false,
      );
    }).toList();
    allPlaylists.addAll(decorated);
  }

  /// Sorts episode IDs in every playlist, group, and ungrouped list
  /// by [EpisodeData.publishedAt] ascending (oldest first).
  SmartPlaylistGrouping _sortGroupingEpisodes(
    SmartPlaylistGrouping grouping,
    Map<int, EpisodeData> episodeById,
  ) {
    final sortedPlaylists = grouping.playlists.map((playlist) {
      final sortedGroups = playlist.groups?.map((group) {
        return group.copyWith(
          episodeIds: sortEpisodeIdsByPublishedAt(
            group.episodeIds,
            episodeById,
          ),
        );
      }).toList();

      return playlist.copyWith(
        episodeIds: sortEpisodeIdsByPublishedAt(
          playlist.episodeIds,
          episodeById,
        ),
        groups: sortedGroups,
      );
    }).toList();

    return SmartPlaylistGrouping(
      playlists: sortedPlaylists,
      ungroupedEpisodeIds: sortEpisodeIdsByPublishedAt(
        grouping.ungroupedEpisodeIds,
        episodeById,
      ),
      resolverType: grouping.resolverType,
    );
  }

  /// Filters episodes based on definition routing rules.
  ///
  /// Episodes already claimed by a higher-priority definition
  /// are excluded. A definition with no filters acts as a
  /// fallback, receiving all unclaimed episodes.
  List<EpisodeData> _filterEpisodes(
    List<EpisodeData> episodes,
    SmartPlaylistDefinition definition,
    Set<int> claimedIds,
  ) {
    final unclaimed = episodes
        .where((e) => !claimedIds.contains(e.id))
        .toList();
    final filters = definition.episodeFilters;
    if (filters == null) return unclaimed;

    return unclaimed.where((episode) {
      if (!_matchesRequireFilters(episode, filters.require)) return false;
      if (_matchesAnyExcludeFilter(episode, filters.exclude)) return false;
      return true;
    }).toList();
  }

  bool _matchesRequireFilters(
    EpisodeData episode,
    List<EpisodeFilterEntry>? entries,
  ) {
    if (entries == null) return true;
    return entries.every((entry) => _matchesFilterEntry(episode, entry));
  }

  bool _matchesAnyExcludeFilter(
    EpisodeData episode,
    List<EpisodeFilterEntry>? entries,
  ) {
    if (entries == null) return false;
    return entries.any((entry) => _matchesFilterEntry(episode, entry));
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

  SmartPlaylistPatternConfig? _findMatchingConfig(
    String? guid,
    String feedUrl,
  ) {
    for (final config in _patterns) {
      if (config.matchesPodcast(guid, feedUrl)) {
        return config;
      }
    }
    return null;
  }

  SmartPlaylistResolver? _findResolverByType(String type) {
    for (final resolver in _resolvers) {
      if (resolver.type == type) {
        return resolver;
      }
    }
    return null;
  }

  /// Sorts definitions so filtered definitions process before fallbacks.
  /// Within each group, sorts by priority ascending (lower number first).
  static List<SmartPlaylistDefinition> _sortByProcessingOrder(
    List<SmartPlaylistDefinition> definitions,
  ) {
    final filtered = <SmartPlaylistDefinition>[];
    final fallbacks = <SmartPlaylistDefinition>[];

    for (final def in definitions) {
      if (def.hasFilters) {
        filtered.add(def);
      } else {
        fallbacks.add(def);
      }
    }

    filtered.sort((a, b) => a.priority.compareTo(b.priority));
    fallbacks.sort((a, b) => a.priority.compareTo(b.priority));

    return [...filtered, ...fallbacks];
  }
}
