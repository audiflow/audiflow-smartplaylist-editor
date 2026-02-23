import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

/// Signature for an HTTP GET function.
typedef HttpGetFn = Future<String> Function(Uri url);

/// Disk-based feed cache that can be shared between processes.
///
/// Caches parsed RSS episodes as JSON files on disk, keyed by
/// SHA-256 hash of the feed URL. Two separate processes pointing
/// at the same [cacheDir] will share cached data.
class DiskFeedCacheService {
  DiskFeedCacheService({
    required String cacheDir,
    required HttpGetFn httpGet,
    Duration cacheTtl = const Duration(hours: 1),
  }) : _cacheDir = cacheDir,
       _httpGet = httpGet,
       _cacheTtl = cacheTtl;

  final String _cacheDir;
  final HttpGetFn _httpGet;
  final Duration _cacheTtl;

  /// Fetches episodes from the given feed [url].
  ///
  /// Returns cached data from disk if still fresh; otherwise
  /// fetches the RSS feed, parses it, and caches to disk.
  Future<List<Map<String, dynamic>>> fetchFeed(String url) async {
    final hash = _hashUrl(url);
    final cached = await _readCache(hash);
    if (cached != null) {
      return cached;
    }

    final xml = await _httpGet(Uri.parse(url));
    final episodes = _parseRss(xml);
    await _writeCache(hash, url, episodes);
    return episodes;
  }

  // -- Cache I/O -------------------------------------------------------

  String _hashUrl(String url) {
    final bytes = utf8.encode(url);
    return sha256.convert(bytes).toString();
  }

  File _metaFile(String hash) => File('$_cacheDir/$hash.meta');
  File _dataFile(String hash) => File('$_cacheDir/$hash.json');

  /// Reads cached episodes from disk if the cache is fresh.
  Future<List<Map<String, dynamic>>?> _readCache(String hash) async {
    final metaFile = _metaFile(hash);
    if (!await metaFile.exists()) return null;

    try {
      final metaJson =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      final fetchedAt = DateTime.parse(metaJson['fetchedAt'] as String);
      final elapsed = DateTime.now().difference(fetchedAt);
      if (_cacheTtl < elapsed) return null;

      final dataFile = _dataFile(hash);
      if (!await dataFile.exists()) return null;

      final raw = jsonDecode(await dataFile.readAsString()) as List<dynamic>;
      return raw.cast<Map<String, dynamic>>();
    } on Object {
      // Corrupted cache -- treat as miss.
      return null;
    }
  }

  /// Writes episodes and metadata to disk atomically.
  Future<void> _writeCache(
    String hash,
    String url,
    List<Map<String, dynamic>> episodes,
  ) async {
    final dir = Directory(_cacheDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final meta = jsonEncode({
      'url': url,
      'fetchedAt': DateTime.now().toIso8601String(),
    });
    final data = jsonEncode(episodes);

    // Write data before meta so a crash between writes leaves stale meta
    // (safe cache miss) rather than fresh meta pointing to stale data.
    await _atomicWrite(_dataFile(hash), data);
    await _atomicWrite(_metaFile(hash), meta);
  }

  Future<void> _atomicWrite(File target, String content) async {
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(target.path);
  }

  // -- RSS parsing (ported from FeedCacheService in sp_server) ----------

  List<Map<String, dynamic>> _parseRss(String xml) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } on XmlParserException {
      return [];
    }

    final items = document.findAllElements('item');
    final episodes = <Map<String, dynamic>>[];
    var index = 0;

    for (final item in items) {
      episodes.add(_parseItem(item, index));
      index++;
    }

    return episodes;
  }

  Map<String, dynamic> _parseItem(XmlElement item, int index) {
    return {
      'id': index,
      'title': _text(item, 'title') ?? '',
      'description': _text(item, 'description'),
      'guid': _text(item, 'guid'),
      'publishedAt': _parseDate(_text(item, 'pubDate')),
      'seasonNumber': _parseInt(_itunesText(item, 'season')),
      'episodeNumber': _parseInt(_itunesText(item, 'episode')),
      'imageUrl': _itunesImageUrl(item),
    };
  }

  String? _text(XmlElement parent, String name) {
    final elements = parent.findElements(name);
    if (elements.isEmpty) return null;
    final text = elements.first.innerText.trim();
    return text.isEmpty ? null : text;
  }

  String? _itunesText(XmlElement parent, String name) {
    for (final child in parent.children) {
      if (child is! XmlElement) continue;
      if (child.name.local == name && child.name.prefix == 'itunes') {
        final text = child.innerText.trim();
        return text.isEmpty ? null : text;
      }
    }
    return null;
  }

  String? _itunesImageUrl(XmlElement parent) {
    for (final child in parent.children) {
      if (child is! XmlElement) continue;
      if (child.name.local != 'image') continue;
      if (child.name.prefix != 'itunes') continue;
      return child.getAttribute('href');
    }
    return null;
  }

  String? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    final parsed = DateTime.tryParse(dateStr);
    if (parsed != null) return parsed.toIso8601String();
    return _parseRfc2822(dateStr)?.toIso8601String();
  }

  DateTime? _parseRfc2822(String input) {
    try {
      final cleaned = input.contains(',')
          ? input.substring(input.indexOf(',') + 1).trim()
          : input.trim();

      final parts = cleaned.split(RegExp(r'\s+'));
      if (4 <= parts.length) {
        return _assembleDate(parts);
      }
    } on Object {
      // Swallow parse failures.
    }
    return null;
  }

  DateTime? _assembleDate(List<String> parts) {
    final day = int.tryParse(parts[0]);
    final month = _monthNumber(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;

    final timeParts = parts[3].split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = 2 <= timeParts.length ? int.tryParse(timeParts[1]) ?? 0 : 0;
    final second = 3 <= timeParts.length ? int.tryParse(timeParts[2]) ?? 0 : 0;

    return DateTime.utc(year, month, day, hour, minute, second);
  }

  static int? _monthNumber(String abbr) {
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    return months[abbr];
  }

  int? _parseInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value);
  }
}
