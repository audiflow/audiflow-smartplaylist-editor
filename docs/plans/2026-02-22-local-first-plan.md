# Local-First Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the webapp from a GitHub-hosted remote editor to a local-first config editor that reads/writes files on disk.

**Architecture:** The server reads/writes split config files from a local data repo directory (auto-detected from CWD). No authentication. SSE pushes file change events to the browser. Both the web server and MCP server share a disk-based feed cache. See `docs/plans/2026-02-22-local-first-redesign.md` for the full design.

**Tech Stack:** Dart (shelf), React 19 (TanStack Query/Router, Zustand, shadcn/ui), MCP (JSON-RPC over stdio)

---

## Task 1: DiskFeedCacheService in sp_shared

Shared disk-based feed cache used by both web server and MCP server. Replaces in-memory `FeedCacheService`.

**Files:**
- Create: `packages/sp_shared/lib/src/services/disk_feed_cache_service.dart`
- Test: `packages/sp_shared/test/services/disk_feed_cache_service_test.dart`
- Modify: `packages/sp_shared/lib/sp_shared.dart` (export new service)

**Step 1: Write the failing tests**

```dart
// disk_feed_cache_service_test.dart
import 'dart:io';
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late DiskFeedCacheService service;
  late List<String> fetchedUrls;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('feed_cache_test_');
    fetchedUrls = [];
    service = DiskFeedCacheService(
      cacheDir: tempDir.path,
      cacheTtl: const Duration(seconds: 5),
      httpGet: (Uri url) async {
        fetchedUrls.add(url.toString());
        return '<rss><channel><item><title>Ep 1</title></item></channel></rss>';
      },
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('fetches and caches feed to disk', () async {
    final episodes = await service.fetchFeed('https://example.com/feed.xml');
    expect(episodes, isNotEmpty);
    expect(fetchedUrls, hasLength(1));

    // Second call reads from disk cache, no HTTP fetch
    final cached = await service.fetchFeed('https://example.com/feed.xml');
    expect(cached, equals(episodes));
    expect(fetchedUrls, hasLength(1));
  });

  test('refetches when cache is stale', () async {
    service = DiskFeedCacheService(
      cacheDir: tempDir.path,
      cacheTtl: Duration.zero,
      httpGet: (Uri url) async {
        fetchedUrls.add(url.toString());
        return '<rss><channel><item><title>Ep 1</title></item></channel></rss>';
      },
    );

    await service.fetchFeed('https://example.com/feed.xml');
    await service.fetchFeed('https://example.com/feed.xml');
    expect(fetchedUrls, hasLength(2));
  });

  test('creates cache directory if missing', () async {
    final nested = '${tempDir.path}/deep/nested/cache';
    service = DiskFeedCacheService(
      cacheDir: nested,
      httpGet: (Uri url) async => '<rss><channel></channel></rss>',
    );
    await service.fetchFeed('https://example.com/feed.xml');
    expect(Directory(nested).existsSync(), isTrue);
  });

  test('shared cache between instances', () async {
    await service.fetchFeed('https://example.com/feed.xml');
    expect(fetchedUrls, hasLength(1));

    // New instance, same cache dir
    final other = DiskFeedCacheService(
      cacheDir: tempDir.path,
      cacheTtl: const Duration(seconds: 5),
      httpGet: (Uri url) async {
        fetchedUrls.add(url.toString());
        return '';
      },
    );
    await other.fetchFeed('https://example.com/feed.xml');
    expect(fetchedUrls, hasLength(1)); // No additional fetch
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_shared/test/services/disk_feed_cache_service_test.dart`
Expected: Compilation error - `DiskFeedCacheService` not defined

**Step 3: Write minimal implementation**

```dart
// disk_feed_cache_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

/// Signature for an HTTP GET function.
typedef HttpGetFn = Future<String> Function(Uri url);

/// Disk-based feed cache shared between web server and MCP.
///
/// Stores fetched RSS XML and parsed episodes in a cache
/// directory, keyed by SHA-256 hash of the feed URL.
/// Both processes can read/write the same cache directory.
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
  /// Returns cached data if the disk cache is fresh;
  /// otherwise fetches, parses, and caches the feed.
  Future<List<Map<String, dynamic>>> fetchFeed(String url) async {
    final hash = _hashUrl(url);
    final metaFile = File('$_cacheDir/$hash.meta');
    final dataFile = File('$_cacheDir/$hash.json');

    if (metaFile.existsSync() && dataFile.existsSync()) {
      final meta = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      final fetchedAt = DateTime.parse(meta['fetchedAt'] as String);
      final elapsed = DateTime.now().difference(fetchedAt);
      if (elapsed < _cacheTtl) {
        final cached = jsonDecode(dataFile.readAsStringSync()) as List<dynamic>;
        return cached.cast<Map<String, dynamic>>();
      }
    }

    final xml = await _httpGet(Uri.parse(url));
    final episodes = _parseRss(xml);

    await _writeCache(hash, url, episodes);
    return episodes;
  }

  String _hashUrl(String url) {
    return sha256.convert(utf8.encode(url)).toString();
  }

  Future<void> _writeCache(
    String hash,
    String url,
    List<Map<String, dynamic>> episodes,
  ) async {
    final dir = Directory(_cacheDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final metaFile = File('$_cacheDir/$hash.meta');
    final dataFile = File('$_cacheDir/$hash.json');

    // Write data first, then meta (atomic-ish)
    final tmpData = File('${dataFile.path}.tmp');
    tmpData.writeAsStringSync(jsonEncode(episodes));
    tmpData.renameSync(dataFile.path);

    final tmpMeta = File('${metaFile.path}.tmp');
    tmpMeta.writeAsStringSync(jsonEncode({
      'url': url,
      'fetchedAt': DateTime.now().toIso8601String(),
    }));
    tmpMeta.renameSync(metaFile.path);
  }

  // --- RSS parsing (extracted from FeedCacheService) ---

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
    final rfc2822 = _parseRfc2822(dateStr);
    return rfc2822?.toIso8601String();
  }

  DateTime? _parseRfc2822(String input) {
    try {
      final cleaned = input.contains(',')
          ? input.substring(input.indexOf(',') + 1).trim()
          : input.trim();
      final parts = cleaned.split(RegExp(r'\s+'));
      if (4 <= parts.length) return _assembleDate(parts);
    } on Object {
      // Swallow parse failures
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

  int? _monthNumber(String abbr) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    return months[abbr];
  }

  int? _parseInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value);
  }
}
```

