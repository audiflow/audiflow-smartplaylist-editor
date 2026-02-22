/// Constants for SmartPlaylist config schema values.
///
/// Provides enum value lists and version info used by both
/// validation and runtime code. The authoritative schema is
/// the vendored `assets/schema.json`.
final class SmartPlaylistSchemaConstants {
  SmartPlaylistSchemaConstants._();

  /// Current schema version.
  static const int currentVersion = 1;

  /// Valid resolver types for playlist definitions.
  static const List<String> validResolverTypes = [
    'rss',
    'category',
    'year',
    'titleAppearanceOrder',
  ];

  /// Valid content types for playlist definitions.
  static const List<String> validContentTypes = ['episodes', 'groups'];

  /// Valid year header modes.
  static const List<String> validYearHeaderModes = [
    'none',
    'firstEpisode',
    'perEpisode',
  ];

  /// Valid sort fields.
  static const List<String> validSortFields = [
    'playlistNumber',
    'newestEpisodeDate',
    'progress',
    'alphabetical',
  ];

  /// Valid sort orders.
  static const List<String> validSortOrders = ['ascending', 'descending'];

  /// Valid title extractor sources.
  static const List<String> validTitleExtractorSources = [
    'title',
    'description',
    'seasonNumber',
    'episodeNumber',
  ];

  /// Valid episode extractor sources.
  static const List<String> validEpisodeExtractorSources = [
    'title',
    'description',
  ];

  /// Valid sort condition types.
  static const List<String> validSortConditionTypes = [
    'sortKeyGreaterThan',
    'greaterThan',
  ];
}
