import 'dart:convert';

/// JSON Schema generator and validator for SmartPlaylist configs.
///
/// Provides both a full JSON Schema (draft-07) describing the config
/// format and a lightweight structural validator for runtime checks.
final class SmartPlaylistSchema {
  SmartPlaylistSchema._();

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
    'firstEpisode',
    'lastEpisode',
    'publishYear',
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

  /// Generates a JSON Schema string describing the config format.
  static String generate() {
    final schema = <String, dynamic>{
      r'$schema': 'http://json-schema.org/draft-07/schema#',
      'title': 'SmartPlaylist Pattern Config',
      'description':
          'Top-level configuration file that maps podcasts to '
          'smart playlist definitions. Contains a version number and an '
          'array of pattern configs.',
      'type': 'object',
      'required': ['version', 'patterns'],
      'additionalProperties': false,
      'properties': {
        'version': {
          'type': 'integer',
          'const': currentVersion,
          'description': 'Schema version number. Must be $currentVersion.',
        },
        'patterns': {
          'type': 'array',
          'description':
              'Array of pattern configs, each matching a podcast '
              'and defining its smart playlists.',
          'items': {r'$ref': '#/\$defs/SmartPlaylistPatternConfig'},
        },
      },
      r'$defs': {
        'SmartPlaylistPatternConfig': _patternConfigSchema(),
        'SmartPlaylistDefinition': _playlistDefinitionSchema(),
        'SmartPlaylistGroupDef': _groupDefSchema(),
        'SmartPlaylistSortSpec': _sortSpecSchema(),
        'SmartPlaylistSortRule': _sortRuleSchema(),
        'SmartPlaylistSortCondition': _sortConditionSchema(),
        'SmartPlaylistTitleExtractor': _titleExtractorSchema(),
        'EpisodeNumberExtractor': _episodeNumberExtractorSchema(),
        'SmartPlaylistEpisodeExtractor': _episodeExtractorSchema(),
      },
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(schema);
  }

  /// Validates a JSON string against the schema.
  ///
  /// Performs lightweight structural validation: checks required
  /// fields, types, enum values, and version. Does not reject
  /// unknown/additional properties.
  ///
  /// Returns a list of validation error messages (empty = valid).
  static List<String> validate(String jsonString) {
    final errors = <String>[];

    // Parse JSON
    final Object? parsed;
    try {
      parsed = jsonDecode(jsonString);
    } on FormatException catch (e) {
      return ['Invalid JSON: ${e.message}'];
    }

    if (parsed is! Map<String, dynamic>) {
      return ['Root must be a JSON object'];
    }

    _validateRoot(parsed, errors);
    return errors;
  }

  // -- Schema definition helpers --

  static Map<String, dynamic> _patternConfigSchema() {
    return {
      'type': 'object',
      'description':
          'Matches a podcast by GUID or feed URLs and '
          'provides playlist definitions.',
      'required': ['id', 'playlists'],
      'additionalProperties': false,
      'properties': {
        'id': {
          'type': 'string',
          'description': 'Unique identifier for this pattern config.',
        },
        'podcastGuid': {
          'type': 'string',
          'description':
              'Podcast GUID for exact matching. '
              'Checked before feedUrls.',
        },
        'feedUrls': {
          'type': 'array',
          'description': 'Exact feed URLs for matching.',
          'items': {'type': 'string'},
        },
        'yearGroupedEpisodes': {
          'type': 'boolean',
          'default': false,
          'description': 'Whether the all-episodes view groups by year.',
        },
        'playlists': {
          'type': 'array',
          'description': 'Playlist definitions for this podcast.',
          'items': {r'$ref': '#/\$defs/SmartPlaylistDefinition'},
          'minItems': 1,
        },
      },
    };
  }

  static Map<String, dynamic> _playlistDefinitionSchema() {
    return {
      'type': 'object',
      'description':
          'Defines a single smart playlist with resolver type, '
          'filters, groups, and display options.',
      'required': ['id', 'displayName', 'resolverType'],
      'additionalProperties': false,
      'properties': {
        'id': {
          'type': 'string',
          'description': 'Unique identifier for this playlist definition.',
        },
        'displayName': {
          'type': 'string',
          'description': 'Human-readable name for display.',
        },
        'resolverType': {
          'type': 'string',
          'enum': validResolverTypes,
          'description': 'Type of resolver to use for episode grouping.',
        },
        'priority': {
          'type': 'integer',
          'default': 0,
          'description': 'Sort priority among sibling playlists.',
        },
        'contentType': {
          'type': 'string',
          'enum': validContentTypes,
          'description':
              'Content type: "episodes" for flat lists, '
              '"groups" for grouped display.',
        },
        'yearHeaderMode': {
          'type': 'string',
          'enum': validYearHeaderModes,
          'description': 'How to determine year for year headers.',
        },
        'episodeYearHeaders': {
          'type': 'boolean',
          'default': false,
          'description': 'Whether to show year headers within episode lists.',
        },
        'showDateRange': {
          'type': 'boolean',
          'default': false,
          'description': 'Whether group cards display a date range.',
        },
        'titleFilter': {
          'type': 'string',
          'description': 'Regex pattern to filter episode titles (include).',
        },
        'excludeFilter': {
          'type': 'string',
          'description': 'Regex pattern to exclude episodes by title.',
        },
        'requireFilter': {
          'type': 'string',
          'description': 'Regex pattern that episodes must match.',
        },
        'nullSeasonGroupKey': {
          'type': 'integer',
          'description': 'Group key assigned to episodes with null season.',
        },
        'groups': {
          'type': 'array',
          'description':
              'Static group definitions for category-based '
              'grouping.',
          'items': {r'$ref': '#/\$defs/SmartPlaylistGroupDef'},
        },
        'customSort': {
          r'$ref': '#/\$defs/SmartPlaylistSortSpec',
          'description': 'Custom sort specification for this playlist.',
        },
        'titleExtractor': {
          r'$ref': '#/\$defs/SmartPlaylistTitleExtractor',
          'description':
              'Configuration for extracting playlist '
              'display names from episode data.',
        },
        'episodeNumberExtractor': {
          r'$ref': '#/\$defs/EpisodeNumberExtractor',
          'description':
              'Configuration for extracting episode numbers '
              'from episode titles.',
        },
        'smartPlaylistEpisodeExtractor': {
          r'$ref': '#/\$defs/SmartPlaylistEpisodeExtractor',
          'description':
              'Configuration for extracting both season and '
              'episode numbers from title prefixes.',
        },
      },
    };
  }

  static Map<String, dynamic> _groupDefSchema() {
    return {
      'type': 'object',
      'description':
          'Static group definition. Groups with a pattern match '
          'episodes by title regex; without a pattern, acts as catch-all.',
      'required': ['id', 'displayName'],
      'additionalProperties': false,
      'properties': {
        'id': {
          'type': 'string',
          'description': 'Unique identifier for this group.',
        },
        'displayName': {
          'type': 'string',
          'description': 'Human-readable name for display.',
        },
        'pattern': {
          'type': 'string',
          'description':
              'Regex pattern to match episode titles. '
              'Null means catch-all fallback.',
        },
        'episodeYearHeaders': {
          'type': 'boolean',
          'description':
              'Per-group override for episode year headers. '
              'Inherits from playlist when null.',
        },
        'showDateRange': {
          'type': 'boolean',
          'description':
              'Per-group override for date range display. '
              'Inherits from playlist when null.',
        },
      },
    };
  }

  static Map<String, dynamic> _sortSpecSchema() {
    return {
      'type': 'object',
      'description':
          'Sort specification, either simple (single-field) '
          'or composite (multi-rule).',
      'required': ['type'],
      'oneOf': [
        {
          'type': 'object',
          'description': 'Simple single-field sort.',
          'required': ['type', 'field', 'order'],
          'additionalProperties': false,
          'properties': {
            'type': {'type': 'string', 'const': 'simple'},
            'field': {
              'type': 'string',
              'enum': validSortFields,
              'description': 'Field to sort by.',
            },
            'order': {
              'type': 'string',
              'enum': validSortOrders,
              'description': 'Sort direction.',
            },
          },
        },
        {
          'type': 'object',
          'description': 'Composite sort with multiple rules.',
          'required': ['type', 'rules'],
          'additionalProperties': false,
          'properties': {
            'type': {'type': 'string', 'const': 'composite'},
            'rules': {
              'type': 'array',
              'description': 'Ordered list of sort rules.',
              'items': {r'$ref': '#/\$defs/SmartPlaylistSortRule'},
              'minItems': 1,
            },
          },
        },
      ],
    };
  }

  static Map<String, dynamic> _sortRuleSchema() {
    return {
      'type': 'object',
      'description': 'A single rule in a composite sort.',
      'required': ['field', 'order'],
      'additionalProperties': false,
      'properties': {
        'field': {
          'type': 'string',
          'enum': validSortFields,
          'description': 'Field to sort by.',
        },
        'order': {
          'type': 'string',
          'enum': validSortOrders,
          'description': 'Sort direction.',
        },
        'condition': {
          r'$ref': '#/\$defs/SmartPlaylistSortCondition',
          'description': 'Optional condition for when this rule applies.',
        },
      },
    };
  }

  static Map<String, dynamic> _sortConditionSchema() {
    return {
      'type': 'object',
      'description': 'Condition for conditional sort rules.',
      'required': ['type', 'value'],
      'additionalProperties': false,
      'properties': {
        'type': {
          'type': 'string',
          'enum': validSortConditionTypes,
          'description':
              'Condition type. "sortKeyGreaterThan" applies when '
              'the sort key exceeds the given value.',
        },
        'value': {
          'type': 'integer',
          'description': 'Threshold value for the condition.',
        },
      },
    };
  }

  static Map<String, dynamic> _titleExtractorSchema() {
    return {
      'type': 'object',
      'description':
          'Extracts playlist display names from episode data '
          'using source field, regex, and templates.',
      'required': ['source'],
      'additionalProperties': false,
      'properties': {
        'source': {
          'type': 'string',
          'enum': validTitleExtractorSources,
          'description': 'Episode field to extract from.',
        },
        'pattern': {
          'type': 'string',
          'description': 'Regex pattern to extract value from the source.',
        },
        'group': {
          'type': 'integer',
          'default': 0,
          'description':
              'Capture group index from regex match '
              '(0 = full match).',
        },
        'template': {
          'type': 'string',
          'description': 'Template with {value} placeholder for formatting.',
        },
        'fallback': {
          r'$ref': '#/\$defs/SmartPlaylistTitleExtractor',
          'description': 'Fallback extractor when this one fails.',
        },
        'fallbackValue': {
          'type': 'string',
          'description': 'Fallback string for null/zero seasonNumber.',
        },
      },
    };
  }

  static Map<String, dynamic> _episodeNumberExtractorSchema() {
    return {
      'type': 'object',
      'description':
          'Extracts episode-in-season number from episode '
          'titles using regex.',
      'required': ['pattern'],
      'additionalProperties': false,
      'properties': {
        'pattern': {
          'type': 'string',
          'description': 'Regex pattern to extract episode number.',
        },
        'captureGroup': {
          'type': 'integer',
          'default': 1,
          'description': 'Capture group index for the episode number.',
        },
        'fallbackToRss': {
          'type': 'boolean',
          'default': true,
          'description':
              'Whether to fall back to RSS episodeNumber on '
              'regex failure.',
        },
      },
    };
  }

  static Map<String, dynamic> _episodeExtractorSchema() {
    return {
      'type': 'object',
      'description':
          'Extracts both season and episode numbers from '
          'episode title prefixes. Useful for podcasts with unreliable '
          'RSS metadata.',
      'required': ['source', 'pattern'],
      'additionalProperties': false,
      'properties': {
        'source': {
          'type': 'string',
          'enum': validEpisodeExtractorSources,
          'description': 'Episode field to extract from.',
        },
        'pattern': {
          'type': 'string',
          'description':
              'Primary regex to extract both season and '
              'episode numbers.',
        },
        'seasonGroup': {
          'type': 'integer',
          'default': 1,
          'description': 'Capture group index for season number.',
        },
        'episodeGroup': {
          'type': 'integer',
          'default': 2,
          'description': 'Capture group index for episode number.',
        },
        'fallbackSeasonNumber': {
          'type': 'integer',
          'description':
              'Season number when primary pattern fails but '
              'fallback matches.',
        },
        'fallbackEpisodePattern': {
          'type': 'string',
          'description': 'Fallback regex for special episodes.',
        },
        'fallbackEpisodeCaptureGroup': {
          'type': 'integer',
          'default': 1,
          'description': 'Capture group for episode number in fallback.',
        },
      },
    };
  }

  // -- Validation helpers --

  static void _validateRoot(Map<String, dynamic> root, List<String> errors) {
    // Check version
    if (!root.containsKey('version')) {
      errors.add('Missing required field: version');
    } else if (root['version'] is! int) {
      errors.add('Field "version" must be an integer');
    } else if (root['version'] != currentVersion) {
      errors.add(
        'Unsupported version: ${root['version']}. '
        'Expected $currentVersion.',
      );
    }

    // Check patterns
    if (!root.containsKey('patterns')) {
      errors.add('Missing required field: patterns');
    } else if (root['patterns'] is! List) {
      errors.add('Field "patterns" must be an array');
    } else {
      final patterns = root['patterns'] as List<dynamic>;
      for (var i = 0; i < patterns.length; i++) {
        final item = patterns[i];
        if (item is! Map<String, dynamic>) {
          errors.add('patterns[$i]: must be an object');
          continue;
        }
        _validatePatternConfig(item, 'patterns[$i]', errors);
      }
    }
  }

  static void _validatePatternConfig(
    Map<String, dynamic> config,
    String path,
    List<String> errors,
  ) {
    _requireString(config, 'id', path, errors);

    if (!config.containsKey('playlists')) {
      errors.add('$path: missing required field "playlists"');
    } else if (config['playlists'] is! List) {
      errors.add('$path.playlists: must be an array');
    } else {
      final playlists = config['playlists'] as List<dynamic>;
      for (var i = 0; i < playlists.length; i++) {
        final item = playlists[i];
        if (item is! Map<String, dynamic>) {
          errors.add('$path.playlists[$i]: must be an object');
          continue;
        }
        _validatePlaylistDefinition(item, '$path.playlists[$i]', errors);
      }
    }

    _optionalBool(config, 'yearGroupedEpisodes', path, errors);
    _optionalStringList(config, 'feedUrls', path, errors);
    _optionalString(config, 'podcastGuid', path, errors);
  }

  static void _validatePlaylistDefinition(
    Map<String, dynamic> def,
    String path,
    List<String> errors,
  ) {
    _requireString(def, 'id', path, errors);
    _requireString(def, 'displayName', path, errors);

    // resolverType: required + enum
    if (!def.containsKey('resolverType')) {
      errors.add('$path: missing required field "resolverType"');
    } else if (def['resolverType'] is! String) {
      errors.add('$path.resolverType: must be a string');
    } else if (!validResolverTypes.contains(def['resolverType'])) {
      errors.add(
        '$path.resolverType: invalid value "${def['resolverType']}". '
        'Must be one of: ${validResolverTypes.join(', ')}',
      );
    }

    _optionalInt(def, 'priority', path, errors);
    _optionalEnum(def, 'contentType', validContentTypes, path, errors);
    _optionalEnum(def, 'yearHeaderMode', validYearHeaderModes, path, errors);
    _optionalBool(def, 'episodeYearHeaders', path, errors);
    _optionalBool(def, 'showDateRange', path, errors);
    _optionalString(def, 'titleFilter', path, errors);
    _optionalString(def, 'excludeFilter', path, errors);
    _optionalString(def, 'requireFilter', path, errors);
    _optionalInt(def, 'nullSeasonGroupKey', path, errors);

    // groups
    if (def.containsKey('groups')) {
      if (def['groups'] is! List) {
        errors.add('$path.groups: must be an array');
      } else {
        final groups = def['groups'] as List<dynamic>;
        for (var i = 0; i < groups.length; i++) {
          final item = groups[i];
          if (item is! Map<String, dynamic>) {
            errors.add('$path.groups[$i]: must be an object');
            continue;
          }
          _validateGroupDef(item, '$path.groups[$i]', errors);
        }
      }
    }

    // customSort
    if (def.containsKey('customSort')) {
      if (def['customSort'] is! Map<String, dynamic>) {
        errors.add('$path.customSort: must be an object');
      } else {
        _validateSortSpec(
          def['customSort'] as Map<String, dynamic>,
          '$path.customSort',
          errors,
        );
      }
    }

    // titleExtractor
    if (def.containsKey('titleExtractor')) {
      if (def['titleExtractor'] is! Map<String, dynamic>) {
        errors.add('$path.titleExtractor: must be an object');
      } else {
        _validateTitleExtractor(
          def['titleExtractor'] as Map<String, dynamic>,
          '$path.titleExtractor',
          errors,
        );
      }
    }

    // episodeNumberExtractor
    if (def.containsKey('episodeNumberExtractor')) {
      if (def['episodeNumberExtractor'] is! Map<String, dynamic>) {
        errors.add('$path.episodeNumberExtractor: must be an object');
      } else {
        _validateEpisodeNumberExtractor(
          def['episodeNumberExtractor'] as Map<String, dynamic>,
          '$path.episodeNumberExtractor',
          errors,
        );
      }
    }

    // smartPlaylistEpisodeExtractor
    if (def.containsKey('smartPlaylistEpisodeExtractor')) {
      if (def['smartPlaylistEpisodeExtractor'] is! Map<String, dynamic>) {
        errors.add('$path.smartPlaylistEpisodeExtractor: must be an object');
      } else {
        _validateEpisodeExtractor(
          def['smartPlaylistEpisodeExtractor'] as Map<String, dynamic>,
          '$path.smartPlaylistEpisodeExtractor',
          errors,
        );
      }
    }
  }

  static void _validateGroupDef(
    Map<String, dynamic> group,
    String path,
    List<String> errors,
  ) {
    _requireString(group, 'id', path, errors);
    _requireString(group, 'displayName', path, errors);
    _optionalString(group, 'pattern', path, errors);
    _optionalBool(group, 'episodeYearHeaders', path, errors);
    _optionalBool(group, 'showDateRange', path, errors);
  }

  static void _validateSortSpec(
    Map<String, dynamic> sort,
    String path,
    List<String> errors,
  ) {
    if (!sort.containsKey('type')) {
      errors.add('$path: missing required field "type"');
      return;
    }
    if (sort['type'] is! String) {
      errors.add('$path.type: must be a string');
      return;
    }

    final type = sort['type'] as String;
    switch (type) {
      case 'simple':
        _requireEnum(sort, 'field', validSortFields, path, errors);
        _requireEnum(sort, 'order', validSortOrders, path, errors);
      case 'composite':
        if (!sort.containsKey('rules')) {
          errors.add('$path: missing required field "rules"');
        } else if (sort['rules'] is! List) {
          errors.add('$path.rules: must be an array');
        } else {
          final rules = sort['rules'] as List<dynamic>;
          for (var i = 0; i < rules.length; i++) {
            final item = rules[i];
            if (item is! Map<String, dynamic>) {
              errors.add('$path.rules[$i]: must be an object');
              continue;
            }
            _validateSortRule(item, '$path.rules[$i]', errors);
          }
        }
      default:
        errors.add(
          '$path.type: invalid value "$type". '
          'Must be "simple" or "composite".',
        );
    }
  }

  static void _validateSortRule(
    Map<String, dynamic> rule,
    String path,
    List<String> errors,
  ) {
    _requireEnum(rule, 'field', validSortFields, path, errors);
    _requireEnum(rule, 'order', validSortOrders, path, errors);

    if (rule.containsKey('condition')) {
      if (rule['condition'] is! Map<String, dynamic>) {
        errors.add('$path.condition: must be an object');
      } else {
        _validateSortCondition(
          rule['condition'] as Map<String, dynamic>,
          '$path.condition',
          errors,
        );
      }
    }
  }

  static void _validateSortCondition(
    Map<String, dynamic> condition,
    String path,
    List<String> errors,
  ) {
    if (!condition.containsKey('type')) {
      errors.add('$path: missing required field "type"');
    } else if (condition['type'] is! String) {
      errors.add('$path.type: must be a string');
    } else if (!validSortConditionTypes.contains(condition['type'])) {
      errors.add(
        '$path.type: invalid value "${condition['type']}". '
        'Must be one of: ${validSortConditionTypes.join(', ')}',
      );
    }

    if (!condition.containsKey('value')) {
      errors.add('$path: missing required field "value"');
    } else if (condition['value'] is! int) {
      errors.add('$path.value: must be an integer');
    }
  }

  static void _validateTitleExtractor(
    Map<String, dynamic> extractor,
    String path,
    List<String> errors,
  ) {
    _requireEnum(extractor, 'source', validTitleExtractorSources, path, errors);
    _optionalString(extractor, 'pattern', path, errors);
    _optionalInt(extractor, 'group', path, errors);
    _optionalString(extractor, 'template', path, errors);
    _optionalString(extractor, 'fallbackValue', path, errors);

    if (extractor.containsKey('fallback')) {
      if (extractor['fallback'] is! Map<String, dynamic>) {
        errors.add('$path.fallback: must be an object');
      } else {
        _validateTitleExtractor(
          extractor['fallback'] as Map<String, dynamic>,
          '$path.fallback',
          errors,
        );
      }
    }
  }

  static void _validateEpisodeNumberExtractor(
    Map<String, dynamic> extractor,
    String path,
    List<String> errors,
  ) {
    _requireString(extractor, 'pattern', path, errors);
    _optionalInt(extractor, 'captureGroup', path, errors);
    _optionalBool(extractor, 'fallbackToRss', path, errors);
  }

  static void _validateEpisodeExtractor(
    Map<String, dynamic> extractor,
    String path,
    List<String> errors,
  ) {
    _requireEnum(
      extractor,
      'source',
      validEpisodeExtractorSources,
      path,
      errors,
    );
    _requireString(extractor, 'pattern', path, errors);
    _optionalInt(extractor, 'seasonGroup', path, errors);
    _optionalInt(extractor, 'episodeGroup', path, errors);
    _optionalInt(extractor, 'fallbackSeasonNumber', path, errors);
    _optionalString(extractor, 'fallbackEpisodePattern', path, errors);
    _optionalInt(extractor, 'fallbackEpisodeCaptureGroup', path, errors);
  }

  // -- Field validation primitives --

  static void _requireString(
    Map<String, dynamic> map,
    String field,
    String path,
    List<String> errors,
  ) {
    if (!map.containsKey(field)) {
      errors.add('$path: missing required field "$field"');
    } else if (map[field] is! String) {
      errors.add('$path.$field: must be a string');
    }
  }

  static void _requireEnum(
    Map<String, dynamic> map,
    String field,
    List<String> allowed,
    String path,
    List<String> errors,
  ) {
    if (!map.containsKey(field)) {
      errors.add('$path: missing required field "$field"');
    } else if (map[field] is! String) {
      errors.add('$path.$field: must be a string');
    } else if (!allowed.contains(map[field])) {
      errors.add(
        '$path.$field: invalid value "${map[field]}". '
        'Must be one of: ${allowed.join(', ')}',
      );
    }
  }

  static void _optionalString(
    Map<String, dynamic> map,
    String field,
    String path,
    List<String> errors,
  ) {
    if (map.containsKey(field) && map[field] is! String) {
      errors.add('$path.$field: must be a string');
    }
  }

  static void _optionalInt(
    Map<String, dynamic> map,
    String field,
    String path,
    List<String> errors,
  ) {
    if (map.containsKey(field) && map[field] is! int) {
      errors.add('$path.$field: must be an integer');
    }
  }

  static void _optionalBool(
    Map<String, dynamic> map,
    String field,
    String path,
    List<String> errors,
  ) {
    if (map.containsKey(field) && map[field] is! bool) {
      errors.add('$path.$field: must be a boolean');
    }
  }

  static void _optionalEnum(
    Map<String, dynamic> map,
    String field,
    List<String> allowed,
    String path,
    List<String> errors,
  ) {
    if (!map.containsKey(field)) return;
    if (map[field] is! String) {
      errors.add('$path.$field: must be a string');
    } else if (!allowed.contains(map[field])) {
      errors.add(
        '$path.$field: invalid value "${map[field]}". '
        'Must be one of: ${allowed.join(', ')}',
      );
    }
  }

  static void _optionalStringList(
    Map<String, dynamic> map,
    String field,
    String path,
    List<String> errors,
  ) {
    if (!map.containsKey(field)) return;
    if (map[field] is! List) {
      errors.add('$path.$field: must be an array');
      return;
    }
    final list = map[field] as List<dynamic>;
    for (var i = 0; i < list.length; i++) {
      if (list[i] is! String) {
        errors.add('$path.$field[$i]: must be a string');
      }
    }
  }
}
