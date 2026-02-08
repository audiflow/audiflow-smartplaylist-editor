import 'package:xml/xml.dart';

/// A cached feed with a time-to-live (TTL).
final class CachedFeed {
  CachedFeed({
    required this.episodes,
    required this.fetchedAt,
    this.ttl = const Duration(minutes: 15),
  });

  final List<Map<String, dynamic>> episodes;
  final DateTime fetchedAt;
  final Duration ttl;

  /// Whether this cache entry has expired.
  bool get isStale {
    final elapsed = DateTime.now().difference(fetchedAt);
    return ttl < elapsed;
  }
}

/// Signature for an HTTP GET function, enabling
/// dependency injection for testing.
typedef HttpGetFn = Future<String> Function(Uri url);

/// Service that fetches podcast RSS feeds, parses
/// episode data, and caches results in memory.
class FeedCacheService {
  FeedCacheService({
    required HttpGetFn httpGet,
    Duration cacheTtl = const Duration(minutes: 15),
  }) : _httpGet = httpGet,
       _cacheTtl = cacheTtl;

  final HttpGetFn _httpGet;
  final Duration _cacheTtl;
  final Map<String, CachedFeed> _cache = {};

  /// Fetches episodes from the given feed [url].
  ///
  /// Returns cached data if still fresh; otherwise
  /// fetches and parses the RSS feed anew.
  Future<List<Map<String, dynamic>>> fetchFeed(String url) async {
    final cached = _cache[url];
    if (cached != null && !cached.isStale) {
      return cached.episodes;
    }

    final xml = await _httpGet(Uri.parse(url));
    final episodes = _parseRss(xml);

    _cache[url] = CachedFeed(
      episodes: episodes,
      fetchedAt: DateTime.now(),
      ttl: _cacheTtl,
    );

    return episodes;
  }

  /// Clears all cached feed data.
  void clearCache() => _cache.clear();

  /// Returns the number of cached feeds.
  int get cacheSize => _cache.length;

  /// Parses minimal episode data from RSS XML.
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
      final episode = _parseItem(item, index);
      episodes.add(episode);
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

  /// Extracts text content from a child element.
  String? _text(XmlElement parent, String name) {
    final elements = parent.findElements(name);
    if (elements.isEmpty) return null;
    final text = elements.first.innerText.trim();
    return text.isEmpty ? null : text;
  }

  /// Extracts text from an `itunes:*` namespaced
  /// child element.
  String? _itunesText(XmlElement parent, String name) {
    for (final child in parent.children) {
      if (child is! XmlElement) continue;
      final localName = child.name.local;
      final prefix = child.name.prefix;
      if (localName == name && prefix == 'itunes') {
        final text = child.innerText.trim();
        return text.isEmpty ? null : text;
      }
    }
    return null;
  }

  /// Extracts the image URL from `itunes:image`.
  String? _itunesImageUrl(XmlElement parent) {
    for (final child in parent.children) {
      if (child is! XmlElement) continue;
      if (child.name.local != 'image') continue;
      if (child.name.prefix != 'itunes') continue;
      return child.getAttribute('href');
    }
    return null;
  }

  /// Parses an RFC 2822 date string to ISO 8601.
  String? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    final parsed = DateTime.tryParse(dateStr);
    if (parsed != null) return parsed.toIso8601String();

    // Try RFC 2822 format commonly used in RSS.
    final rfc2822 = _parseRfc2822(dateStr);
    return rfc2822?.toIso8601String();
  }

  /// Best-effort RFC 2822 date parser.
  DateTime? _parseRfc2822(String input) {
    try {
      // Remove day-of-week prefix if present.
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

    if (day == null || month == null || year == null) {
      return null;
    }

    final timeParts = parts[3].split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = 2 <= timeParts.length ? int.tryParse(timeParts[1]) ?? 0 : 0;
    final second = 3 <= timeParts.length ? int.tryParse(timeParts[2]) ?? 0 : 0;

    return DateTime.utc(year, month, day, hour, minute, second);
  }

  int? _monthNumber(String abbr) {
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