Note: Add `crypto: ^3.0.0` to `sp_shared/pubspec.yaml` dependencies.

**Step 4: Run tests to verify they pass**

Run: `dart test packages/sp_shared/test/services/disk_feed_cache_service_test.dart`
Expected: All 4 tests PASS

**Step 5: Export from sp_shared barrel**

Add to `packages/sp_shared/lib/sp_shared.dart`:
```dart
export 'src/services/disk_feed_cache_service.dart';
```

**Step 6: Commit**

```
feat: add DiskFeedCacheService for shared disk-based feed caching
```

---

## Task 2: LocalConfigRepository

Reads and writes split config files from the local filesystem. Replaces the HTTP-based `ConfigRepository`.

**Files:**
- Create: `packages/sp_server/lib/src/services/local_config_repository.dart`
- Test: `packages/sp_server/test/services/local_config_repository_test.dart`

**Step 1: Write the failing tests**

```dart
// local_config_repository_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:sp_server/src/services/local_config_repository.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late LocalConfigRepository repo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('config_repo_test_');
    // Create patterns/ subdirectory
    final patternsDir = Directory('${tempDir.path}/patterns');
    patternsDir.createSync();
    repo = LocalConfigRepository(dataDir: tempDir.path);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  group('listPatterns', () {
    test('reads root meta.json', () async {
      File('${tempDir.path}/patterns/meta.json').writeAsStringSync(jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'pod-a',
            'version': 1,
            'displayName': 'Podcast A',
            'feedUrlHint': 'example.com/a',
            'playlistCount': 2,
          },
        ],
      }));

      final patterns = await repo.listPatterns();
      expect(patterns, hasLength(1));
      expect(patterns.first.id, 'pod-a');
    });

    test('throws when meta.json missing', () async {
      expect(() => repo.listPatterns(), throwsA(isA<FileSystemException>()));
    });
  });

  group('getPatternMeta', () {
    test('reads pattern meta.json', () async {
      final dir = Directory('${tempDir.path}/patterns/pod-a');
      dir.createSync(recursive: true);
      File('${dir.path}/meta.json').writeAsStringSync(jsonEncode({
        'version': 1,
        'id': 'pod-a',
        'feedUrls': ['https://example.com/feed.xml'],
        'playlists': ['main'],
      }));

      final meta = await repo.getPatternMeta('pod-a');
      expect(meta.id, 'pod-a');
      expect(meta.playlists, ['main']);
    });
  });

  group('getPlaylist', () {
    test('reads playlist definition', () async {
      final dir = Directory('${tempDir.path}/patterns/pod-a/playlists');
      dir.createSync(recursive: true);
      File('${dir.path}/main.json').writeAsStringSync(jsonEncode({
        'id': 'main',
        'displayName': 'Main',
        'resolverType': 'rss',
      }));

      final playlist = await repo.getPlaylist('pod-a', 'main');
      expect(playlist.id, 'main');
      expect(playlist.resolverType, 'rss');
    });
  });

  group('savePlaylist', () {
    test('writes playlist JSON to disk', () async {
      final dir = Directory('${tempDir.path}/patterns/pod-a/playlists');
      dir.createSync(recursive: true);

      await repo.savePlaylist('pod-a', 'main', {
        'id': 'main',
        'displayName': 'Main',
        'resolverType': 'rss',
      });

      final file = File('${dir.path}/main.json');
      expect(file.existsSync(), isTrue);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['id'], 'main');
    });
  });

  group('savePatternMeta', () {
    test('writes pattern meta to disk', () async {
      final dir = Directory('${tempDir.path}/patterns/pod-a');
      dir.createSync(recursive: true);

      await repo.savePatternMeta('pod-a', {
        'version': 1,
        'id': 'pod-a',
        'feedUrls': ['https://example.com/feed.xml'],
        'playlists': ['main'],
      });

      final file = File('${dir.path}/meta.json');
      expect(file.existsSync(), isTrue);
    });
  });

  group('createPattern', () {
    test('creates pattern directory and meta', () async {
      await repo.createPattern('new-pod', {
        'version': 1,
        'id': 'new-pod',
        'feedUrls': ['https://example.com/new.xml'],
        'playlists': [],
      });

      final metaFile = File('${tempDir.path}/patterns/new-pod/meta.json');
      expect(metaFile.existsSync(), isTrue);
      final playlistsDir = Directory('${tempDir.path}/patterns/new-pod/playlists');
      expect(playlistsDir.existsSync(), isTrue);
    });
  });

  group('deletePlaylist', () {
    test('removes playlist file', () async {
      final dir = Directory('${tempDir.path}/patterns/pod-a/playlists');
      dir.createSync(recursive: true);
      final file = File('${dir.path}/main.json');
      file.writeAsStringSync('{}');

      await repo.deletePlaylist('pod-a', 'main');
      expect(file.existsSync(), isFalse);
    });
  });

  group('deletePattern', () {
    test('removes entire pattern directory', () async {
      final dir = Directory('${tempDir.path}/patterns/pod-a/playlists');
      dir.createSync(recursive: true);
      File('${dir.path}/main.json').writeAsStringSync('{}');

      await repo.deletePattern('pod-a');
      expect(Directory('${tempDir.path}/patterns/pod-a').existsSync(), isFalse);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_server/test/services/local_config_repository_test.dart`
Expected: Compilation error

**Step 3: Write implementation**

