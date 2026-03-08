import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('PlaylistStructure', () {
    test('has split and grouped values', () {
      expect(PlaylistStructure.values, hasLength(2));
      expect(PlaylistStructure.split.name, 'split');
      expect(PlaylistStructure.grouped.name, 'grouped');
    });
  });

  group('YearBinding', () {
    test('has none, pinToYear, and splitByYear values', () {
      expect(YearBinding.values, hasLength(3));
      expect(YearBinding.none.name, 'none');
      expect(YearBinding.pinToYear.name, 'pinToYear');
      expect(YearBinding.splitByYear.name, 'splitByYear');
    });
  });

  group('SmartPlaylistGroup', () {
    test('holds group data with episode IDs', () {
      final group = SmartPlaylistGroup(
        id: 'lincoln',
        displayName: 'Lincoln',
        sortKey: 1,
        episodeIds: [1, 2, 3],
      );

      expect(group.id, 'lincoln');
      expect(group.displayName, 'Lincoln');
      expect(group.sortKey, 1);
      expect(group.episodeIds, [1, 2, 3]);
      expect(group.thumbnailUrl, isNull);
      expect(group.yearOverride, isNull);
    });

    test('episodeCount returns correct count', () {
      final group = SmartPlaylistGroup(
        id: 'g1',
        displayName: 'G1',
        sortKey: 1,
        episodeIds: [1, 2, 3, 4],
      );
      expect(group.episodeCount, 4);
    });

    test('supports yearOverride', () {
      final group = SmartPlaylistGroup(
        id: 'g1',
        displayName: 'G1',
        sortKey: 1,
        episodeIds: [1],
        yearOverride: YearBinding.splitByYear,
      );
      expect(group.yearOverride, YearBinding.splitByYear);
    });
  });

  group('SmartPlaylist', () {
    test('SmartPlaylist holds episode list and metadata', () {
      final playlist = SmartPlaylist(
        id: 'smart_playlist_1',
        displayName: 'Smart Playlist 1',
        sortKey: 1,
        episodeIds: [1, 2, 3],
      );

      expect(playlist.id, 'smart_playlist_1');
      expect(playlist.displayName, 'Smart Playlist 1');
      expect(playlist.sortKey, 1);
      expect(playlist.episodeIds, [1, 2, 3]);
    });

    test('SmartPlaylist.episodeCount returns correct count', () {
      final playlist = SmartPlaylist(
        id: 'smart_playlist_2',
        displayName: 'Smart Playlist 2',
        sortKey: 2,
        episodeIds: [4, 5, 6, 7, 8],
      );

      expect(playlist.episodeCount, 5);
    });

    test('defaults to split playlistStructure with no year headers', () {
      final playlist = SmartPlaylist(
        id: 'p1',
        displayName: 'P1',
        sortKey: 1,
        episodeIds: [1, 2],
      );

      expect(playlist.playlistStructure, PlaylistStructure.split);
      expect(playlist.yearBinding, YearBinding.none);
      expect(playlist.showYearHeaders, isFalse);
      expect(playlist.groups, isNull);
    });

    test('supports grouped playlistStructure', () {
      final groups = [
        SmartPlaylistGroup(
          id: 'g1',
          displayName: 'G1',
          sortKey: 1,
          episodeIds: [1, 2],
        ),
      ];
      final playlist = SmartPlaylist(
        id: 'p1',
        displayName: 'P1',
        sortKey: 1,
        episodeIds: [],
        playlistStructure: PlaylistStructure.grouped,
        yearBinding: YearBinding.pinToYear,
        groups: groups,
      );

      expect(playlist.playlistStructure, PlaylistStructure.grouped);
      expect(playlist.yearBinding, YearBinding.pinToYear);
      expect(playlist.groups, hasLength(1));
      expect(playlist.groups!.first.id, 'g1');
    });

    test('copyWith preserves new fields', () {
      final playlist = SmartPlaylist(
        id: 'p1',
        displayName: 'P1',
        sortKey: 1,
        episodeIds: [],
        playlistStructure: PlaylistStructure.grouped,
        yearBinding: YearBinding.splitByYear,
        showYearHeaders: true,
      );

      final copied = playlist.copyWith(displayName: 'P2');
      expect(copied.playlistStructure, PlaylistStructure.grouped);
      expect(copied.yearBinding, YearBinding.splitByYear);
      expect(copied.showYearHeaders, isTrue);
      expect(copied.displayName, 'P2');
    });
  });

  group('SmartPlaylistGrouping', () {
    test('SmartPlaylistGrouping holds playlists and '
        'ungrouped episodes', () {
      final grouping = SmartPlaylistGrouping(
        playlists: [
          SmartPlaylist(
            id: 's1',
            displayName: 'S1',
            sortKey: 1,
            episodeIds: [1, 2],
          ),
        ],
        ungroupedEpisodeIds: [10, 11],
        resolverType: 'rss',
      );

      expect(grouping.playlists.length, 1);
      expect(grouping.ungroupedEpisodeIds, [10, 11]);
      expect(grouping.resolverType, 'rss');
    });

    test('SmartPlaylistGrouping.hasUngrouped returns true '
        'when ungrouped exist', () {
      final withUngrouped = SmartPlaylistGrouping(
        playlists: [],
        ungroupedEpisodeIds: [1],
        resolverType: 'rss',
      );
      final withoutUngrouped = SmartPlaylistGrouping(
        playlists: [],
        ungroupedEpisodeIds: [],
        resolverType: 'rss',
      );

      expect(withUngrouped.hasUngrouped, isTrue);
      expect(withoutUngrouped.hasUngrouped, isFalse);
    });
  });
}
