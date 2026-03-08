/// Constants for SmartPlaylist config schema values.
///
/// Provides enum value lists and version info used by both
/// validation and runtime code. The authoritative schemas are
/// the vendored `assets/*.schema.json` files.
final class SmartPlaylistSchemaConstants {
  SmartPlaylistSchemaConstants._();

  /// Schema URI for pattern-index.schema.json.
  static const String patternIndexSchemaId =
      'https://audiflow.app/schema/v$currentSchemaVersion/pattern-index.json';

  /// Schema URI for pattern-meta.schema.json.
  static const String patternMetaSchemaId =
      'https://audiflow.app/schema/v$currentSchemaVersion/pattern-meta.json';

  /// Schema URI for playlist-definition.schema.json.
  static const String playlistDefinitionSchemaId =
      'https://audiflow.app/schema/v$currentSchemaVersion/playlist-definition.json';

  /// Current data format version.
  static const int currentDataVersion = 1;

  /// Current schema definition version.
  static const int currentSchemaVersion = 2;

  /// Valid resolver types for playlist definitions.
  static const List<String> validResolverTypes = [
    'rss',
    'category',
    'year',
    'titleAppearanceOrder',
  ];

  /// Valid playlist structure types.
  static const List<String> validPlaylistStructures = ['split', 'grouped'];

  /// Valid year binding modes.
  static const List<String> validYearBindings = [
    'none',
    'pinToYear',
    'splitByYear',
  ];

  /// Valid group sort fields.
  static const List<String> validSortFields = [
    'playlistNumber',
    'newestEpisodeDate',
    'alphabetical',
  ];

  /// Valid episode sort fields.
  static const List<String> validEpisodeSortFields = [
    'publishedAt',
    'episodeNumber',
    'title',
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
}