```dart
// local_config_repository.dart
import 'dart:convert';
import 'dart:io';

import 'package:sp_shared/sp_shared.dart';

/// Repository that reads and writes split config files
/// from the local filesystem.
///
/// Expects the data repo directory structure:
///   patterns/meta.json
///   patterns/{id}/meta.json
///   patterns/{id}/playlists/{pid}.json
class LocalConfigRepository {
  LocalConfigRepository({required String dataDir})
      : _patternsDir = '$dataDir/patterns';

  final String _patternsDir;

  Future<List<PatternSummary>> listPatterns() async {
    final file = File('$_patternsDir/meta.json');
    final raw = await file.readAsString();
    final rootMeta = RootMeta.parseJson(raw);
    return rootMeta.patterns;
  }

  Future<PatternMeta> getPatternMeta(String patternId) async {
    final file = File('$_patternsDir/$patternId/meta.json');
    final raw = await file.readAsString();
    return PatternMeta.parseJson(raw);
  }

  Future<SmartPlaylistDefinition> getPlaylist(
    String patternId,
    String playlistId,
  ) async {
    final file = File('$_patternsDir/$patternId/playlists/$playlistId.json');
    final raw = await file.readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return SmartPlaylistDefinition.fromJson(json);
  }

  Future<SmartPlaylistPatternConfig> assembleConfig(String patternId) async {
    final meta = await getPatternMeta(patternId);
    final playlists = <SmartPlaylistDefinition>[];
    for (final playlistId in meta.playlists) {
      playlists.add(await getPlaylist(patternId, playlistId));
    }
    return ConfigAssembler.assemble(meta, playlists);
  }

  Future<void> savePlaylist(
    String patternId,
    String playlistId,
    Map<String, dynamic> json,
  ) async {
    final file = File('$_patternsDir/$patternId/playlists/$playlistId.json');
    await _writeJsonAtomic(file, json);
  }

  Future<void> savePatternMeta(
    String patternId,
    Map<String, dynamic> json,
  ) async {
    final file = File('$_patternsDir/$patternId/meta.json');
    await _writeJsonAtomic(file, json);
  }

  Future<void> createPattern(
    String patternId,
    Map<String, dynamic> metaJson,
  ) async {
    final dir = Directory('$_patternsDir/$patternId/playlists');
    await dir.create(recursive: true);
    final metaFile = File('$_patternsDir/$patternId/meta.json');
    await _writeJsonAtomic(metaFile, metaJson);
  }

  Future<void> deletePlaylist(String patternId, String playlistId) async {
    final file = File('$_patternsDir/$patternId/playlists/$playlistId.json');
    if (file.existsSync()) await file.delete();
  }

  Future<void> deletePattern(String patternId) async {
    final dir = Directory('$_patternsDir/$patternId');
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Reads the schema.json from the data repo's schema/ directory.
  Future<String> readSchema(String dataDir) async {
    final file = File('$dataDir/schema/schema.json');
    return file.readAsString();
  }

  Future<void> _writeJsonAtomic(
    File file,
    Map<String, dynamic> json,
  ) async {
    final encoder = const JsonEncoder.withIndent('  ');
    final content = encoder.convert(json);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString('$content\n');
    await tmp.rename(file.path);
  }
}
```

**Step 4: Run tests**

Run: `dart test packages/sp_server/test/services/local_config_repository_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```
feat: add LocalConfigRepository for local filesystem config access
```

---

## Task 3: FileWatcherService

Watches the data directory for file changes and emits events.

**Files:**
- Create: `packages/sp_server/lib/src/services/file_watcher_service.dart`
- Test: `packages/sp_server/test/services/file_watcher_service_test.dart`

**Step 1: Write failing tests**

```dart
// file_watcher_service_test.dart
import 'dart:async';
import 'dart:io';
import 'package:sp_server/src/services/file_watcher_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late FileWatcherService watcher;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('watcher_test_');
    watcher = FileWatcherService(
      watchDir: tempDir.path,
      debounceMs: 50,
      ignorePatterns: ['.cache'],
    );
  });

  tearDown(() async {
    await watcher.stop();
    tempDir.deleteSync(recursive: true);
  });

  test('emits event when file is created', () async {
    watcher.start();
    final events = <FileChangeEvent>[];
    final sub = watcher.events.listen(events.add);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    File('${tempDir.path}/test.json').writeAsStringSync('{}');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(events, isNotEmpty);
    expect(events.any((e) => e.path.contains('test.json')), isTrue);

    await sub.cancel();
  });

  test('ignores .cache directory', () async {
    final cacheDir = Directory('${tempDir.path}/.cache');
    cacheDir.createSync();

    watcher.start();
    final events = <FileChangeEvent>[];
    final sub = watcher.events.listen(events.add);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    File('${cacheDir.path}/feed.json').writeAsStringSync('{}');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(events.where((e) => e.path.contains('.cache')), isEmpty);

    await sub.cancel();
  });
}
```

**Step 2: Run test to verify failure**

Run: `dart test packages/sp_server/test/services/file_watcher_service_test.dart`
Expected: Compilation error

**Step 3: Write implementation**

```dart
// file_watcher_service.dart
import 'dart:async';
import 'dart:io';

/// A file change event emitted by [FileWatcherService].
final class FileChangeEvent {
  const FileChangeEvent({required this.type, required this.path});

  final FileChangeType type;

  /// Relative path from the watched directory.
  final String path;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'path': path,
  };
}

enum FileChangeType { created, modified, deleted }

/// Watches a directory recursively and emits debounced
/// file change events. Ignores paths matching ignore patterns.
class FileWatcherService {
  FileWatcherService({
    required String watchDir,
    int debounceMs = 200,
    List<String> ignorePatterns = const [],
  }) : _watchDir = watchDir,
       _debounceMs = debounceMs,
       _ignorePatterns = ignorePatterns;

  final String _watchDir;
  final int _debounceMs;
  final List<String> _ignorePatterns;

  final _controller = StreamController<FileChangeEvent>.broadcast();
  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounceTimer;
  final _pendingEvents = <String, FileChangeEvent>{};

  Stream<FileChangeEvent> get events => _controller.stream;

