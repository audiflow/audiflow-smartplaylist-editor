/// Summary of a pattern from root meta.json.
///
/// Used in browse lists and for cache invalidation.
final class PatternSummary {
  const PatternSummary({
    required this.id,
    required this.dataVersion,
    required this.displayName,
    required this.feedUrlHint,
    required this.playlistCount,
  });

  factory PatternSummary.fromJson(Map<String, dynamic> json) {
    return PatternSummary(
      id: json['id'] as String,
      dataVersion: (json['dataVersion'] as int?) ?? 1,
      displayName: json['displayName'] as String,
      feedUrlHint: json['feedUrlHint'] as String,
      playlistCount: json['playlistCount'] as int,
    );
  }

  final String id;
  final int dataVersion;
  final String displayName;
  final String feedUrlHint;
  final int playlistCount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dataVersion': dataVersion,
      'displayName': displayName,
      'feedUrlHint': feedUrlHint,
      'playlistCount': playlistCount,
    };
  }
}
