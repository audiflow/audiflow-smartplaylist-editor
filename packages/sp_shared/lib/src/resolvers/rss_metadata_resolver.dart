import '../models/episode_data.dart';
import '../models/smart_playlist.dart';
import '../models/smart_playlist_definition.dart';
import '../models/smart_playlist_sort.dart';
import '../models/smart_playlist_title_extractor.dart';
import 'smart_playlist_resolver.dart';

/// Resolver that groups episodes using RSS metadata (seasonNumber field).
class RssMetadataResolver implements SmartPlaylistResolver {
  @override
  String get type => 'rss';

  @override
  SmartPlaylistSortSpec get defaultSort => const SmartPlaylistSortSpec([
    SmartPlaylistSortRule(
      field: SmartPlaylistSortField.playlistNumber,
      order: SortOrder.ascending,
    ),
  ]);

  @override
  SmartPlaylistGrouping? resolve(
    List<EpisodeData> episodes,
    SmartPlaylistDefinition? definition,
  ) {
    return _resolveBySeasonNumber(episodes, definition);
  }

  SmartPlaylistGrouping? _resolveBySeasonNumber(
    List<EpisodeData> episodes,
    SmartPlaylistDefinition? definition,
  ) {
    final grouped = <int, List<EpisodeData>>{};
    final ungrouped = <int>[];
    final groupNullAs = definition?.nullSeasonGroupKey;

    for (final episode in episodes) {
      final seasonNum = episode.seasonNumber;
      if (seasonNum != null && 1 <= seasonNum) {
        grouped.putIfAbsent(seasonNum, () => []).add(episode);
      } else if (groupNullAs != null) {
        grouped.putIfAbsent(groupNullAs, () => []).add(episode);
      } else {
        ungrouped.add(episode.id);
      }
    }

    if (grouped.isEmpty) return null;

    final titleExtractor = definition?.titleExtractor;

    final playlists = grouped.entries.map((entry) {
      final seasonNumber = entry.key;
      final playlistEpisodes = entry.value;
      final displayName = _extractDisplayName(
        seasonNumber: seasonNumber,
        episodes: playlistEpisodes,
        titleExtractor: titleExtractor,
      );
      return SmartPlaylist(
        id: 'season_$seasonNumber',
        displayName: displayName,
        sortKey: seasonNumber,
        episodeIds: playlistEpisodes.map((e) => e.id).toList(),
      );
    }).toList()..sort((a, b) => a.sortKey.compareTo(b.sortKey));

    return SmartPlaylistGrouping(
      playlists: playlists,
      ungroupedEpisodeIds: ungrouped,
      resolverType: type,
    );
  }

  static SmartPlaylistContentType parseContentType(String? value) {
    return switch (value) {
      'groups' => SmartPlaylistContentType.groups,
      _ => SmartPlaylistContentType.episodes,
    };
  }

  static YearHeaderMode parseYearHeaderMode(String? value) {
    return switch (value) {
      'firstEpisode' => YearHeaderMode.firstEpisode,
      'perEpisode' => YearHeaderMode.perEpisode,
      _ => YearHeaderMode.none,
    };
  }

  String _extractDisplayName({
    required int seasonNumber,
    required List<EpisodeData> episodes,
    required SmartPlaylistTitleExtractor? titleExtractor,
  }) {
    if (titleExtractor == null || episodes.isEmpty) {
      return 'Season $seasonNumber';
    }

    final extracted = titleExtractor.extract(episodes.first);
    return extracted ?? 'Season $seasonNumber';
  }
}
