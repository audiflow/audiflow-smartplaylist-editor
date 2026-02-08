import '../models/episode_data.dart';
import '../models/smart_playlist.dart';
import '../models/smart_playlist_definition.dart';
import '../models/smart_playlist_sort.dart';

/// Interface for smart playlist resolvers that group episodes into
/// smart playlists.
abstract class SmartPlaylistResolver {
  /// Unique identifier for this resolver type.
  String get type;

  /// Default sort specification for smart playlists produced by
  /// this resolver.
  SmartPlaylistSortSpec get defaultSort;

  /// Attempts to group episodes into smart playlists.
  ///
  /// Returns null if this resolver cannot handle the given
  /// episodes. The [definition] provides resolver-specific
  /// configuration when available.
  SmartPlaylistGrouping? resolve(
    List<EpisodeData> episodes,
    SmartPlaylistDefinition? definition,
  );
}
