import 'episode_data.dart';

/// Result of extracting smart playlist and episode numbers from
/// episode data.
final class SmartPlaylistEpisodeResult {
  const SmartPlaylistEpisodeResult({this.seasonNumber, this.episodeNumber});

  final int? seasonNumber;
  final int? episodeNumber;

  /// Returns true if at least one value was extracted.
  bool get hasValues => seasonNumber != null || episodeNumber != null;

  @override
  String toString() =>
      'SmartPlaylistEpisodeResult('
      'season: $seasonNumber, episode: $episodeNumber)';
}

/// Extracts both smart playlist and episode numbers from episode
/// title prefix.
///
/// Designed for podcasts like COTEN RADIO where RSS metadata is
/// unreliable but episode titles encode the data reliably:
/// - `[62-15] ...` encodes Playlist 62, Episode 15
/// - `[bangai-hen #135] ...` encodes a special episode
///   (playlist 0, episode 135)
final class SmartPlaylistEpisodeExtractor {
  const SmartPlaylistEpisodeExtractor({
    required this.source,
    required this.pattern,
    this.seasonGroup = 1,
    this.episodeGroup = 2,
    this.fallbackSeasonNumber,
    this.fallbackEpisodePattern,
    this.fallbackEpisodeCaptureGroup = 1,
  });

  factory SmartPlaylistEpisodeExtractor.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistEpisodeExtractor(
      source: json['source'] as String,
      pattern: json['pattern'] as String,
      seasonGroup: (json['seasonGroup'] as int?) ?? 1,
      episodeGroup: (json['episodeGroup'] as int?) ?? 2,
      fallbackSeasonNumber: json['fallbackSeasonNumber'] as int?,
      fallbackEpisodePattern: json['fallbackEpisodePattern'] as String?,
      fallbackEpisodeCaptureGroup:
          (json['fallbackEpisodeCaptureGroup'] as int?) ?? 1,
    );
  }

  /// Episode field to extract from ("title" or "description").
  final String source;

  /// Primary regex pattern to extract both playlist and episode.
  ///
  /// Example: `[(\d+)-(\d+)]` for `[62-15]`
  final String pattern;

  /// Capture group index for season number (default: 1).
  final int seasonGroup;

  /// Capture group index for episode number (default: 2).
  final int episodeGroup;

  /// Season number to use when primary pattern fails but fallback
  /// matches.
  ///
  /// Example: `0` for bangai-hen episodes.
  final int? fallbackSeasonNumber;

  /// Fallback regex pattern for special episodes.
  ///
  /// Example: `[bangai-hen#(\d+)]`
  final String? fallbackEpisodePattern;

  /// Capture group index for episode number in fallback pattern
  /// (default: 1).
  final int fallbackEpisodeCaptureGroup;

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'pattern': pattern,
      'seasonGroup': seasonGroup,
      'episodeGroup': episodeGroup,
      if (fallbackSeasonNumber != null)
        'fallbackSeasonNumber': fallbackSeasonNumber,
      if (fallbackEpisodePattern != null)
        'fallbackEpisodePattern': fallbackEpisodePattern,
      if (fallbackEpisodeCaptureGroup != 1)
        'fallbackEpisodeCaptureGroup': fallbackEpisodeCaptureGroup,
    };
  }

  /// Extracts smart playlist and episode numbers from episode data.
  ///
  /// Returns a [SmartPlaylistEpisodeResult] with extracted values
  /// (may be null).
  SmartPlaylistEpisodeResult extract(EpisodeData episode) {
    final sourceValue = _getSourceValue(episode);
    if (sourceValue == null) {
      return const SmartPlaylistEpisodeResult();
    }

    // Try primary pattern first
    final primaryResult = _extractFromPrimary(sourceValue);
    if (primaryResult.hasValues) {
      return primaryResult;
    }

    // Try fallback pattern if configured
    if (fallbackEpisodePattern != null) {
      return _extractFromFallback(sourceValue);
    }

    return const SmartPlaylistEpisodeResult();
  }

  String? _getSourceValue(EpisodeData episode) {
    return switch (source) {
      'title' => episode.title,
      'description' => episode.description,
      _ => null,
    };
  }

  SmartPlaylistEpisodeResult _extractFromPrimary(String value) {
    final regex = RegExp(pattern);
    final match = regex.firstMatch(value);

    if (match == null) {
      return const SmartPlaylistEpisodeResult();
    }

    int? season;
    int? episode;

    if (seasonGroup <= match.groupCount) {
      final captured = match.group(seasonGroup);
      if (captured != null) {
        season = int.tryParse(captured);
      }
    }

    if (episodeGroup <= match.groupCount) {
      final captured = match.group(episodeGroup);
      if (captured != null) {
        episode = int.tryParse(captured);
      }
    }

    return SmartPlaylistEpisodeResult(
      seasonNumber: season,
      episodeNumber: episode,
    );
  }

  SmartPlaylistEpisodeResult _extractFromFallback(String value) {
    final regex = RegExp(fallbackEpisodePattern!);
    final match = regex.firstMatch(value);

    if (match == null) {
      return const SmartPlaylistEpisodeResult();
    }

    int? episode;
    if (fallbackEpisodeCaptureGroup <= match.groupCount) {
      final captured = match.group(fallbackEpisodeCaptureGroup);
      if (captured != null) {
        episode = int.tryParse(captured);
      }
    }

    return SmartPlaylistEpisodeResult(
      seasonNumber: fallbackSeasonNumber,
      episodeNumber: episode,
    );
  }
}
