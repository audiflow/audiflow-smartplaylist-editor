import '../models/episode_data.dart';
import '../models/preview_grouping.dart';
import '../models/smart_playlist.dart';
import '../models/smart_playlist_definition.dart';
import '../models/smart_playlist_group_def.dart';
import '../models/smart_playlist_pattern_config.dart';
import '../resolvers/rss_metadata_resolver.dart';
import '../resolvers/smart_playlist_resolver.dart';
import 'episode_sorter.dart';

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
      final result = _resolveWithConfig(config, episodes);
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
    final result = _resolveWithConfigForPreview(config, episodes);
    if (result == null) return null;

    return _sortPreviewGrouping(result, episodeById);
  }

  /// Preview variant of [_resolveWithConfig] that tracks claimed episodes.
  PreviewGrouping? _resolveWithConfigForPreview(
    SmartPlaylistPatternConfig config,
    List<EpisodeData> episodes,
  ) {
    final playlistResults = <PlaylistPreviewResult>[];
    final allUngroupedIds = <int>{};
    final claimedIds = <int>{};
    final claimedByMap = <int, String>{};
    String? resolverType;

    final sorted = _sortByProcessingOrder(config.playlists);

    for (final definition in sorted) {
      final hasFilters =
          definition.titleFilter != null ||
          definition.excludeFilter != null ||
          definition.requireFilter != null;

      // Compute claimedByOthers for definitions with filters
      final claimedByOthers = <int, String>{};
      if (hasFilters) {
        final allCandidates = _filterEpisodes(episodes, definition, {});
        for (final ep in allCandidates) {
          if (claimedIds.contains(ep.id)) {
            claimedByOthers[ep.id] = claimedByMap[ep.id]!;
          }
        }
      }

      final filtered = _filterEpisodes(episodes, definition, claimedIds);

      if (filtered.isEmpty) {
        // Still emit a result entry so the UI knows about claimed episodes
        playlistResults.add(
          PlaylistPreviewResult(
            definitionId: definition.id,
            playlist: SmartPlaylist(
              id: definition.id,
              displayName: definition.displayName,
              sortKey: playlistResults.length,
              episodeIds: const [],
            ),
            claimedByOthers: claimedByOthers,
          ),
        );
        continue;
      }

      final resolver = _findResolverByType(definition.resolverType);
      if (resolver == null) continue;

      final result = resolver.resolve(filtered, definition);
      if (result == null) continue;

      resolverType ??= result.resolverType;

      final contentType = RssMetadataResolver.parseContentType(
        definition.contentType,
      );
      final yearHeaderMode = RssMetadataResolver.parseYearHeaderMode(
        definition.yearHeaderMode,
      );

      // Build one SmartPlaylist per definition for the preview result.
      // Groups mode: resolver playlists become groups inside one playlist.
      // Episodes mode: resolver playlists become groups to maintain
      // the 1:1 mapping of definition -> PlaylistPreviewResult.
      final groups = result.playlists.map((p) {
        return SmartPlaylistGroup(
          id: p.id,
          displayName: p.displayName,
          sortKey: p.sortKey,
          episodeIds: p.episodeIds,
          thumbnailUrl: p.thumbnailUrl,
        );
      }).toList();
      final allEpisodeIds = groups.expand((g) => g.episodeIds).toList();

      final playlist = SmartPlaylist(
        id: definition.id,
        displayName: definition.displayName,
        sortKey: playlistResults.length,
        episodeIds: allEpisodeIds,
        contentType: contentType,
        yearHeaderMode: yearHeaderMode,
        episodeYearHeaders: definition.episodeYearHeaders,
        showDateRange: definition.showDateRange,
        groups: groups,
      );

      playlistResults.add(
        PlaylistPreviewResult(
          definitionId: definition.id,
          playlist: playlist,
          claimedByOthers: claimedByOthers,
        ),
      );

      allUngroupedIds.addAll(result.ungroupedEpisodeIds);

      if (hasFilters) {
        for (final p in result.playlists) {
          for (final id in p.episodeIds) {
            claimedIds.add(id);
            claimedByMap[id] = definition.id;
          }
        }
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

      final contentType = RssMetadataResolver.parseContentType(
        definition.contentType,
      );
      final yearHeaderMode = RssMetadataResolver.parseYearHeaderMode(
        definition.yearHeaderMode,
      );

      // When contentType is "groups", the resolver's playlists
      // become groups inside a single parent playlist named after
      // the definition.
      if (contentType == SmartPlaylistContentType.groups) {
        final groupDefMap = {
          for (final g in definition.groups ?? <SmartPlaylistGroupDef>[])
            g.id: g,
        };
        final groups = result.playlists.map((p) {
          final gDef = groupDefMap[p.id];
          return SmartPlaylistGroup(
            id: p.id,
            displayName: p.displayName,
            sortKey: p.sortKey,
            episodeIds: p.episodeIds,
            thumbnailUrl: p.thumbnailUrl,
            episodeYearHeaders: gDef?.episodeYearHeaders,
            showDateRange: gDef?.showDateRange ?? definition.showDateRange,
          );
        }).toList();
        final allEpisodeIds = groups.expand((g) => g.episodeIds).toList();

        allPlaylists.add(
          SmartPlaylist(
            id: definition.id,
            displayName: definition.displayName,
            sortKey: allPlaylists.length,
            episodeIds: allEpisodeIds,
            contentType: contentType,
            yearHeaderMode: yearHeaderMode,
            episodeYearHeaders: definition.episodeYearHeaders,
            showDateRange: definition.showDateRange,
            groups: groups,
          ),
        );
      } else {
        // Episodes mode: each resolver playlist is a top-level
        // smart playlist.
        final decorated = result.playlists.map((playlist) {
          return playlist.copyWith(
            contentType: contentType,
            yearHeaderMode: yearHeaderMode,
            episodeYearHeaders: definition.episodeYearHeaders,
            showDateRange: definition.showDateRange,
          );
        }).toList();
        allPlaylists.addAll(decorated);
      }

      allUngroupedIds.addAll(result.ungroupedEpisodeIds);

      // Only claim episode IDs when the definition has explicit
      // filters. Fallback definitions (no filters) receive all
      // unclaimed episodes without preventing other fallbacks
      // from also receiving them.
      final hasFilters =
          definition.titleFilter != null ||
          definition.excludeFilter != null ||
          definition.requireFilter != null;
      if (hasFilters) {
        for (final p in result.playlists) {
          claimedIds.addAll(p.episodeIds);
        }
      }
    }

    if (allPlaylists.isEmpty) return null;

    // Remove from ungrouped any IDs that ended up in a playlist
    allUngroupedIds.removeAll(claimedIds);

    return SmartPlaylistGrouping(
      playlists: allPlaylists,
      ungroupedEpisodeIds: allUngroupedIds.toList(),
      resolverType: resolverType ?? 'config',
    );
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

    final hasTitleFilter = definition.titleFilter != null;
    final hasExcludeFilter = definition.excludeFilter != null;
    final hasRequireFilter = definition.requireFilter != null;

    // No filters means fallback: gets all unclaimed episodes
    if (!hasTitleFilter && !hasExcludeFilter && !hasRequireFilter) {
      return unclaimed;
    }

    final titleRegex = hasTitleFilter ? RegExp(definition.titleFilter!) : null;
    final excludeRegex = hasExcludeFilter
        ? RegExp(definition.excludeFilter!)
        : null;
    final requireRegex = hasRequireFilter
        ? RegExp(definition.requireFilter!)
        : null;

    return unclaimed.where((episode) {
      final title = episode.title;
      if (titleRegex != null && !titleRegex.hasMatch(title)) {
        return false;
      }
      if (excludeRegex != null && excludeRegex.hasMatch(title)) {
        return false;
      }
      if (requireRegex != null && !requireRegex.hasMatch(title)) {
        return false;
      }
      return true;
    }).toList();
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
      if (_hasFilters(def)) {
        filtered.add(def);
      } else {
        fallbacks.add(def);
      }
    }

    filtered.sort((a, b) => a.priority.compareTo(b.priority));
    fallbacks.sort((a, b) => a.priority.compareTo(b.priority));

    return [...filtered, ...fallbacks];
  }

  static bool _hasFilters(SmartPlaylistDefinition definition) {
    return definition.titleFilter != null ||
        definition.excludeFilter != null ||
        definition.requireFilter != null;
  }
}