  void start() {
    final dir = Directory(_watchDir);
    _subscription = dir.watch(recursive: true).listen(_onRawEvent);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _debounceTimer?.cancel();
    await _controller.close();
  }

  void _onRawEvent(FileSystemEvent event) {
    final relativePath = event.path.substring(_watchDir.length + 1);

    // Skip ignored patterns
    for (final pattern in _ignorePatterns) {
      if (relativePath.startsWith(pattern)) return;
    }

    // Skip tmp files from atomic writes
    if (relativePath.endsWith('.tmp')) return;

    final type = switch (event.type) {
      FileSystemEvent.create => FileChangeType.created,
      FileSystemEvent.modify => FileChangeType.modified,
      FileSystemEvent.delete => FileChangeType.deleted,
      _ => FileChangeType.modified,
    };

    _pendingEvents[relativePath] = FileChangeEvent(
      type: type,
      path: relativePath,
    );

    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      Duration(milliseconds: _debounceMs),
      _flushPending,
    );
  }

  void _flushPending() {
    for (final event in _pendingEvents.values) {
      _controller.add(event);
    }
    _pendingEvents.clear();
  }
}
```

**Step 4: Run tests**

Run: `dart test packages/sp_server/test/services/file_watcher_service_test.dart`
Expected: All tests PASS

**Step 5: Commit**

```
feat: add FileWatcherService for local file change detection
```

---

## Task 4: SSE Events Route

Server-Sent Events endpoint that streams file changes to the browser.

**Files:**
- Create: `packages/sp_server/lib/src/routes/events_routes.dart`
- Test: `packages/sp_server/test/routes/events_routes_test.dart`

**Step 1: Write failing tests**

```dart
// events_routes_test.dart
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:sp_server/src/routes/events_routes.dart';
import 'package:sp_server/src/services/file_watcher_service.dart';
import 'package:test/test.dart';

void main() {
  test('returns SSE content type', () async {
    final controller = StreamController<FileChangeEvent>.broadcast();
    final handler = eventsHandler(eventStream: controller.stream);
    final request = Request('GET', Uri.parse('http://localhost/api/events'));
    final response = await handler(request);

    expect(response.statusCode, 200);
    expect(response.headers['content-type'], 'text/event-stream');
    expect(response.headers['cache-control'], 'no-cache');

    await controller.close();
  });
}
```

**Step 2: Run test to verify failure**

Run: `dart test packages/sp_server/test/routes/events_routes_test.dart`
Expected: Compilation error

**Step 3: Write implementation**

```dart
// events_routes.dart
import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../services/file_watcher_service.dart';

/// Returns a handler that streams file change events as SSE.
Handler eventsHandler({
  required Stream<FileChangeEvent> eventStream,
}) {
  return (Request request) {
    final controller = StreamController<List<int>>();

    final subscription = eventStream.listen((event) {
      final data = jsonEncode(event.toJson());
      controller.add(utf8.encode('data: $data\n\n'));
    });

    // Clean up when the client disconnects.
    controller.onCancel = () async {
      await subscription.cancel();
    };

    return Response.ok(
      controller.stream,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    );
  };
}
```

**Step 4: Run tests**

Run: `dart test packages/sp_server/test/routes/events_routes_test.dart`
Expected: PASS

**Step 5: Commit**

```
feat: add SSE events endpoint for file change streaming
```

---

## Task 5: Strip Auth, GitHub, and Drafts from sp_server

Remove all authentication, GitHub API, draft, and submit code from the server.

**Files to delete:**
- `packages/sp_server/lib/src/routes/auth_routes.dart`
- `packages/sp_server/lib/src/routes/submit_routes.dart`
- `packages/sp_server/lib/src/routes/draft_routes.dart`
- `packages/sp_server/lib/src/routes/key_routes.dart`
- `packages/sp_server/lib/src/services/github_oauth_service.dart`
- `packages/sp_server/lib/src/services/github_app_service.dart`
- `packages/sp_server/lib/src/services/jwt_service.dart`
- `packages/sp_server/lib/src/services/api_key_service.dart`
- `packages/sp_server/lib/src/services/draft_service.dart`
- `packages/sp_server/lib/src/services/user_service.dart`
- `packages/sp_server/lib/src/services/config_repository.dart`
- `packages/sp_server/lib/src/middleware/auth_middleware.dart`
- `packages/sp_server/lib/src/middleware/api_key_middleware.dart`
- `packages/sp_server/lib/src/models/api_key.dart`
- `packages/sp_server/lib/src/models/draft.dart`
- `packages/sp_server/lib/src/models/user.dart`
- All corresponding test files in `packages/sp_server/test/`

**Files to modify:**
- `packages/sp_server/lib/src/services/feed_cache_service.dart` - keep RSS parsing but delegate caching to DiskFeedCacheService (or replace entirely)

**Step 1: Delete all source files listed above**

Use `rm` for each file. Delete corresponding test files too.

**Step 2: Remove auth dependencies from pubspec.yaml**

Check `packages/sp_server/pubspec.yaml` for packages only used by removed services (e.g., `dart_jsonwebtoken`, any GitHub API package). Remove them.

**Step 3: Run analyzer to find broken imports**

Run: `dart analyze packages/sp_server`
Expected: Errors in `config_routes.dart`, `feed_routes.dart`, `server.dart` (they still import deleted files)

**Step 4: Fix config_routes.dart**

Remove auth middleware imports and usage. The `configRouter` function no longer takes `jwtService` or `apiKeyService` parameters. Remove `unifiedAuthMiddleware` calls. Register handlers directly without Pipeline/auth.

Replace `ConfigRepository` parameter with `LocalConfigRepository`.

**Step 5: Fix feed_routes.dart**

Remove auth middleware. Replace `FeedCacheService` with `DiskFeedCacheService`. Simplify `feedRouter` to just take a `DiskFeedCacheService` parameter.

**Step 6: Run tests**

Run: `dart test packages/sp_server`
Expected: Remaining tests pass (config_routes_test and feed_routes_test may need updates to remove auth setup)

**Step 7: Commit**

```
refactor: remove auth, GitHub, drafts, and submit from sp_server
```

---

## Task 6: Add Write Endpoints to Config Routes

Add PUT, POST, DELETE endpoints for writing configs to disk.

**Files:**
- Modify: `packages/sp_server/lib/src/routes/config_routes.dart`
- Modify: `packages/sp_server/test/routes/config_routes_test.dart`

**Step 1: Write failing tests for new endpoints**

```dart
// Add to config_routes_test.dart:

