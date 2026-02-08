import 'dart:convert';

/// Summary of a config for list responses.
final class ConfigSummary {
  const ConfigSummary({
    required this.id,
    this.podcastGuid,
    this.feedUrlPatterns,
    required this.playlistCount,
  });

  final String id;
  final String? podcastGuid;
  final List<String>? feedUrlPatterns;
  final int playlistCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    if (podcastGuid != null) 'podcastGuid': podcastGuid,
    if (feedUrlPatterns != null) 'feedUrlPatterns': feedUrlPatterns,
    'playlistCount': playlistCount,
  };
}

/// Cached config data with a time-to-live (TTL).
final class CachedConfig {
  CachedConfig({
    required this.data,
    required this.fetchedAt,
    this.ttl = const Duration(minutes: 15),
  });

  final String data;
  final DateTime fetchedAt;
  final Duration ttl;

  bool get isStale {
    final elapsed = DateTime.now().difference(fetchedAt);
    return ttl < elapsed;
  }
}

/// Signature for an HTTP GET function, enabling
/// dependency injection for testing.
typedef HttpGetFn = Future<String> Function(Uri url);

/// Repository that reads smart playlist configs from
/// a GitHub repository with in-memory caching.
class ConfigRepository {
  ConfigRepository({
    required HttpGetFn httpGet,
    required String configRepoUrl,
    Duration cacheTtl = const Duration(minutes: 15),
  }) : _httpGet = httpGet,
       _configRepoUrl = configRepoUrl,
       _cacheTtl = cacheTtl;

  final HttpGetFn _httpGet;
  final String _configRepoUrl;
  final Duration _cacheTtl;
  final Map<String, CachedConfig> _cache = {};

  /// Lists all configs from the GitHub repo.
  ///
  /// Fetches the index JSON from [_configRepoUrl],
  /// parses each pattern config, and returns summaries.
  Future<List<ConfigSummary>> listConfigs() async {
    final raw = await _fetchWithCache(_configRepoUrl);
    final parsed = jsonDecode(raw);

    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Config index must be a JSON object');
    }

    final patterns = parsed['patterns'] as List<dynamic>?;
    if (patterns == null) return [];

    return patterns.whereType<Map<String, dynamic>>().map(_toSummary).toList();
  }

  /// Gets a specific config by ID.
  ///
  /// Returns the raw JSON map for the matching pattern
  /// config, or null if not found.
  Future<Map<String, dynamic>?> getConfig(String id) async {
    final raw = await _fetchWithCache(_configRepoUrl);
    final parsed = jsonDecode(raw);

    if (parsed is! Map<String, dynamic>) return null;

    final patterns = parsed['patterns'] as List<dynamic>?;
    if (patterns == null) return null;

    for (final item in patterns) {
      if (item is Map<String, dynamic> && item['id'] == id) {
        return item;
      }
    }
    return null;
  }

  /// Clears all cached data.
  void clearCache() => _cache.clear();

  /// Returns the number of cached entries.
  int get cacheSize => _cache.length;

  Future<String> _fetchWithCache(String url) async {
    final cached = _cache[url];
    if (cached != null && !cached.isStale) {
      return cached.data;
    }

    final data = await _httpGet(Uri.parse(url));
    _cache[url] = CachedConfig(
      data: data,
      fetchedAt: DateTime.now(),
      ttl: _cacheTtl,
    );
    return data;
  }

  ConfigSummary _toSummary(Map<String, dynamic> json) {
    final playlists = json['playlists'] as List<dynamic>?;
    return ConfigSummary(
      id: json['id'] as String? ?? '',
      podcastGuid: json['podcastGuid'] as String?,
      feedUrlPatterns: (json['feedUrlPatterns'] as List<dynamic>?)
          ?.cast<String>(),
      playlistCount: playlists?.length ?? 0,
    );
  }
}
