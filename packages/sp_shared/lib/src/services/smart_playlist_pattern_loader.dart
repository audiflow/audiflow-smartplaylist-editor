import 'dart:convert';

import '../models/smart_playlist_pattern_config.dart';

/// Parses smart playlist pattern JSON into typed models.
///
/// Pure function with no Flutter dependency. The JSON source
/// can be a bundled asset or a server response.
final class SmartPlaylistPatternLoader {
  SmartPlaylistPatternLoader._();

  /// Parses a JSON string into a list of pattern configs.
  ///
  /// Throws [FormatException] if the version field is missing.
  static List<SmartPlaylistPatternConfig> parse(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final dataVersion = data['dataVersion'] as int?;
    if (dataVersion == null) {
      throw const FormatException(
        'Missing "dataVersion" field in smart playlist patterns JSON',
      );
    }
    final patterns = data['patterns'] as List<dynamic>;
    return patterns
        .map(
          (p) => SmartPlaylistPatternConfig.fromJson(p as Map<String, dynamic>),
        )
        .toList();
  }
}
