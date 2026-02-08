import '../models/episode_data.dart';
import '../models/smart_playlist.dart';
import '../models/smart_playlist_definition.dart';
import '../models/smart_playlist_sort.dart';
import '../models/smart_playlist_title_extractor.dart';
import 'smart_playlist_resolver.dart';

/// Resolver that groups by title pattern with playlist order by
/// first appearance.
///
/// Useful for podcasts like:
/// - [Rome 1] First Steps
/// - [Rome 2] The Colosseum
/// - [Venezia 1] Arrival
///
/// Where "Rome" becomes playlist 1 (appeared first), "Venezia"
/// becomes playlist 2.
///
/// When a titleExtractor is provided in the definition, it uses that
/// to extract playlist names. Otherwise, falls back to the first
/// group's pattern with capture group 1.
class TitleAppearanceOrderResolver implements SmartPlaylistResolver {
  @override
  String get type => 'title_appearance';

  @override
  SmartPlaylistSortSpec get defaultSort => const SimpleSmartPlaylistSort(
    SmartPlaylistSortField.playlistNumber,
    SortOrder.ascending,
  );

  @override
  SmartPlaylistGrouping? resolve(
    List<EpisodeData> episodes,
    SmartPlaylistDefinition? definition,
  ) {
    if (definition == null) return null;

    final titleExtractor = definition.titleExtractor;
    final patternStr = definition.groups?.firstOrNull?.pattern;

    // Need either a titleExtractor or a group pattern
    if (titleExtractor == null && patternStr == null) {
      return null;
    }

    // Sort episodes by publish date (oldest first) to determine
    // appearance order
    final sorted = episodes.where((e) => e.publishedAt != null).toList()
      ..sort((a, b) => a.publishedAt!.compareTo(b.publishedAt!));

    final playlistOrder = <String>[];
    final grouped = <String, List<EpisodeData>>{};
    final ungrouped = <int>[];

    // Also process episodes without publish date at the end
    final allEpisodes = [
      ...sorted,
      ...episodes.where((e) => e.publishedAt == null),
    ];

    for (final episode in allEpisodes) {
      final playlistName = _extractPlaylistName(
        episode: episode,
        titleExtractor: titleExtractor,
        patternStr: patternStr,
      );

      if (playlistName != null) {
        if (!playlistOrder.contains(playlistName)) {
          playlistOrder.add(playlistName);
        }
        grouped.putIfAbsent(playlistName, () => []).add(episode);
      } else {
        ungrouped.add(episode.id);
      }
    }

    // Return null if no matches
    if (grouped.isEmpty) {
      return null;
    }

    final playlists = <SmartPlaylist>[];
    for (var i = 0; playlistOrder.length - i != 0; i++) {
      final name = playlistOrder[i];
      final playlistEpisodes = grouped[name]!;
      playlists.add(
        SmartPlaylist(
          id: 'season_${i + 1}',
          displayName: name,
          sortKey: i + 1,
          episodeIds: playlistEpisodes.map((e) => e.id).toList(),
        ),
      );
    }

    return SmartPlaylistGrouping(
      playlists: playlists,
      ungroupedEpisodeIds: ungrouped,
      resolverType: type,
    );
  }

  String? _extractPlaylistName({
    required EpisodeData episode,
    required SmartPlaylistTitleExtractor? titleExtractor,
    required String? patternStr,
  }) {
    // Try titleExtractor first if available
    if (titleExtractor != null) {
      return titleExtractor.extract(episode);
    }

    // Fall back to group pattern
    if (patternStr != null) {
      final regex = RegExp(patternStr);
      final match = regex.firstMatch(episode.title);
      if (match != null && 1 <= match.groupCount) {
        return match.group(1);
      }
    }

    return null;
  }
}
