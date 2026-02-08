import 'dart:convert';

import '../models/smart_playlist_pattern_config.dart';

/// Parses smart playlist pattern JSON into typed models.
///
/// Pure function with no Flutter dependency. The JSON source
/// can be a bundled asset or a server response.
final class SmartPlaylistPatternLoader {
  SmartPlaylistPatternLoader._();

  static const _supportedVersion = 1;

  /// Parses a JSON string into a list of pattern configs.
  ///
  /// Throws [FormatException] if the version is missing or
  /// unsupported.
  static List<SmartPlaylistPatternConfig> parse(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final version = data['version'] as int?;
    if (version == null) {
      throw const FormatException(
        'Missing "version" field in smart playlist patterns JSON',
      );
    }
    if (version != _supportedVersion) {
      throw FormatException(
        'Unsupported smart playlist patterns version: $version '
        '(supported: $_supportedVersion)',
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
