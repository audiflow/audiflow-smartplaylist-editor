import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';

/// Cached data with a time-to-live (TTL).
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

/// Repository that reads split config files from
/// a GitHub repository with in-memory caching.
///
/// Supports three-level lazy loading:
/// - Level 1: root meta.json (pattern summaries)
/// - Level 2: {patternId}/meta.json (pattern metadata)
/// - Level 3: {patternId}/playlists/{playlistId}.json
class ConfigRepository {
  ConfigRepository({
    required HttpGetFn httpGet,
    required String baseUrl,
    Duration rootTtl = const Duration(minutes: 5),
    Duration fileTtl = const Duration(minutes: 30),
  }) : _httpGet = httpGet,
       _baseUrl = baseUrl,
       _rootTtl = rootTtl,
       _fileTtl = fileTtl;

  final HttpGetFn _httpGet;
  final String _baseUrl;
  final Duration _rootTtl;
  final Duration _fileTtl;
  final Map<String, CachedConfig> _cache = {};

  /// Lists all pattern summaries from root meta.json.
  Future<List<PatternSummary>> listPatterns() async {
    final url = '$_baseUrl/meta.json';
    final raw = await _fetchWithCache(url, _rootTtl);
    final rootMeta = RootMeta.parseJson(raw);
    return rootMeta.patterns;
  }

  /// Gets pattern metadata for a specific pattern.
  Future<PatternMeta> getPatternMeta(String patternId) async {
    final url = '$_baseUrl/$patternId/meta.json';
    final raw = await _fetchWithCache(url, _fileTtl);
    return PatternMeta.parseJson(raw);
  }

  /// Gets a single playlist definition by pattern and playlist ID.
  Future<SmartPlaylistDefinition> getPlaylist(
    String patternId,
    String playlistId,
  ) async {
    final url = '$_baseUrl/$patternId/playlists/$playlistId.json';
    final raw = await _fetchWithCache(url, _fileTtl);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return SmartPlaylistDefinition.fromJson(json);
  }

  /// Assembles a full config from pattern meta and all playlists.
  ///
  /// Fetches the pattern meta, then fetches each playlist
  /// referenced in the meta, and assembles them using
  /// [ConfigAssembler].
  Future<SmartPlaylistPatternConfig> assembleConfig(String patternId) async {
    final meta = await getPatternMeta(patternId);

    final playlists = <SmartPlaylistDefinition>[];
    for (final playlistId in meta.playlists) {
      playlists.add(await getPlaylist(patternId, playlistId));
    }

    return ConfigAssembler.assemble(meta, playlists);
  }

  /// Clears all cached data.
  void clearCache() => _cache.clear();

  /// Returns the number of cached entries.
  int get cacheSize => _cache.length;

  Future<String> _fetchWithCache(String url, Duration ttl) async {
    final cached = _cache[url];
    if (cached != null && !cached.isStale) {
      return cached.data;
    }

    final data = await _httpGet(Uri.parse(url));
    _cache[url] = CachedConfig(data: data, fetchedAt: DateTime.now(), ttl: ttl);
    return data;
  }
}
