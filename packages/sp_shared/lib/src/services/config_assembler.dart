import '../models/pattern_meta.dart';
import '../models/smart_playlist_definition.dart';
import '../models/smart_playlist_pattern_config.dart';

/// Assembles a [SmartPlaylistPatternConfig] from split config files.
///
/// Combines a [PatternMeta] with its playlist definitions into
/// the unified config that resolvers expect.
final class ConfigAssembler {
  ConfigAssembler._();

  /// Assembles a full config from pattern metadata and playlist
  /// definitions.
  ///
  /// Playlists are ordered according to [meta.playlists]. Any
  /// playlists not listed in meta are appended at the end.
  static SmartPlaylistPatternConfig assemble(
    PatternMeta meta,
    List<SmartPlaylistDefinition> playlists,
  ) {
    final playlistMap = {for (final p in playlists) p.id: p};

    final ordered = <SmartPlaylistDefinition>[];
    for (final id in meta.playlists) {
      final playlist = playlistMap.remove(id);
      if (playlist != null) {
        ordered.add(playlist);
      }
    }
    // Append any remaining playlists not in meta order
    ordered.addAll(playlistMap.values);

    return SmartPlaylistPatternConfig(
      id: meta.id,
      podcastGuid: meta.podcastGuid,
      feedUrls: meta.feedUrls,
      yearGroupedEpisodes: meta.yearGroupedEpisodes,
      playlists: ordered,
    );
  }
}
