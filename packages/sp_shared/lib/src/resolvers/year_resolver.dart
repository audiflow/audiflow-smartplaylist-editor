import '../models/episode_data.dart';
import '../models/smart_playlist.dart';
import '../models/smart_playlist_definition.dart';
import '../models/smart_playlist_sort.dart';
import '../models/smart_playlist_title_extractor.dart';
import 'smart_playlist_resolver.dart';

/// Resolver that groups episodes by publication year.
class YearResolver implements SmartPlaylistResolver {
  @override
  String get type => 'year';

  @override
  SmartPlaylistSortSpec get defaultSort => const SmartPlaylistSortSpec([
    SmartPlaylistSortRule(
      field: SmartPlaylistSortField.playlistNumber,
      order: SortOrder.descending, // Newest years first
    ),
  ]);

  @override
  SmartPlaylistGrouping? resolve(
    List<EpisodeData> episodes,
    SmartPlaylistDefinition? definition,
  ) {
    final grouped = <int, List<EpisodeData>>{};
    final ungrouped = <int>[];

    for (final episode in episodes) {
      final pubDate = episode.publishedAt;
      if (pubDate != null) {
        grouped.putIfAbsent(pubDate.year, () => []).add(episode);
      } else {
        ungrouped.add(episode.id);
      }
    }

    // Return null if no episodes have publish dates
    if (grouped.isEmpty) {
      return null;
    }

    final titleExtractor = definition?.titleExtractor;

    final playlists = grouped.entries.map((entry) {
      final playlistEpisodes = entry.value;
      final displayName = _extractDisplayName(
        year: entry.key,
        episodes: playlistEpisodes,
        titleExtractor: titleExtractor,
      );

      return SmartPlaylist(
        id: 'year_${entry.key}',
        displayName: displayName,
        sortKey: entry.key,
        episodeIds: playlistEpisodes.map((e) => e.id).toList(),
      );
    }).toList()..sort((a, b) => b.sortKey.compareTo(a.sortKey)); // Descending

    return SmartPlaylistGrouping(
      playlists: playlists,
      ungroupedEpisodeIds: ungrouped,
      resolverType: type,
    );
  }

  String _extractDisplayName({
    required int year,
    required List<EpisodeData> episodes,
    required SmartPlaylistTitleExtractor? titleExtractor,
  }) {
    if (titleExtractor == null || episodes.isEmpty) {
      return '$year';
    }

    // Try to extract title from first episode
    final extracted = titleExtractor.extract(episodes.first);
    return extracted ?? '$year';
  }
}
