import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('PlaylistPreviewResult', () {
    test('stores playlist and empty claimedByOthers', () {
      final playlist = SmartPlaylist(
        id: 'p1',
        displayName: 'Playlist 1',
        sortKey: 0,
        episodeIds: [1, 2, 3],
      );

      final result = PlaylistPreviewResult(
        definitionId: 'p1',
        playlist: playlist,
        claimedByOthers: {},
      );

      expect(result.definitionId, 'p1');
      expect(result.playlist.episodeIds, [1, 2, 3]);
      expect(result.claimedByOthers, isEmpty);
    });

    test('stores claimedByOthers mapping episode ID to claimer ID', () {
      final playlist = SmartPlaylist(
        id: 'p2',
        displayName: 'Playlist 2',
        sortKey: 0,
        episodeIds: [3, 4],
      );

      final result = PlaylistPreviewResult(
        definitionId: 'p2',
        playlist: playlist,
        claimedByOthers: {1: 'p1', 2: 'p1'},
      );

      expect(result.claimedByOthers, {1: 'p1', 2: 'p1'});
    });
  });

  group('PreviewGrouping', () {
    test('wraps playlist results with ungrouped and resolverType', () {
      final grouping = PreviewGrouping(
        playlistResults: [
          PlaylistPreviewResult(
            definitionId: 'p1',
            playlist: SmartPlaylist(
              id: 'p1',
              displayName: 'P1',
              sortKey: 0,
              episodeIds: [1, 2],
            ),
            claimedByOthers: {},
          ),
        ],
        ungroupedEpisodeIds: [5, 6],
        resolverType: 'rss',
      );

      expect(grouping.playlistResults, hasLength(1));
      expect(grouping.ungroupedEpisodeIds, [5, 6]);
      expect(grouping.resolverType, 'rss');
    });
  });
}
