import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SimpleEpisodeData', () {
    test('stores all fields', () {
      final episode = SimpleEpisodeData(
        id: 42,
        title: 'Episode 1',
        description: 'First episode',
        seasonNumber: 1,
        episodeNumber: 1,
        publishedAt: DateTime(2025, 1, 15),
        imageUrl: 'https://example.com/img.jpg',
      );

      expect(episode.id, 42);
      expect(episode.title, 'Episode 1');
      expect(episode.description, 'First episode');
      expect(episode.seasonNumber, 1);
      expect(episode.episodeNumber, 1);
      expect(episode.publishedAt, DateTime(2025, 1, 15));
      expect(episode.imageUrl, 'https://example.com/img.jpg');
    });

    test('nullable fields default to null', () {
      final episode = SimpleEpisodeData(id: 1, title: 'Test');

      expect(episode.description, isNull);
      expect(episode.seasonNumber, isNull);
      expect(episode.episodeNumber, isNull);
      expect(episode.publishedAt, isNull);
      expect(episode.imageUrl, isNull);
    });

    test('implements EpisodeData interface', () {
      final episode = SimpleEpisodeData(id: 1, title: 'Test');

      expect(episode, isA<EpisodeData>());
    });
  });
}
