import 'episode_data.dart';

/// Configuration for extracting smart playlist display names from
/// episode data.
///
/// Supports JSON-based configuration that can be downloaded from web.
///
/// Example JSON configs:
/// ```json
/// // Extract from title using regex
/// {
///   "source": "title",
///   "pattern": "\\[(.+?)\\s+\\d+\\]",
///   "group": 1
/// }
///
/// // Use seasonNumber with template
/// {
///   "source": "seasonNumber",
///   "template": "Season {value}"
/// }
///
/// // With fallback
/// {
///   "source": "title",
///   "pattern": "\\[(.+?)\\]",
///   "group": 1,
///   "fallback": {
///     "source": "seasonNumber",
///     "template": "Season {value}"
///   }
/// }
/// ```
final class SmartPlaylistTitleExtractor {
  const SmartPlaylistTitleExtractor({
    required this.source,
    this.pattern,
    this.group = 0,
    this.template,
    this.fallback,
    this.fallbackValue,
  });

  /// Creates an extractor from JSON configuration.
  factory SmartPlaylistTitleExtractor.fromJson(Map<String, dynamic> json) {
    return SmartPlaylistTitleExtractor(
      source: json['source'] as String,
      pattern: json['pattern'] as String?,
      group: (json['group'] as int?) ?? 0,
      template: json['template'] as String?,
      fallback: json['fallback'] != null
          ? SmartPlaylistTitleExtractor.fromJson(
              json['fallback'] as Map<String, dynamic>,
            )
          : null,
      fallbackValue: json['fallbackValue'] as String?,
    );
  }

  /// Episode field to extract from.
  ///
  /// Supported values: "title", "description", "seasonNumber",
  /// "episodeNumber"
  final String source;

  /// Regex pattern to extract value (optional).
  ///
  /// When provided, the pattern is matched against the source
  /// field.
  final String? pattern;

  /// Capture group to use from regex match (default: 0 = full
  /// match).
  final int group;

  /// Template for formatting the extracted value.
  ///
  /// Use `{value}` as placeholder for the extracted/source value.
  /// Example: "Season {value}" with seasonNumber=3 produces
  /// "Season 3"
  final String? template;

  /// Fallback extractor to use when this one fails.
  final SmartPlaylistTitleExtractor? fallback;

  /// Fallback string value for null/zero seasonNumber episodes.
  final String? fallbackValue;

  /// Converts to JSON representation.
  Map<String, dynamic> toJson() {
    return {
      'source': source,
      if (pattern != null) 'pattern': pattern,
      if (group != 0) 'group': group,
      if (template != null) 'template': template,
      if (fallback != null) 'fallback': fallback!.toJson(),
      if (fallbackValue != null) 'fallbackValue': fallbackValue,
    };
  }

  /// Extracts the smart playlist title from an episode.
  ///
  /// Returns null if extraction fails and no fallback is available.
  String? extract(EpisodeData episode) {
    // For null/zero seasonNumber, use fallbackValue if available
    final seasonNum = episode.seasonNumber;
    if (fallbackValue != null && (seasonNum == null || seasonNum < 1)) {
      return fallbackValue;
    }

    final sourceValue = _getSourceValue(episode);

    if (sourceValue == null) {
      return fallback?.extract(episode);
    }

    String? result;

    if (pattern != null) {
      result = _extractWithPattern(sourceValue);
    } else {
      result = sourceValue;
    }

    if (result == null) {
      return fallback?.extract(episode);
    }

    if (template != null) {
      result = template!.replaceAll('{value}', result);
    }

    return result;
  }

  String? _getSourceValue(EpisodeData episode) {
    return switch (source) {
      'title' => episode.title,
      'description' => episode.description,
      'seasonNumber' => episode.seasonNumber?.toString(),
      'episodeNumber' => episode.episodeNumber?.toString(),
      _ => null,
    };
  }

  String? _extractWithPattern(String value) {
    final regex = RegExp(pattern!);
    final match = regex.firstMatch(value);

    if (match == null) {
      return null;
    }

    if (group == 0) {
      return match.group(0);
    }

    if (match.groupCount < group) {
      return null;
    }

    return match.group(group);
  }
}
