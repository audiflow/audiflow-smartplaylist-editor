import 'episode_data.dart';

/// Extracts episode-in-season number from episode data on-demand.
///
/// For episodes with positive seasonNumber, extracts from title using regex.
/// For episodes with null/zero seasonNumber (e.g., bangai-hen), uses RSS
/// episodeNumber.
final class EpisodeNumberExtractor {
  const EpisodeNumberExtractor({
    required this.pattern,
    this.captureGroup = 1,
    this.fallbackToRss = true,
  });

  factory EpisodeNumberExtractor.fromJson(Map<String, dynamic> json) {
    return EpisodeNumberExtractor(
      pattern: json['pattern'] as String,
      captureGroup: (json['captureGroup'] as int?) ?? 1,
      fallbackToRss: (json['fallbackToRss'] as bool?) ?? true,
    );
  }

  final String pattern;
  final int captureGroup;
  final bool fallbackToRss;

  Map<String, dynamic> toJson() {
    return {
      'pattern': pattern,
      'captureGroup': captureGroup,
      'fallbackToRss': fallbackToRss,
    };
  }

  int? extract(EpisodeData episode) {
    // For null/zero seasonNumber (e.g., bangai-hen), use RSS
    // episodeNumber directly
    final seasonNum = episode.seasonNumber;
    if (seasonNum == null || seasonNum < 1) {
      return episode.episodeNumber;
    }

    // Try regex extraction from title
    final regex = RegExp(pattern);
    final match = regex.firstMatch(episode.title);

    if (match != null && captureGroup <= match.groupCount) {
      final captured = match.group(captureGroup);
      if (captured != null) {
        final parsed = int.tryParse(captured);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    // Fall back to RSS episodeNumber if enabled
    if (fallbackToRss) {
      return episode.episodeNumber;
    }

    return null;
  }
}
