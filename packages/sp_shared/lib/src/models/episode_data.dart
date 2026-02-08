/// Interface for episode data used by SmartPlaylist resolvers and extractors.
///
/// Abstracts away the storage layer (Drift, RSS parsed data, etc.)
/// so resolvers work with any episode source.
abstract interface class EpisodeData {
  /// Unique episode identifier.
  int get id;

  /// Episode title.
  String get title;

  /// Episode description (optional).
  String? get description;

  /// Season number from RSS metadata (optional).
  int? get seasonNumber;

  /// Episode number from RSS metadata (optional).
  int? get episodeNumber;

  /// Publication date (optional).
  DateTime? get publishedAt;

  /// Episode artwork URL (optional).
  String? get imageUrl;
}

/// Simple implementation of [EpisodeData] for testing and web service use.
final class SimpleEpisodeData implements EpisodeData {
  const SimpleEpisodeData({
    required this.id,
    required this.title,
    this.description,
    this.seasonNumber,
    this.episodeNumber,
    this.publishedAt,
    this.imageUrl,
  });

  @override
  final int id;

  @override
  final String title;

  @override
  final String? description;

  @override
  final int? seasonNumber;

  @override
  final int? episodeNumber;

  @override
  final DateTime? publishedAt;

  @override
  final String? imageUrl;
}
