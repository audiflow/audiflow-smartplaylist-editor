/// Summary of a pattern from root meta.json.
///
/// Used in browse lists and for cache invalidation.
final class PatternSummary {
  const PatternSummary({
    required this.id,
    required this.version,
    required this.displayName,
    required this.feedUrlHint,
    required this.playlistCount,
  });

  factory PatternSummary.fromJson(Map<String, dynamic> json) {
    return PatternSummary(
      id: json['id'] as String,
      version: json['version'] as int,
      displayName: json['displayName'] as String,
      feedUrlHint: json['feedUrlHint'] as String,
      playlistCount: json['playlistCount'] as int,
    );
  }

  final String id;
  final int version;
  final String displayName;
  final String feedUrlHint;
  final int playlistCount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version': version,
      'displayName': displayName,
      'feedUrlHint': feedUrlHint,
      'playlistCount': playlistCount,
    };
  }
}