test('PUT /api/configs/patterns/<id>/playlists/<pid> saves playlist', () async {
  // Setup temp dir with pattern directory
  // POST the playlist JSON
  // Verify file written to disk
  // Verify response 200
});

test('PUT /api/configs/patterns/<id>/meta saves pattern meta', () async {
  // Setup temp dir with pattern directory
  // POST the meta JSON
  // Verify file written to disk
});

test('POST /api/configs/patterns creates new pattern', () async {
  // POST with pattern ID and meta
  // Verify directory created
  // Verify meta.json written
});

test('DELETE /api/configs/patterns/<id>/playlists/<pid> removes playlist', () async {
  // Setup file
  // DELETE request
  // Verify file removed
});

test('DELETE /api/configs/patterns/<id> removes pattern', () async {
  // Setup directory
  // DELETE request
  // Verify directory removed
});

test('PUT validates playlist against schema before saving', () async {
  // POST invalid JSON
  // Verify 400 response with validation errors
});
```

**Step 2: Run tests to verify they fail**

Run: `dart test packages/sp_server/test/routes/config_routes_test.dart`
Expected: FAIL - new endpoints not implemented

**Step 3: Add handlers to configRouter**

Add to `config_routes.dart`:
- `PUT /api/configs/patterns/<id>/playlists/<pid>` -> `_handleSavePlaylist`
- `PUT /api/configs/patterns/<id>/meta` -> `_handleSavePatternMeta`
- `POST /api/configs/patterns` -> `_handleCreatePattern`
- `DELETE /api/configs/patterns/<id>/playlists/<pid>` -> `_handleDeletePlaylist`
- `DELETE /api/configs/patterns/<id>` -> `_handleDeletePattern`

Each write handler validates JSON against the schema before writing. Returns 400 on validation failure.

**Step 4: Run tests**

Run: `dart test packages/sp_server/test/routes/config_routes_test.dart`
Expected: All PASS

**Step 5: Commit**

```
feat: add write endpoints for local config file operations
```

---

## Task 7: Rewire Server Entry Point

Rewrite `bin/server.dart` to use new services, remove auth, add SSE and file watcher.

**Files:**
- Modify: `packages/sp_server/bin/server.dart`

**Step 1: Rewrite server.dart**

Replace the entire `main()` function:

- Remove: all auth service construction, auth route mounting, submit/draft/key routes
- Add: `LocalConfigRepository(dataDir: cwd)`, `DiskFeedCacheService(cacheDir: '$cwd/.cache/feeds')`, `FileWatcherService(watchDir: cwd)`
- Mount: `/api/events` SSE endpoint
- Keep: health, schema, config, feed routes, CORS, static serving, logging
- Read schema from `$cwd/schema/schema.json`
- Bind to `InternetAddress.loopbackIPv4` (localhost only)

Environment variables:
- `PORT` (default: 8080)
- `WEB_ROOT` (default: 'public')
- `SP_FEED_CACHE_TTL` (default: 3600 seconds)

Auto-detect data dir from CWD: check `patterns/meta.json` exists.

**Step 2: Run server and verify startup**

Run: `dart run packages/sp_server/bin/server.dart` (from a data repo dir)
Expected: "Server listening on http://127.0.0.1:8080"

**Step 3: Run all sp_server tests**

Run: `dart test packages/sp_server`
Expected: All tests pass

**Step 4: Commit**

```
refactor: rewire server entry point for local-first mode
```

---

## Task 8: Strip Auth from sp_react

Remove authentication, draft, and submit code from the React frontend.

**Files to delete:**
- `packages/sp_react/src/routes/login.tsx`
- `packages/sp_react/src/routes/settings.tsx`
- `packages/sp_react/src/stores/auth-store.ts`
- `packages/sp_react/src/stores/__tests__/auth-store.test.ts`
- `packages/sp_react/src/hooks/use-auto-save.ts`
- `packages/sp_react/src/lib/draft-service.ts`
- `packages/sp_react/src/lib/__tests__/draft-service.test.ts`
- `packages/sp_react/src/components/editor/submit-dialog.tsx`
- `packages/sp_react/src/components/editor/draft-restore-dialog.tsx`
- `packages/sp_react/src/components/settings/` (entire directory if exists)

**Files to modify:**
- `packages/sp_react/src/main.tsx` - remove OAuth extraction, auth store sync
- `packages/sp_react/src/routes/index.tsx` - already redirects to /browse, no change needed
- `packages/sp_react/src/routes/browse.tsx` - remove auth guard, settings button
- `packages/sp_react/src/routes/editor.$id.tsx` - remove auth guard
- `packages/sp_react/src/routes/editor.tsx` - remove auth guard (if exists)
- `packages/sp_react/src/api/queries.ts` - remove useSubmitPr, useApiKeys, useGenerateKey, useRevokeKey
- `packages/sp_react/src/schemas/api-schema.ts` - remove ApiKey, SubmitResponse types

**Step 1: Delete files listed above**

**Step 2: Simplify main.tsx**

Remove lines 8, 15-55. Keep: ApiClient creation, QueryClient, Router, render.

New `main.tsx`:
```tsx
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createRouter, RouterProvider } from '@tanstack/react-router';
import { routeTree } from './routeTree.gen';
import { ApiClient } from './api/client.ts';
import { ApiClientProvider } from './api/client-provider.tsx';
import './lib/i18n.ts';
import './index.css';

const API_BASE_URL =
  (import.meta.env.VITE_API_BASE_URL as string) || 'http://localhost:8080';

