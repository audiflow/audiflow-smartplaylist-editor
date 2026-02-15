import 'smart_playlist.dart';

/// Preview-specific wrapper for a single playlist definition's
/// resolution result, including episodes that were claimed by
/// higher-priority definitions.
final class PlaylistPreviewResult {
  const PlaylistPreviewResult({
    required this.definitionId,
    required this.playlist,
    required this.claimedByOthers,
  });

  /// The playlist definition ID this result corresponds to.
  final String definitionId;

  /// The resolved playlist (groups, episodes, etc).
  final SmartPlaylist playlist;

  /// Episodes that matched this definition's filters but were
  /// already claimed by a higher-priority definition.
  /// Maps episode ID to the claiming definition's ID.
  final Map<int, String> claimedByOthers;
}

/// Preview-specific grouping that includes per-playlist
/// claimed-episode tracking alongside the standard resolution
/// output.
final class PreviewGrouping {
  const PreviewGrouping({
    required this.playlistResults,
    required this.ungroupedEpisodeIds,
    required this.resolverType,
  });

  final List<PlaylistPreviewResult> playlistResults;
  final List<int> ungroupedEpisodeIds;
  final String resolverType;
}
