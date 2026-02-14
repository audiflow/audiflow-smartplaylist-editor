import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigAssembler', () {
    test('assembles config from pattern meta and playlists', () {
      final meta = PatternMeta(
        version: 1,
        id: 'coten_radio',
        feedUrls: ['https://anchor.fm/s/8c2088c/podcast/rss'],
        yearGroupedEpisodes: true,
        playlists: ['regular', 'short'],
      );
      final playlists = [
        SmartPlaylistDefinition(
          id: 'regular',
          displayName: 'Regular',
          resolverType: 'rss',
        ),
        SmartPlaylistDefinition(
          id: 'short',
          displayName: 'Short',
          resolverType: 'rss',
        ),
      ];

      final config = ConfigAssembler.assemble(meta, playlists);

      expect(config.id, 'coten_radio');
      expect(config.feedUrls, hasLength(1));
      expect(config.yearGroupedEpisodes, isTrue);
      expect(config.playlists, hasLength(2));
      expect(config.playlists[0].id, 'regular');
      expect(config.playlists[1].id, 'short');
    });

    test('preserves podcastGuid when present', () {
      final meta = PatternMeta(
        version: 1,
        id: 'test',
        podcastGuid: 'guid-abc',
        feedUrls: [],
        playlists: ['main'],
      );
      final playlists = [
        SmartPlaylistDefinition(
          id: 'main',
          displayName: 'Main',
          resolverType: 'rss',
        ),
      ];

      final config = ConfigAssembler.assemble(meta, playlists);
      expect(config.podcastGuid, 'guid-abc');
    });

    test('orders playlists by meta playlist list order', () {
      final meta = PatternMeta(
        version: 1,
        id: 'test',
        feedUrls: [],
        playlists: ['b', 'a'],
      );
      final playlists = [
        SmartPlaylistDefinition(id: 'a', displayName: 'A', resolverType: 'rss'),
        SmartPlaylistDefinition(id: 'b', displayName: 'B', resolverType: 'rss'),
      ];

      final config = ConfigAssembler.assemble(meta, playlists);
      expect(config.playlists[0].id, 'b');
      expect(config.playlists[1].id, 'a');
    });
  });
}