const apiClient = new ApiClient(API_BASE_URL);
const queryClient = new QueryClient();
const router = createRouter({ routeTree });

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <ApiClientProvider client={apiClient}>
        <RouterProvider router={router} />
      </ApiClientProvider>
    </QueryClientProvider>
  </StrictMode>,
);
```

**Step 3: Remove auth guards from routes**

In `browse.tsx`: remove `beforeLoad` hook, remove `useAuthStore` import, remove settings button.

In `editor.$id.tsx`: remove `beforeLoad` hook, remove `useAuthStore` import.

**Step 4: Simplify queries.ts**

Remove `useSubmitPr`, `useApiKeys`, `useGenerateKey`, `useRevokeKey`. Remove unused type imports.

**Step 5: Run TypeScript check**

Run: `cd packages/sp_react && pnpm tsc --noEmit`
Expected: No errors

**Step 6: Run frontend tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: Tests pass (some may need updating if they reference deleted modules)

**Step 7: Commit**

```
refactor: remove auth, drafts, and submit from sp_react
```

---

## Task 9: Simplify ApiClient

Strip token management from the API client.

**Files:**
- Modify: `packages/sp_react/src/api/client.ts`
- Modify: `packages/sp_react/src/api/__tests__/client.test.ts`

**Step 1: Rewrite client.ts**

```typescript
import i18n from '@/lib/i18n.ts';

export class ApiClient {
  private readonly baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  async get<T>(path: string): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
      }),
    );
  }

  async post<T>(path: string, body?: unknown): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: body !== undefined ? JSON.stringify(body) : undefined,
      }),
    );
  }

  async put<T>(path: string, body?: unknown): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: body !== undefined ? JSON.stringify(body) : undefined,
      }),
    );
  }

  async delete<T>(path: string): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
      }),
    );
  }

  private async send<T>(request: () => Promise<Response>): Promise<T> {
    const response = await request();
    if (!response.ok) {
      const text = await response.text();
      throw new Error(i18n.t('httpError', { status: response.status, text }));
    }
    return response.json() as Promise<T>;
  }
}
```

**Step 2: Update tests**

Remove all tests related to token refresh, auth headers, unauthorized handling.

**Step 3: Run tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: PASS

**Step 4: Commit**

```
refactor: simplify ApiClient by removing token management
```

---

## Task 10: Add Save and Delete Mutations

Add TanStack Query mutations for saving and deleting configs.

**Files:**
- Modify: `packages/sp_react/src/api/queries.ts`
- Modify: `packages/sp_react/src/schemas/api-schema.ts` (if needed)

**Step 1: Add new mutation hooks**

```typescript
// Add to queries.ts:

export function useSavePlaylist() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: {
      patternId: string;
      playlistId: string;
      data: unknown;
    }) =>
      client.put<void>(
        `/api/configs/patterns/${params.patternId}/playlists/${params.playlistId}`,
        params.data,
      ),
    onSuccess: (_data, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['assembledConfig', variables.patternId],
      });
    },
  });
}

export function useSavePatternMeta() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { patternId: string; data: unknown }) =>
      client.put<void>(
        `/api/configs/patterns/${params.patternId}/meta`,
        params.data,
      ),
    onSuccess: (_data, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['assembledConfig', variables.patternId],
      });
      void queryClient.invalidateQueries({ queryKey: ['patterns'] });
    },
  });
}

export function useCreatePattern() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { data: unknown }) =>
      client.post<void>('/api/configs/patterns', params.data),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['patterns'] });
    },
  });
}

export function useDeletePlaylist() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { patternId: string; playlistId: string }) =>
      client.delete<void>(
        `/api/configs/patterns/${params.patternId}/playlists/${params.playlistId}`,
      ),
    onSuccess: (_data, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['assembledConfig', variables.patternId],
      });
    },
  });
}

export function useDeletePattern() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (patternId: string) =>
      client.delete<void>(`/api/configs/patterns/${patternId}`),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['patterns'] });
    },
  });
}
```

**Step 2: Run TypeScript check**

Run: `cd packages/sp_react && pnpm tsc --noEmit`
Expected: No errors

**Step 3: Commit**

```
feat: add save and delete mutation hooks for local config operations
```

---

## Task 11: useFileEvents Hook

SSE hook that listens for file changes and invalidates TanStack Query caches.

**Files:**
- Create: `packages/sp_react/src/hooks/use-file-events.ts`
- Test: `packages/sp_react/src/hooks/__tests__/use-file-events.test.ts`

**Step 1: Write failing tests**

```typescript
// use-file-events.test.ts
import { renderHook } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { useFileEvents } from '../use-file-events.ts';

// Mock EventSource
class MockEventSource {
  onmessage: ((event: MessageEvent) => void) | null = null;
  onerror: (() => void) | null = null;
  close = vi.fn();

  simulateMessage(data: string): void {
    this.onmessage?.(new MessageEvent('message', { data }));
  }
}

