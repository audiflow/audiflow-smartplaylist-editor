import 'dart:convert';

import 'pattern_summary.dart';

/// Root meta.json from the split config repository.
///
/// Contains data version and pattern summaries for discovery.
/// The version field tracks the data format version managed by the data repo,
/// not a schema version enforced by this editor.
final class RootMeta {
  const RootMeta({required this.version, required this.patterns});

  factory RootMeta.fromJson(Map<String, dynamic> json) {
    return RootMeta(
      version: json['version'] as int,
      patterns: (json['patterns'] as List<dynamic>)
          .map((p) => PatternSummary.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Parses a JSON string into a RootMeta.
  ///
  /// Throws [FormatException] if version field is missing.
  static RootMeta parseJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final version = data['version'] as int?;
    if (version == null) {
      throw const FormatException(
        'Missing required "version" field in root meta.json',
      );
    }
    return RootMeta.fromJson(data);
  }

  final int version;
  final List<PatternSummary> patterns;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'patterns': patterns.map((p) => p.toJson()).toList(),
    };
  }
}