describe('useFileEvents', () => {
  let mockEventSource: MockEventSource;

  beforeEach(() => {
    mockEventSource = new MockEventSource();
    vi.stubGlobal('EventSource', vi.fn(() => mockEventSource));
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('creates EventSource on mount', () => {
    renderHook(() => useFileEvents());
    expect(EventSource).toHaveBeenCalledWith('/api/events');
  });

  it('closes EventSource on unmount', () => {
    const { unmount } = renderHook(() => useFileEvents());
    unmount();
    expect(mockEventSource.close).toHaveBeenCalled();
  });
});
```

**Step 2: Run test to verify failure**

Run: `cd packages/sp_react && pnpm test -- --run src/hooks/__tests__/use-file-events.test.ts`
Expected: Module not found

**Step 3: Write implementation**

```typescript
// use-file-events.ts
import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';

interface FileChangeEvent {
  type: 'created' | 'modified' | 'deleted';
  path: string;
}

/**
 * Subscribes to SSE file change events from the server
 * and invalidates relevant TanStack Query caches.
 */
export function useFileEvents(): void {
  const queryClient = useQueryClient();

  useEffect(() => {
    const source = new EventSource('/api/events');

    source.onmessage = (event: MessageEvent) => {
      const change = JSON.parse(event.data as string) as FileChangeEvent;
      invalidateForChange(queryClient, change);
    };

    source.onerror = () => {
      // EventSource auto-reconnects; nothing to do
    };

    return () => source.close();
  }, [queryClient]);
}

function invalidateForChange(
  queryClient: ReturnType<typeof useQueryClient>,
  change: FileChangeEvent,
): void {
  const { path } = change;

  // patterns/meta.json -> invalidate patterns list
  if (path === 'patterns/meta.json') {
    void queryClient.invalidateQueries({ queryKey: ['patterns'] });
    return;
  }

  // patterns/{id}/meta.json -> invalidate that pattern's assembled config
  const metaMatch = path.match(/^patterns\/([^/]+)\/meta\.json$/);
  if (metaMatch) {
    void queryClient.invalidateQueries({
      queryKey: ['assembledConfig', metaMatch[1]],
    });
    return;
  }

  // patterns/{id}/playlists/{pid}.json -> invalidate assembled config
  const playlistMatch = path.match(/^patterns\/([^/]+)\/playlists\/[^/]+\.json$/);
  if (playlistMatch) {
    void queryClient.invalidateQueries({
      queryKey: ['assembledConfig', playlistMatch[1]],
    });
    return;
  }
}

export type { FileChangeEvent };
```

**Step 4: Run tests**

Run: `cd packages/sp_react && pnpm test -- --run src/hooks/__tests__/use-file-events.test.ts`
Expected: PASS

**Step 5: Wire hook into root layout**

Add `useFileEvents()` call in `__root.tsx` so all routes get automatic cache invalidation.

**Step 6: Commit**

```
feat: add useFileEvents hook for SSE-based cache invalidation
```

---

## Task 12: Editor Store Updates

Replace submit-related state with dirty tracking and conflict detection.

**Files:**
- Modify: `packages/sp_react/src/stores/editor-store.ts`

**Step 1: Rewrite editor-store.ts**

```typescript
import { create } from 'zustand';

interface EditorState {
  isJsonMode: boolean;
  feedUrl: string;
  isDirty: boolean;
  isSaving: boolean;
  lastSavedAt: Date | null;
  conflictDetected: boolean;
  conflictPath: string | null;
  toggleJsonMode: () => void;
  setFeedUrl: (url: string) => void;
  setDirty: (dirty: boolean) => void;
  setSaving: (saving: boolean) => void;
  setLastSavedAt: (date: Date) => void;
  setConflict: (path: string) => void;
  clearConflict: () => void;
  reset: () => void;
}

const initialState = {
  isJsonMode: false,
  feedUrl: '',
  isDirty: false,
  isSaving: false,
  lastSavedAt: null as Date | null,
  conflictDetected: false,
  conflictPath: null as string | null,
};

export const useEditorStore = create<EditorState>((set) => ({
  ...initialState,
  toggleJsonMode: () => set((state) => ({ isJsonMode: !state.isJsonMode })),
  setFeedUrl: (url) => set({ feedUrl: url }),
  setDirty: (dirty) => set({ isDirty: dirty }),
  setSaving: (saving) => set({ isSaving: saving }),
  setLastSavedAt: (date) => set({ lastSavedAt: date, isDirty: false }),
  setConflict: (path) => set({ conflictDetected: true, conflictPath: path }),
  clearConflict: () => set({ conflictDetected: false, conflictPath: null }),
  reset: () => set(initialState),
}));
```

**Step 2: Fix any components that reference removed fields**

Search for `lastAutoSavedAt`, `lastSubmittedBranch`, `lastPrUrl`, `configVersion`, `incrementConfigVersion`, `setLastSubmission`, `setLastAutoSavedAt` and remove or replace usage.

**Step 3: Run TypeScript check**

Run: `cd packages/sp_react && pnpm tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```
refactor: update editor store for local-first dirty tracking
```

---

## Task 13: Conflict Dialog Component

Dialog shown when a file changes externally while the user has unsaved edits.

**Files:**
- Create: `packages/sp_react/src/components/editor/conflict-dialog.tsx`

**Step 1: Create component**

```tsx
// conflict-dialog.tsx
import { useTranslation } from 'react-i18next';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog.tsx';

interface ConflictDialogProps {
  open: boolean;
  filePath: string | null;
  onReload: () => void;
  onKeepChanges: () => void;
}

export function ConflictDialog({
  open,
  filePath,
  onReload,
  onKeepChanges,
}: ConflictDialogProps) {
  const { t } = useTranslation('editor');

  return (
    <AlertDialog open={open}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>
            {t('conflictTitle', 'File changed externally')}
          </AlertDialogTitle>
          <AlertDialogDescription>
            {t('conflictDescription', {
              path: filePath,
              defaultValue:
                '{{path}} was modified outside the editor. You have unsaved changes.',
            })}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel onClick={onKeepChanges}>
            {t('keepChanges', 'Keep my changes')}
          </AlertDialogCancel>
          <AlertDialogAction onClick={onReload}>
            {t('reloadFromDisk', 'Reload from disk')}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
```

**Step 2: Commit**

```
feat: add conflict dialog for external file change detection
```

---

## Task 14: Wire Save Flow into Editor

Connect save button, Ctrl+S, dirty tracking, and conflict detection into the editor layout.

**Files:**
- Modify: `packages/sp_react/src/components/editor/editor-layout.tsx`

This is a larger integration task. Key changes:

**Step 1: Add save handler**

- Import `useSavePlaylist`, `useSavePatternMeta` from queries
- Import `useEditorStore` for dirty/saving/conflict state
- Import `ConflictDialog`
- Add `handleSave()` function that calls the save mutation
- Add `Ctrl+S` keyboard shortcut via `useEffect`

**Step 2: Add dirty tracking**

- Compare current form values with `initialConfig` prop
- Set `isDirty` in editor store on form changes
- Show dirty indicator in UI (e.g., dot on save button, "Unsaved changes" text)

**Step 3: Add conflict detection**

- Listen to `useFileEvents` for changes to the current pattern's files
- If dirty and file changed externally, show `ConflictDialog`
- "Reload from disk" -> invalidate query and reset form
- "Keep my changes" -> dismiss dialog, user saves over external change

**Step 4: Remove SubmitDialog and DraftRestoreDialog references**

- Remove all imports and usage of deleted components
- Remove `useAutoSave` hook calls

**Step 5: Run TypeScript check and tests**

Run: `cd packages/sp_react && pnpm tsc --noEmit && pnpm test -- --run`
Expected: PASS

**Step 6: Commit**

```
feat: wire save flow with dirty tracking and conflict detection
```

---

## Task 15: Switch MCP Server to Local Filesystem

Replace HTTP-based tool implementations with local file operations.

**Files:**
- Modify: `mcp_server/lib/src/mcp_server.dart`
- Modify: `mcp_server/lib/src/tools/get_config_tool.dart`
- Modify: `mcp_server/lib/src/tools/search_configs_tool.dart`
- Modify: `mcp_server/lib/src/tools/get_schema_tool.dart`
- Modify: `mcp_server/lib/src/tools/fetch_feed_tool.dart`
- Modify: `mcp_server/lib/src/tools/submit_config_tool.dart`
- Modify: `mcp_server/lib/src/tools/validate_config_tool.dart`
- Modify: `mcp_server/lib/src/tools/preview_config_tool.dart`
- Possibly delete: `mcp_server/lib/src/http_client.dart`
- Modify: `mcp_server/test/` test files

**Step 1: Replace McpHttpClient with local file access**

Change `SpMcpServer` constructor to accept `dataDir` (String) instead of `httpClient`.

**Step 2: Update each tool**

- `search_configs`: read `patterns/meta.json` from disk, filter by keyword
- `get_config`: read and assemble config from disk using `LocalConfigRepository`
- `get_schema`: read `schema/schema.json` from disk
- `fetch_feed`: use `DiskFeedCacheService` with `.cache/feeds/` under data dir
- `validate_config`: read schema from disk, validate
- `preview_config`: use `DiskFeedCacheService` + resolver chain (same logic)
- `submit_config`: write config files to disk using `LocalConfigRepository`

**Step 3: Update resources**

- `smartplaylist://schema`: read from disk
- `smartplaylist://configs`: read from disk

**Step 4: Update MCP entry point**

Auto-detect data dir from CWD, same as web server.

**Step 5: Run MCP tests**

Run: `dart test mcp_server`
Expected: All pass (tests will need updating to use temp directories)

**Step 6: Commit**

```
refactor: switch MCP server to local filesystem operations
```

---

## Task 16: Update Makefile and Environment Config

Update build/run configuration for local-first mode.

**Files:**
- Modify: `Makefile`

**Step 1: Update Makefile**

- Remove `LOCAL_ENV` variables for JWT_SECRET, GITHUB_* credentials
- Update `make server` to just set PORT and WEB_ROOT
- Update `make dev` for new dev workflow
- Remove `make update-schema` (schema now in data repo)
- Add `make build-web` to build sp_react and copy to `public/`

New key targets:
```makefile
server:
	cd $(DATA_DIR) && PORT=8080 WEB_ROOT=$(WEB_ROOT) dart run $(SP_SERVER)/bin/server.dart

dev:
	cd $(DATA_DIR) && PORT=8080 dart run $(SP_SERVER)/bin/server.dart &
	cd $(SP_REACT) && VITE_API_BASE_URL=http://localhost:8080 pnpm dev

build-web:
	cd $(SP_REACT) && pnpm build
	cp -r $(SP_REACT)/dist public/
```

**Step 2: Update .gitignore**

Ensure `.cache/` is listed.

**Step 3: Run all tests**

Run: `dart test packages/sp_shared && dart test packages/sp_server && cd packages/sp_react && pnpm test -- --run && dart test mcp_server`
Expected: All pass

**Step 4: Commit**

```
chore: update Makefile and env config for local-first mode
```

---

## Task 17: Update CLAUDE.md and Memory

Update project documentation to reflect the new architecture.

**Files:**
- Modify: `CLAUDE.md`
- Modify: `.claude/rules/project/architecture.md`

**Step 1: Update CLAUDE.md**

- Update ecosystem overview (3 repos, not 4)
- Update data flow diagram
- Remove GitHub API references
- Document new local-first workflow
- Update schema location (now in data repo)

**Step 2: Update architecture.md**

- Remove auth/GitHub/draft service descriptions
- Add LocalConfigRepository, FileWatcherService, DiskFeedCacheService
- Update API surface (add write endpoints, remove auth endpoints)
- Update sp_react section (no auth, SSE, save flow)

**Step 3: Commit**

```
docs: update project docs for local-first architecture
```

---

## Execution Order and Dependencies

```
Task 1 (DiskFeedCacheService)
  |
  +---> Task 2 (LocalConfigRepository)
  |       |
  |       +---> Task 5 (Strip auth from server) ---> Task 6 (Write endpoints) ---> Task 7 (Rewire server)
  |
  +---> Task 3 (FileWatcherService) ---> Task 4 (SSE route) ---> Task 7
  |
  +---> Task 15 (MCP server)

Task 5 ---> Task 8 (Strip auth from frontend) ---> Task 9 (Simplify ApiClient)
  |
  +---> Task 10 (Save/delete mutations) ---> Task 14 (Wire save flow)
  |
  +---> Task 11 (useFileEvents hook) ---> Task 14
  |
  +---> Task 12 (Editor store) ---> Task 13 (Conflict dialog) ---> Task 14

Task 7, 14, 15 ---> Task 16 (Makefile) ---> Task 17 (Docs)
```

**Parallelizable groups:**
- Tasks 1, 2, 3 can run in parallel (no dependencies)
- Tasks 8, 9, 10, 11, 12, 13 can largely run in parallel after Task 5
- Task 15 (MCP) is independent after Task 1
