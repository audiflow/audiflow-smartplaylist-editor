# Split Config Repository - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate SmartPlaylist configurations from a single bundled JSON file to a dedicated GitHub repository (`reedom/audiflow-smart-playlists`) with multi-file structure, and update all packages (sp_shared, sp_server, sp_web, mcp_server) to work with the new split format.

**Architecture:** Split configs into pattern directories with individual playlist files. Three-level lazy loading (root meta -> pattern meta -> playlist). Server assembles on-demand. Web editor gains two-level browse flow. PRs touch only changed files via Git Trees API. CI bumps versions on merge.

**Tech Stack:** Dart 3.10, shelf (server), Flutter 3.38 (web), `package:http` for fetching, `package:test` for testing. No code generation needed for new packages (hand-written JSON serialization following sp_shared patterns).

---

## Phase 1: sp_shared Models for Split Config Format

New models in sp_shared representing the split config repo structure. These are consumed by sp_server, sp_web, and mcp_server.

### Task 1: Add PatternSummary model

**Files:**
- Create: `packages/sp_shared/lib/src/models/pattern_summary.dart`
- Test: `packages/sp_shared/test/models/pattern_summary_test.dart`
- Modify: `packages/sp_shared/lib/sp_shared.dart` (add export)

**Step 1: Write the failing test**

```dart
// packages/sp_shared/test/models/pattern_summary_test.dart
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('PatternSummary', () {
    test('constructs with required fields', () {
      final summary = PatternSummary(
        id: 'coten_radio',
        version: 1,
        displayName: 'Coten Radio',
        feedUrlHint: 'anchor.fm/s/8c2088c',
        playlistCount: 3,
      );
      expect(summary.id, 'coten_radio');
      expect(summary.version, 1);
      expect(summary.displayName, 'Coten Radio');
      expect(summary.feedUrlHint, 'anchor.fm/s/8c2088c');
      expect(summary.playlistCount, 3);
    });

    test('deserializes from JSON', () {
      final json = {
        'id': 'coten_radio',
        'version': 2,
        'displayName': 'Coten Radio',
        'feedUrlHint': 'anchor.fm/s/8c2088c',
        'playlistCount': 3,
      };
      final summary = PatternSummary.fromJson(json);
      expect(summary.id, 'coten_radio');
      expect(summary.version, 2);
      expect(summary.playlistCount, 3);
    });

    test('serializes to JSON', () {
      final summary = PatternSummary(
        id: 'news',
        version: 1,
        displayName: 'News',
        feedUrlHint: 'example.com',
        playlistCount: 2,
      );
      final json = summary.toJson();
      expect(json['id'], 'news');
      expect(json['version'], 1);
      expect(json['displayName'], 'News');
      expect(json['feedUrlHint'], 'example.com');
      expect(json['playlistCount'], 2);
    });

    test('roundtrips through JSON', () {
      final original = PatternSummary(
        id: 'test',
        version: 5,
        displayName: 'Test Pattern',
        feedUrlHint: 'test.com/feed',
        playlistCount: 1,
      );
      final restored = PatternSummary.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.version, original.version);
      expect(restored.displayName, original.displayName);
      expect(restored.feedUrlHint, original.feedUrlHint);
      expect(restored.playlistCount, original.playlistCount);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_shared/test/models/pattern_summary_test.dart`
Expected: FAIL - cannot find `PatternSummary`

**Step 3: Write minimal implementation**

```dart
// packages/sp_shared/lib/src/models/pattern_summary.dart

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
```

Add export to `packages/sp_shared/lib/sp_shared.dart`:
```dart
export 'src/models/pattern_summary.dart';
```

**Step 4: Run test to verify it passes**

Run: `dart test packages/sp_shared/test/models/pattern_summary_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
jj bookmark create feat/split-config-models
```

---

### Task 2: Add RootMeta model

**Files:**
- Create: `packages/sp_shared/lib/src/models/root_meta.dart`
- Test: `packages/sp_shared/test/models/root_meta_test.dart`
- Modify: `packages/sp_shared/lib/sp_shared.dart` (add export)

**Step 1: Write the failing test**

```dart
// packages/sp_shared/test/models/root_meta_test.dart
import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('RootMeta', () {
    test('deserializes from JSON', () {
      final json = {
        'version': 1,
        'patterns': [
          {
            'id': 'coten_radio',
            'version': 1,
            'displayName': 'Coten Radio',
            'feedUrlHint': 'anchor.fm/s/8c2088c',
            'playlistCount': 3,
          },
        ],
      };
      final meta = RootMeta.fromJson(json);
      expect(meta.version, 1);
      expect(meta.patterns, hasLength(1));
      expect(meta.patterns[0].id, 'coten_radio');
    });

    test('serializes to JSON', () {
      final meta = RootMeta(
        version: 1,
        patterns: [
          PatternSummary(
            id: 'test',
            version: 1,
            displayName: 'Test',
            feedUrlHint: 'test.com',
            playlistCount: 2,
          ),
        ],
      );
      final json = meta.toJson();
      expect(json['version'], 1);
      expect((json['patterns'] as List), hasLength(1));
    });

    test('parses from JSON string', () {
      final jsonString = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'p1',
            'version': 1,
            'displayName': 'P1',
            'feedUrlHint': 'example.com',
            'playlistCount': 1,
          },
        ],
      });
      final meta = RootMeta.parseJson(jsonString);
      expect(meta.patterns, hasLength(1));
    });

    test('throws FormatException for unsupported version', () {
      final jsonString = jsonEncode({'version': 99, 'patterns': []});
      expect(
        () => RootMeta.parseJson(jsonString),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_shared/test/models/root_meta_test.dart`
Expected: FAIL

**Step 3: Write minimal implementation**

```dart
// packages/sp_shared/lib/src/models/root_meta.dart
import 'dart:convert';

import 'pattern_summary.dart';

/// Root meta.json from the split config repository.
///
/// Contains schema version and pattern summaries for discovery.
final class RootMeta {
  const RootMeta({
    required this.version,
    required this.patterns,
  });

  static const _supportedVersion = 1;

  factory RootMeta.fromJson(Map<String, dynamic> json) {
    return RootMeta(
      version: json['version'] as int,
      patterns: (json['patterns'] as List<dynamic>)
          .map((p) => PatternSummary.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Parses a JSON string into a RootMeta.
  ///
  /// Throws [FormatException] if version is unsupported.
  static RootMeta parseJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final version = data['version'] as int?;
    if (version == null || version != _supportedVersion) {
      throw FormatException(
        'Unsupported root meta version: $version '
        '(supported: $_supportedVersion)',
      );
    }
    return RootMeta.fromJson(data);
  }

  final int version;
  final List<PatternSummary> patterns;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'patterns': patterns.map((p) => p.toJson()).toList(),
    };
  }
}
```

Add export to `packages/sp_shared/lib/sp_shared.dart`:
```dart
export 'src/models/root_meta.dart';
```

**Step 4: Run test to verify it passes**

Run: `dart test packages/sp_shared/test/models/root_meta_test.dart`
Expected: PASS

**Step 5: Commit**

---

### Task 3: Add PatternMeta model

**Files:**
- Create: `packages/sp_shared/lib/src/models/pattern_meta.dart`
- Test: `packages/sp_shared/test/models/pattern_meta_test.dart`
- Modify: `packages/sp_shared/lib/sp_shared.dart` (add export)

**Step 1: Write the failing test**

```dart
// packages/sp_shared/test/models/pattern_meta_test.dart
import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('PatternMeta', () {
    test('deserializes from JSON', () {
      final json = {
        'version': 1,
        'id': 'coten_radio',
        'feedUrlPatterns': [
          r'https://anchor\.fm/s/8c2088c/podcast/rss',
        ],
        'yearGroupedEpisodes': true,
        'playlists': ['regular', 'short', 'extras'],
      };
      final meta = PatternMeta.fromJson(json);
      expect(meta.version, 1);
      expect(meta.id, 'coten_radio');
      expect(meta.feedUrlPatterns, hasLength(1));
      expect(meta.yearGroupedEpisodes, isTrue);
      expect(meta.playlists, ['regular', 'short', 'extras']);
    });

    test('defaults yearGroupedEpisodes to false', () {
      final json = {
        'version': 1,
        'id': 'test',
        'feedUrlPatterns': <String>[],
        'playlists': ['main'],
      };
      final meta = PatternMeta.fromJson(json);
      expect(meta.yearGroupedEpisodes, isFalse);
    });

    test('handles optional podcastGuid', () {
      final json = {
        'version': 1,
        'id': 'test',
        'podcastGuid': 'abc-123',
        'feedUrlPatterns': <String>[],
        'playlists': ['main'],
      };
      final meta = PatternMeta.fromJson(json);
      expect(meta.podcastGuid, 'abc-123');
    });

    test('serializes to JSON', () {
      final meta = PatternMeta(
        version: 1,
        id: 'test',
        feedUrlPatterns: ['pattern1'],
        yearGroupedEpisodes: true,
        playlists: ['p1', 'p2'],
      );
      final json = meta.toJson();
      expect(json['version'], 1);
      expect(json['id'], 'test');
      expect(json['yearGroupedEpisodes'], isTrue);
      expect(json['playlists'], ['p1', 'p2']);
    });

    test('parses from JSON string', () {
      final jsonString = jsonEncode({
        'version': 1,
        'id': 'test',
        'feedUrlPatterns': ['pattern'],
        'playlists': ['main'],
      });
      final meta = PatternMeta.parseJson(jsonString);
      expect(meta.id, 'test');
    });

    test('roundtrips through JSON', () {
      final original = PatternMeta(
        version: 2,
        id: 'test',
        podcastGuid: 'guid-1',
        feedUrlPatterns: ['p1', 'p2'],
        yearGroupedEpisodes: true,
        playlists: ['a', 'b'],
      );
      final restored = PatternMeta.fromJson(original.toJson());
      expect(restored.version, original.version);
      expect(restored.id, original.id);
      expect(restored.podcastGuid, original.podcastGuid);
      expect(restored.feedUrlPatterns, original.feedUrlPatterns);
      expect(restored.yearGroupedEpisodes, original.yearGroupedEpisodes);
      expect(restored.playlists, original.playlists);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_shared/test/models/pattern_meta_test.dart`
Expected: FAIL

**Step 3: Write minimal implementation**

```dart
// packages/sp_shared/lib/src/models/pattern_meta.dart
import 'dart:convert';

/// Pattern-level meta.json from a pattern directory.
///
/// Contains feed matching rules and ordered playlist IDs.
final class PatternMeta {
  const PatternMeta({
    required this.version,
    required this.id,
    this.podcastGuid,
    required this.feedUrlPatterns,
    this.yearGroupedEpisodes = false,
    required this.playlists,
  });

  factory PatternMeta.fromJson(Map<String, dynamic> json) {
    return PatternMeta(
      version: json['version'] as int,
      id: json['id'] as String,
      podcastGuid: json['podcastGuid'] as String?,
      feedUrlPatterns: (json['feedUrlPatterns'] as List<dynamic>).cast<String>(),
      yearGroupedEpisodes: (json['yearGroupedEpisodes'] as bool?) ?? false,
      playlists: (json['playlists'] as List<dynamic>).cast<String>(),
    );
  }

  /// Parses a JSON string into a PatternMeta.
  static PatternMeta parseJson(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    return PatternMeta.fromJson(data);
  }

  final int version;
  final String id;
  final String? podcastGuid;
  final List<String> feedUrlPatterns;
  final bool yearGroupedEpisodes;

  /// Ordered list of playlist IDs. Each corresponds to
  /// `playlists/{id}.json` in the pattern directory.
  final List<String> playlists;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'id': id,
      if (podcastGuid != null) 'podcastGuid': podcastGuid,
      'feedUrlPatterns': feedUrlPatterns,
      if (yearGroupedEpisodes) 'yearGroupedEpisodes': yearGroupedEpisodes,
      'playlists': playlists,
    };
  }
}
```

Add export to `packages/sp_shared/lib/sp_shared.dart`:
```dart
export 'src/models/pattern_meta.dart';
```

**Step 4: Run test to verify it passes**

Run: `dart test packages/sp_shared/test/models/pattern_meta_test.dart`
Expected: PASS

**Step 5: Commit**

---

### Task 4: Add ConfigAssembler service

Assembles a full `SmartPlaylistPatternConfig` from split files (PatternMeta + playlist definitions).

**Files:**
- Create: `packages/sp_shared/lib/src/services/config_assembler.dart`
- Test: `packages/sp_shared/test/services/config_assembler_test.dart`
- Modify: `packages/sp_shared/lib/sp_shared.dart` (add export)

**Step 1: Write the failing test**

```dart
// packages/sp_shared/test/services/config_assembler_test.dart
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigAssembler', () {
    test('assembles config from pattern meta and playlists', () {
      final meta = PatternMeta(
        version: 1,
        id: 'coten_radio',
        feedUrlPatterns: [r'https://anchor\.fm/s/8c2088c/podcast/rss'],
        yearGroupedEpisodes: true,
        playlists: ['regular', 'short'],
      );
      final playlists = [
        SmartPlaylistDefinition(
          id: 'regular',
          displayName: 'Regular',
          resolverType: 'rss',
        ),
        SmartPlaylistDefinition(
          id: 'short',
          displayName: 'Short',
          resolverType: 'rss',
        ),
      ];

      final config = ConfigAssembler.assemble(meta, playlists);

      expect(config.id, 'coten_radio');
      expect(config.feedUrlPatterns, hasLength(1));
      expect(config.yearGroupedEpisodes, isTrue);
      expect(config.playlists, hasLength(2));
      expect(config.playlists[0].id, 'regular');
      expect(config.playlists[1].id, 'short');
    });

    test('preserves podcastGuid when present', () {
      final meta = PatternMeta(
        version: 1,
        id: 'test',
        podcastGuid: 'guid-abc',
        feedUrlPatterns: [],
        playlists: ['main'],
      );
      final playlists = [
        SmartPlaylistDefinition(
          id: 'main',
          displayName: 'Main',
          resolverType: 'rss',
        ),
      ];

      final config = ConfigAssembler.assemble(meta, playlists);
      expect(config.podcastGuid, 'guid-abc');
    });

    test('orders playlists by meta playlist list order', () {
      final meta = PatternMeta(
        version: 1,
        id: 'test',
        feedUrlPatterns: [],
        playlists: ['b', 'a'],
      );
      // Provide playlists in opposite order
      final playlists = [
        SmartPlaylistDefinition(
          id: 'a',
          displayName: 'A',
          resolverType: 'rss',
        ),
        SmartPlaylistDefinition(
          id: 'b',
          displayName: 'B',
          resolverType: 'rss',
        ),
      ];

      final config = ConfigAssembler.assemble(meta, playlists);
      expect(config.playlists[0].id, 'b');
      expect(config.playlists[1].id, 'a');
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_shared/test/services/config_assembler_test.dart`
Expected: FAIL

**Step 3: Write minimal implementation**

```dart
// packages/sp_shared/lib/src/services/config_assembler.dart
import '../models/pattern_meta.dart';
import '../models/smart_playlist_definition.dart';
import '../models/smart_playlist_pattern_config.dart';

/// Assembles a [SmartPlaylistPatternConfig] from split config files.
///
/// Combines a [PatternMeta] with its playlist definitions into
/// the unified config that resolvers expect.
final class ConfigAssembler {
  ConfigAssembler._();

  /// Assembles a full config from pattern metadata and playlist
  /// definitions.
  ///
  /// Playlists are ordered according to [meta.playlists]. Any
  /// playlists not listed in meta are appended at the end.
  static SmartPlaylistPatternConfig assemble(
    PatternMeta meta,
    List<SmartPlaylistDefinition> playlists,
  ) {
    final playlistMap = {for (final p in playlists) p.id: p};

    final ordered = <SmartPlaylistDefinition>[];
    for (final id in meta.playlists) {
      final playlist = playlistMap.remove(id);
      if (playlist != null) {
        ordered.add(playlist);
      }
    }
    // Append any remaining playlists not in meta order
    ordered.addAll(playlistMap.values);

    return SmartPlaylistPatternConfig(
      id: meta.id,
      podcastGuid: meta.podcastGuid,
      feedUrlPatterns: meta.feedUrlPatterns,
      yearGroupedEpisodes: meta.yearGroupedEpisodes,
      playlists: ordered,
    );
  }
}
```

Add export to `packages/sp_shared/lib/sp_shared.dart`:
```dart
export 'src/services/config_assembler.dart';
```

**Step 4: Run test to verify it passes**

Run: `dart test packages/sp_shared/test/services/config_assembler_test.dart`
Expected: PASS

**Step 5: Run all sp_shared tests**

Run: `dart test packages/sp_shared`
Expected: ALL PASS (existing tests unaffected)

**Step 6: Commit**

---

## Phase 2: sp_server Package Scaffold

### Task 5: Initialize sp_server package

**Files:**
- Create: `packages/sp_server/pubspec.yaml`
- Create: `packages/sp_server/lib/sp_server.dart`
- Create: `packages/sp_server/bin/server.dart`

**Step 1: Create pubspec.yaml**

```yaml
# packages/sp_server/pubspec.yaml
name: sp_server
description: Backend API server for audiflow SmartPlaylist web editor
publish_to: none
resolution: workspace

environment:
  sdk: ^3.10.0

dependencies:
  shelf: ^1.4.0
  shelf_router: ^1.1.0
  http: ^1.3.0
  sp_shared:
    path: ../sp_shared

dev_dependencies:
  test: ^1.25.0
```

**Step 2: Create library export file**

```dart
// packages/sp_server/lib/sp_server.dart
library;

export 'src/services/config_repository.dart';
export 'src/services/github_app_service.dart';
```

**Step 3: Create server entry point stub**

```dart
// packages/sp_server/bin/server.dart
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final router = Router();

  router.get('/health', (Request request) {
    return Response.ok('ok');
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  // ignore: avoid_print
  print('Server running on port ${server.port}');
}
```

**Step 4: Run `dart pub get` to validate**

Run: `dart pub get`
Expected: Success, resolves all dependencies

**Step 5: Run server health check**

Run: `cd packages/sp_server && dart run bin/server.dart &` then `curl http://localhost:8080/health` then kill the server.
Expected: Response "ok"

**Step 6: Commit**

---

### Task 6: Implement ConfigRepository

Fetches and caches split config files from GitHub raw URLs.

**Files:**
- Create: `packages/sp_server/lib/src/services/config_repository.dart`
- Create: `packages/sp_server/lib/src/services/http_fetcher.dart`
- Test: `packages/sp_server/test/services/config_repository_test.dart`

**Step 1: Write the failing test**

```dart
// packages/sp_server/test/services/config_repository_test.dart
import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';
import 'package:sp_server/sp_server.dart';
import 'package:test/test.dart';

/// In-memory fetcher for tests.
class _FakeFetcher implements HttpFetcher {
  final Map<String, String> responses = {};

  @override
  Future<String> fetch(String url) async {
    final body = responses[url];
    if (body == null) throw Exception('Not found: $url');
    return body;
  }
}

void main() {
  const baseUrl = 'https://raw.githubusercontent.com/reedom/audiflow-smart-playlists/main';

  group('ConfigRepository', () {
    late _FakeFetcher fetcher;
    late ConfigRepository repo;

    setUp(() {
      fetcher = _FakeFetcher();
      repo = ConfigRepository(baseUrl: baseUrl, fetcher: fetcher);
    });

    test('listPatterns returns pattern summaries', () async {
      fetcher.responses['$baseUrl/meta.json'] = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'coten_radio',
            'version': 1,
            'displayName': 'Coten Radio',
            'feedUrlHint': 'anchor.fm/s/8c2088c',
            'playlistCount': 3,
          },
        ],
      });

      final patterns = await repo.listPatterns();
      expect(patterns, hasLength(1));
      expect(patterns[0].id, 'coten_radio');
    });

    test('getPatternMeta returns pattern metadata', () async {
      fetcher.responses['$baseUrl/coten_radio/meta.json'] = jsonEncode({
        'version': 1,
        'id': 'coten_radio',
        'feedUrlPatterns': [r'https://anchor\.fm/s/8c2088c/podcast/rss'],
        'yearGroupedEpisodes': true,
        'playlists': ['regular'],
      });

      final meta = await repo.getPatternMeta('coten_radio');
      expect(meta.id, 'coten_radio');
      expect(meta.yearGroupedEpisodes, isTrue);
    });

    test('getPlaylist returns playlist definition', () async {
      fetcher.responses['$baseUrl/coten_radio/playlists/regular.json'] =
          jsonEncode({
        'id': 'regular',
        'displayName': 'Regular',
        'resolverType': 'rss',
      });

      final playlist = await repo.getPlaylist('coten_radio', 'regular');
      expect(playlist.id, 'regular');
      expect(playlist.resolverType, 'rss');
    });

    test('assembleConfig builds full config', () async {
      fetcher.responses['$baseUrl/coten_radio/meta.json'] = jsonEncode({
        'version': 1,
        'id': 'coten_radio',
        'feedUrlPatterns': [r'https://anchor\.fm/s/8c2088c/podcast/rss'],
        'playlists': ['regular'],
      });
      fetcher.responses['$baseUrl/coten_radio/playlists/regular.json'] =
          jsonEncode({
        'id': 'regular',
        'displayName': 'Regular',
        'resolverType': 'rss',
      });

      final config = await repo.assembleConfig('coten_radio');
      expect(config.id, 'coten_radio');
      expect(config.playlists, hasLength(1));
      expect(config.playlists[0].id, 'regular');
    });

    test('caches root meta on repeated calls', () async {
      var fetchCount = 0;
      final originalFetch = fetcher.responses;
      originalFetch['$baseUrl/meta.json'] = jsonEncode({
        'version': 1,
        'patterns': [],
      });

      // Wrap to count calls
      final countingFetcher = _CountingFetcher(fetcher);
      final cachedRepo = ConfigRepository(
        baseUrl: baseUrl,
        fetcher: countingFetcher,
      );

      await cachedRepo.listPatterns();
      await cachedRepo.listPatterns();
      expect(countingFetcher.callCount, 1);
    });

    test('clearCache forces re-fetch', () async {
      fetcher.responses['$baseUrl/meta.json'] = jsonEncode({
        'version': 1,
        'patterns': [],
      });

      final countingFetcher = _CountingFetcher(fetcher);
      final cachedRepo = ConfigRepository(
        baseUrl: baseUrl,
        fetcher: countingFetcher,
      );

      await cachedRepo.listPatterns();
      cachedRepo.clearCache();
      await cachedRepo.listPatterns();
      expect(countingFetcher.callCount, 2);
    });
  });
}

class _CountingFetcher implements HttpFetcher {
  _CountingFetcher(this._delegate);
  final HttpFetcher _delegate;
  int callCount = 0;

  @override
  Future<String> fetch(String url) {
    callCount++;
    return _delegate.fetch(url);
  }
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_server/test/services/config_repository_test.dart`
Expected: FAIL

**Step 3: Write implementation**

```dart
// packages/sp_server/lib/src/services/http_fetcher.dart

/// Abstraction for HTTP GET requests returning body as String.
///
/// Enables testing with fake implementations.
abstract interface class HttpFetcher {
  Future<String> fetch(String url);
}

/// Production HTTP fetcher using package:http.
final class LiveHttpFetcher implements HttpFetcher {
  @override
  Future<String> fetch(String url) async {
    // Lazy import to avoid pulling http into tests
    final response = await _getUrl(url);
    return response;
  }
}

Future<String> _getUrl(String url) async {
  // ignore: depend_on_referenced_packages
  final uri = Uri.parse(url);
  final client = await HttpClient().getUrl(uri);
  // ... simplified; actual implementation uses package:http
  throw UnimplementedError('Use package:http in production');
}
```

Actually, let me provide a cleaner implementation:

```dart
// packages/sp_server/lib/src/services/http_fetcher.dart
import 'package:http/http.dart' as http;

/// Abstraction for HTTP GET requests returning body as String.
abstract interface class HttpFetcher {
  Future<String> fetch(String url);
}

/// Production fetcher using package:http.
final class LiveHttpFetcher implements HttpFetcher {
  LiveHttpFetcher({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> fetch(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (200 != response.statusCode) {
      throw HttpFetchException(url, response.statusCode);
    }
    return response.body;
  }
}

/// Thrown when an HTTP fetch returns a non-200 status.
final class HttpFetchException implements Exception {
  const HttpFetchException(this.url, this.statusCode);
  final String url;
  final int statusCode;

  @override
  String toString() => 'HttpFetchException: $statusCode for $url';
}
```

```dart
// packages/sp_server/lib/src/services/config_repository.dart
import 'dart:convert';

import 'package:sp_shared/sp_shared.dart';

import 'http_fetcher.dart';

/// Fetches and caches split config files from a GitHub raw URL base.
///
/// Three-level lazy loading:
/// 1. Root meta.json -> pattern summaries
/// 2. {patternId}/meta.json -> pattern metadata
/// 3. {patternId}/playlists/{playlistId}.json -> playlist definition
class ConfigRepository {
  ConfigRepository({
    required String baseUrl,
    required HttpFetcher fetcher,
  })  : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _fetcher = fetcher;

  final String _baseUrl;
  final HttpFetcher _fetcher;
  final Map<String, _CacheEntry> _cache = {};

  static const _rootTtl = Duration(minutes: 5);
  static const _fileTtl = Duration(minutes: 30);

  /// Returns pattern summaries from root meta.json.
  Future<List<PatternSummary>> listPatterns() async {
    final meta = await _fetchRootMeta();
    return meta.patterns;
  }

  /// Returns metadata for a specific pattern.
  Future<PatternMeta> getPatternMeta(String patternId) async {
    final key = '$patternId/meta.json';
    final cached = _getCached(key);
    if (cached != null) return PatternMeta.parseJson(cached);

    final body = await _fetcher.fetch('$_baseUrl/$key');
    _setCache(key, body, _fileTtl);
    return PatternMeta.parseJson(body);
  }

  /// Returns a single playlist definition.
  Future<SmartPlaylistDefinition> getPlaylist(
    String patternId,
    String playlistId,
  ) async {
    final key = '$patternId/playlists/$playlistId.json';
    final cached = _getCached(key);
    if (cached != null) {
      return SmartPlaylistDefinition.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    }

    final body = await _fetcher.fetch('$_baseUrl/$key');
    _setCache(key, body, _fileTtl);
    return SmartPlaylistDefinition.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );
  }

  /// Assembles a full [SmartPlaylistPatternConfig] from split files.
  Future<SmartPlaylistPatternConfig> assembleConfig(String patternId) async {
    final meta = await getPatternMeta(patternId);
    final playlists = await Future.wait(
      meta.playlists.map((id) => getPlaylist(patternId, id)),
    );
    return ConfigAssembler.assemble(meta, playlists);
  }

  /// Clears all cached data.
  void clearCache() => _cache.clear();

  Future<RootMeta> _fetchRootMeta() async {
    const key = 'meta.json';
    final cached = _getCached(key);
    if (cached != null) return RootMeta.parseJson(cached);

    final body = await _fetcher.fetch('$_baseUrl/$key');
    _setCache(key, body, _rootTtl);
    return RootMeta.parseJson(body);
  }

  String? _getCached(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }
    return entry.body;
  }

  void _setCache(String key, String body, Duration ttl) {
    _cache[key] = _CacheEntry(body, DateTime.now().add(ttl));
  }
}

class _CacheEntry {
  const _CacheEntry(this.body, this.expiresAt);
  final String body;
  final DateTime expiresAt;
}
```

Update library export `packages/sp_server/lib/sp_server.dart`:
```dart
library;

export 'src/services/config_repository.dart';
export 'src/services/http_fetcher.dart';
```

**Step 4: Run test to verify it passes**

Run: `dart test packages/sp_server/test/services/config_repository_test.dart`
Expected: PASS

**Step 5: Commit**

---

### Task 7: Implement GitHubAppService with Git Trees API

Multi-file atomic commits for PR submissions.

**Files:**
- Create: `packages/sp_server/lib/src/services/github_app_service.dart`
- Test: `packages/sp_server/test/services/github_app_service_test.dart`

**Step 1: Write the failing test**

```dart
// packages/sp_server/test/services/github_app_service_test.dart
import 'dart:convert';

import 'package:sp_server/sp_server.dart';
import 'package:test/test.dart';

void main() {
  group('GitHubAppService', () {
    group('buildFileChanges', () {
      test('edit existing playlist produces single file', () {
        final changes = GitHubAppService.buildFileChanges(
          patternId: 'coten_radio',
          playlistId: 'regular',
          playlist: {'id': 'regular', 'displayName': 'Regular', 'resolverType': 'rss'},
        );
        expect(changes, hasLength(1));
        expect(changes[0].path, 'coten_radio/playlists/regular.json');
      });

      test('add new playlist produces two files', () {
        final changes = GitHubAppService.buildFileChanges(
          patternId: 'coten_radio',
          playlistId: 'new_one',
          playlist: {'id': 'new_one', 'displayName': 'New', 'resolverType': 'rss'},
          patternMeta: {
            'version': 1,
            'id': 'coten_radio',
            'feedUrlPatterns': [],
            'playlists': ['regular', 'new_one'],
          },
        );
        expect(changes, hasLength(2));
        final paths = changes.map((c) => c.path).toSet();
        expect(paths, contains('coten_radio/playlists/new_one.json'));
        expect(paths, contains('coten_radio/meta.json'));
      });

      test('create new pattern produces 3+ files', () {
        final changes = GitHubAppService.buildFileChanges(
          patternId: 'new_pattern',
          playlistId: 'main',
          playlist: {'id': 'main', 'displayName': 'Main', 'resolverType': 'rss'},
          patternMeta: {
            'version': 1,
            'id': 'new_pattern',
            'feedUrlPatterns': [],
            'playlists': ['main'],
          },
          isNewPattern: true,
          rootMeta: {
            'version': 1,
            'patterns': [
              {
                'id': 'new_pattern',
                'version': 1,
                'displayName': 'New Pattern',
                'feedUrlHint': 'example.com',
                'playlistCount': 1,
              },
            ],
          },
        );
        expect(3 <= changes.length, isTrue);
        final paths = changes.map((c) => c.path).toSet();
        expect(paths, contains('new_pattern/playlists/main.json'));
        expect(paths, contains('new_pattern/meta.json'));
        expect(paths, contains('meta.json'));
      });
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_server/test/services/github_app_service_test.dart`
Expected: FAIL

**Step 3: Write implementation**

```dart
// packages/sp_server/lib/src/services/github_app_service.dart
import 'dart:convert';

/// A file change to include in a Git Trees API commit.
final class FileChange {
  const FileChange({required this.path, required this.content});
  final String path;
  final String content;
}

/// Service for creating multi-file commits via GitHub Git Trees API.
///
/// Produces atomic commits regardless of file count.
class GitHubAppService {
  GitHubAppService({
    required String owner,
    required String repo,
    required String token,
  })  : _owner = owner,
        _repo = repo,
        _token = token;

  final String _owner;
  final String _repo;
  final String _token;

  /// Determines which files need to change for a submit operation.
  ///
  /// Scenarios:
  /// - Edit existing playlist: 1 file (playlist JSON)
  /// - Add new playlist: 2 files (playlist JSON + pattern meta)
  /// - Create new pattern: 3+ files (playlist(s) + pattern meta + root meta)
  static List<FileChange> buildFileChanges({
    required String patternId,
    String? playlistId,
    Map<String, dynamic>? playlist,
    Map<String, dynamic>? patternMeta,
    bool isNewPattern = false,
    Map<String, dynamic>? rootMeta,
  }) {
    const encoder = JsonEncoder.withIndent('  ');
    final changes = <FileChange>[];

    // Playlist file
    if (playlist != null && playlistId != null) {
      changes.add(FileChange(
        path: '$patternId/playlists/$playlistId.json',
        content: encoder.convert(playlist),
      ));
    }

    // Pattern meta
    if (patternMeta != null) {
      changes.add(FileChange(
        path: '$patternId/meta.json',
        content: encoder.convert(patternMeta),
      ));
    }

    // Root meta (new pattern only)
    if (isNewPattern && rootMeta != null) {
      changes.add(FileChange(
        path: 'meta.json',
        content: encoder.convert(rootMeta),
      ));
    }

    return changes;
  }

  // TODO(Task 11+): Implement createPullRequest using Git Trees API
  // 1. Get base tree SHA from default branch
  // 2. Create blobs for each changed file
  // 3. Create a new tree referencing the blobs
  // 4. Create a commit pointing to the new tree
  // 5. Create branch and PR
}
```

**Step 4: Run test to verify it passes**

Run: `dart test packages/sp_server/test/services/github_app_service_test.dart`
Expected: PASS

**Step 5: Commit**

---

### Task 8: Add config API routes

**Files:**
- Create: `packages/sp_server/lib/src/routes/config_routes.dart`
- Test: `packages/sp_server/test/routes/config_routes_test.dart`
- Modify: `packages/sp_server/bin/server.dart` (wire routes)
- Modify: `packages/sp_server/lib/sp_server.dart` (add export)

**Step 1: Write the failing test**

```dart
// packages/sp_server/test/routes/config_routes_test.dart
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:sp_server/sp_server.dart';
import 'package:test/test.dart';

class _FakeFetcher implements HttpFetcher {
  final Map<String, String> responses = {};

  @override
  Future<String> fetch(String url) async {
    final body = responses[url];
    if (body == null) throw Exception('Not found: $url');
    return body;
  }
}

void main() {
  const baseUrl = 'https://raw.example.com/repo/main';

  group('ConfigRoutes', () {
    late _FakeFetcher fetcher;
    late ConfigRepository repo;
    late Handler handler;

    setUp(() {
      fetcher = _FakeFetcher();
      repo = ConfigRepository(baseUrl: baseUrl, fetcher: fetcher);
      handler = configRoutes(repo).call;
    });

    test('GET /api/configs/patterns returns pattern list', () async {
      fetcher.responses['$baseUrl/meta.json'] = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'version': 1,
            'displayName': 'Test',
            'feedUrlHint': 'test.com',
            'playlistCount': 1,
          },
        ],
      });

      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/configs/patterns')),
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as List;
      expect(body, hasLength(1));
      expect(body[0]['id'], 'test');
    });

    test('GET /api/configs/patterns/:id returns pattern detail', () async {
      fetcher.responses['$baseUrl/test/meta.json'] = jsonEncode({
        'version': 1,
        'id': 'test',
        'feedUrlPatterns': ['pattern1'],
        'playlists': ['main'],
      });

      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/configs/patterns/test')),
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['id'], 'test');
    });

    test('GET /api/configs/patterns/:id/playlists/:pid returns playlist', () async {
      fetcher.responses['$baseUrl/test/playlists/main.json'] = jsonEncode({
        'id': 'main',
        'displayName': 'Main',
        'resolverType': 'rss',
      });

      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/configs/patterns/test/playlists/main')),
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['id'], 'main');
    });

    test('GET /api/configs/patterns/:id/assembled returns full config', () async {
      fetcher.responses['$baseUrl/test/meta.json'] = jsonEncode({
        'version': 1,
        'id': 'test',
        'feedUrlPatterns': [],
        'playlists': ['main'],
      });
      fetcher.responses['$baseUrl/test/playlists/main.json'] = jsonEncode({
        'id': 'main',
        'displayName': 'Main',
        'resolverType': 'rss',
      });

      final response = await handler(
        Request('GET', Uri.parse('http://localhost/api/configs/patterns/test/assembled')),
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['id'], 'test');
      expect((body['playlists'] as List), hasLength(1));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_server/test/routes/config_routes_test.dart`
Expected: FAIL

**Step 3: Write implementation**

```dart
// packages/sp_server/lib/src/routes/config_routes.dart
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../services/config_repository.dart';

/// Creates the config API router.
///
/// Routes:
/// - GET /api/configs/patterns
/// - GET /api/configs/patterns/:patternId
/// - GET /api/configs/patterns/:patternId/playlists/:playlistId
/// - GET /api/configs/patterns/:patternId/assembled
Router configRoutes(ConfigRepository repo) {
  final router = Router();

  router.get('/api/configs/patterns', (Request request) async {
    final patterns = await repo.listPatterns();
    final body = jsonEncode(patterns.map((p) => p.toJson()).toList());
    return Response.ok(body, headers: _jsonHeaders);
  });

  router.get('/api/configs/patterns/<patternId>',
      (Request request, String patternId) async {
    final meta = await repo.getPatternMeta(patternId);
    return Response.ok(jsonEncode(meta.toJson()), headers: _jsonHeaders);
  });

  router.get('/api/configs/patterns/<patternId>/playlists/<playlistId>',
      (Request request, String patternId, String playlistId) async {
    final playlist = await repo.getPlaylist(patternId, playlistId);
    return Response.ok(jsonEncode(playlist.toJson()), headers: _jsonHeaders);
  });

  router.get('/api/configs/patterns/<patternId>/assembled',
      (Request request, String patternId) async {
    final config = await repo.assembleConfig(patternId);
    return Response.ok(jsonEncode(config.toJson()), headers: _jsonHeaders);
  });

  return router;
}

const _jsonHeaders = {'content-type': 'application/json'};
```

Update exports in `packages/sp_server/lib/sp_server.dart`:
```dart
library;

export 'src/routes/config_routes.dart';
export 'src/services/config_repository.dart';
export 'src/services/github_app_service.dart';
export 'src/services/http_fetcher.dart';
```

Wire routes in `packages/sp_server/bin/server.dart`:
```dart
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sp_server/sp_server.dart';

void main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final configBaseUrl = Platform.environment['CONFIG_REPO_URL'] ??
      'https://raw.githubusercontent.com/reedom/audiflow-smart-playlists/main';

  final fetcher = LiveHttpFetcher();
  final configRepo = ConfigRepository(baseUrl: configBaseUrl, fetcher: fetcher);

  final app = Router();
  app.get('/health', (Request request) => Response.ok('ok'));
  app.mount('/', configRoutes(configRepo).call);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(app.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  // ignore: avoid_print
  print('Server running on port ${server.port}');
}
```

**Step 4: Run test to verify it passes**

Run: `dart test packages/sp_server/test/routes/config_routes_test.dart`
Expected: PASS

**Step 5: Run all sp_server tests**

Run: `dart test packages/sp_server`
Expected: ALL PASS

**Step 6: Commit**

---

### Task 9: Add submit routes

**Files:**
- Create: `packages/sp_server/lib/src/routes/submit_routes.dart`
- Test: `packages/sp_server/test/routes/submit_routes_test.dart`
- Modify: `packages/sp_server/lib/sp_server.dart` (add export)
- Modify: `packages/sp_server/bin/server.dart` (wire routes)

**Step 1: Write the failing test**

```dart
// packages/sp_server/test/routes/submit_routes_test.dart
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:sp_server/sp_server.dart';
import 'package:test/test.dart';

void main() {
  group('SubmitRoutes', () {
    group('parseSubmitRequest', () {
      test('parses edit playlist request', () {
        final body = {
          'patternId': 'coten_radio',
          'playlistId': 'regular',
          'playlist': {
            'id': 'regular',
            'displayName': 'Regular',
            'resolverType': 'rss',
          },
          'description': 'Update regex filter',
        };

        final request = SubmitRequest.fromJson(body);
        expect(request.patternId, 'coten_radio');
        expect(request.playlistId, 'regular');
        expect(request.isNewPattern, isFalse);
        expect(request.playlist, isNotNull);
        expect(request.patternMeta, isNull);
      });

      test('parses create pattern request', () {
        final body = {
          'patternId': 'new_pattern',
          'playlistId': 'main',
          'playlist': {
            'id': 'main',
            'displayName': 'Main',
            'resolverType': 'rss',
          },
          'patternMeta': {
            'version': 1,
            'id': 'new_pattern',
            'feedUrlPatterns': [],
            'playlists': ['main'],
          },
          'isNewPattern': true,
          'description': 'Add new pattern',
        };

        final request = SubmitRequest.fromJson(body);
        expect(request.isNewPattern, isTrue);
        expect(request.patternMeta, isNotNull);
      });

      test('requires patternId', () {
        final body = {
          'playlistId': 'regular',
          'playlist': {'id': 'regular', 'displayName': 'R', 'resolverType': 'rss'},
        };
        expect(() => SubmitRequest.fromJson(body), throwsA(anything));
      });
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_server/test/routes/submit_routes_test.dart`
Expected: FAIL

**Step 3: Write implementation**

```dart
// packages/sp_server/lib/src/routes/submit_routes.dart
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../services/github_app_service.dart';

/// Parsed submit request body.
final class SubmitRequest {
  const SubmitRequest({
    required this.patternId,
    this.playlistId,
    this.playlist,
    this.patternMeta,
    this.isNewPattern = false,
    this.description = '',
  });

  factory SubmitRequest.fromJson(Map<String, dynamic> json) {
    final patternId = json['patternId'] as String?;
    if (patternId == null) {
      throw ArgumentError('patternId is required');
    }
    return SubmitRequest(
      patternId: patternId,
      playlistId: json['playlistId'] as String?,
      playlist: json['playlist'] as Map<String, dynamic>?,
      patternMeta: json['patternMeta'] as Map<String, dynamic>?,
      isNewPattern: (json['isNewPattern'] as bool?) ?? false,
      description: (json['description'] as String?) ?? '',
    );
  }

  final String patternId;
  final String? playlistId;
  final Map<String, dynamic>? playlist;
  final Map<String, dynamic>? patternMeta;
  final bool isNewPattern;
  final String description;
}

/// Creates the submit API router.
///
/// Routes:
/// - POST /api/submit
Router submitRoutes(GitHubAppService githubService) {
  final router = Router();

  router.post('/api/submit', (Request request) async {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final submitReq = SubmitRequest.fromJson(body);

    final changes = GitHubAppService.buildFileChanges(
      patternId: submitReq.patternId,
      playlistId: submitReq.playlistId,
      playlist: submitReq.playlist,
      patternMeta: submitReq.patternMeta,
      isNewPattern: submitReq.isNewPattern,
    );

    // TODO: Call githubService.createPullRequest(changes, submitReq.description)
    // For now, return the file list that would be committed
    final filePaths = changes.map((c) => c.path).toList();
    return Response.ok(
      jsonEncode({'files': filePaths, 'status': 'pending_implementation'}),
      headers: {'content-type': 'application/json'},
    );
  });

  return router;
}
```

Add export to `packages/sp_server/lib/sp_server.dart`:
```dart
export 'src/routes/submit_routes.dart';
```

**Step 4: Run test to verify it passes**

Run: `dart test packages/sp_server/test/routes/submit_routes_test.dart`
Expected: PASS

**Step 5: Run all sp_server tests**

Run: `dart test packages/sp_server`
Expected: ALL PASS

**Step 6: Commit**

---

## Phase 3: Migration Script

### Task 10: Create migration script

One-time script that splits the existing single JSON into the new multi-file format.

**Files:**
- Create: `scripts/migrate.dart`
- Test: `scripts/migrate_test.dart`

**Step 1: Write the failing test**

```dart
// scripts/migrate_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

// Import the migrate script's logic
import 'migrate.dart';

void main() {
  group('Migration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('migrate_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('splits single config into multi-file structure', () {
      final input = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'test_pattern',
            'feedUrlPatterns': [r'https://example\.com/feed'],
            'yearGroupedEpisodes': true,
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main Playlist',
                'resolverType': 'rss',
              },
              {
                'id': 'bonus',
                'displayName': 'Bonus',
                'resolverType': 'category',
              },
            ],
          },
        ],
      });

      migrate(input, tempDir.path);

      // Root meta.json
      final rootMeta = jsonDecode(
        File('${tempDir.path}/meta.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(rootMeta['version'], 1);
      expect((rootMeta['patterns'] as List), hasLength(1));
      expect(rootMeta['patterns'][0]['id'], 'test_pattern');
      expect(rootMeta['patterns'][0]['playlistCount'], 2);

      // Pattern meta.json
      final patternMeta = jsonDecode(
        File('${tempDir.path}/test_pattern/meta.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(patternMeta['id'], 'test_pattern');
      expect(patternMeta['yearGroupedEpisodes'], isTrue);
      expect(patternMeta['playlists'], ['main', 'bonus']);

      // Playlist files
      final mainPlaylist = jsonDecode(
        File('${tempDir.path}/test_pattern/playlists/main.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(mainPlaylist['id'], 'main');
      expect(mainPlaylist['resolverType'], 'rss');

      final bonusPlaylist = jsonDecode(
        File('${tempDir.path}/test_pattern/playlists/bonus.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(bonusPlaylist['id'], 'bonus');
    });

    test('derives displayName from pattern ID', () {
      final input = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'coten_radio',
            'feedUrlPatterns': [r'https://example\.com/feed'],
            'playlists': [
              {'id': 'p1', 'displayName': 'P1', 'resolverType': 'rss'},
            ],
          },
        ],
      });

      migrate(input, tempDir.path);

      final rootMeta = jsonDecode(
        File('${tempDir.path}/meta.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(rootMeta['patterns'][0]['displayName'], 'Coten Radio');
    });

    test('strips regex escapes for feedUrlHint', () {
      final input = jsonEncode({
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'feedUrlPatterns': [r'https://anchor\.fm/s/8c2088c/podcast/rss'],
            'playlists': [
              {'id': 'p1', 'displayName': 'P1', 'resolverType': 'rss'},
            ],
          },
        ],
      });

      migrate(input, tempDir.path);

      final rootMeta = jsonDecode(
        File('${tempDir.path}/meta.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      // Should strip backslash escapes
      expect(
        (rootMeta['patterns'][0]['feedUrlHint'] as String).contains(r'\.'),
        isFalse,
      );
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test scripts/migrate_test.dart`
Expected: FAIL

**Step 3: Write implementation**

```dart
// scripts/migrate.dart
import 'dart:convert';
import 'dart:io';

const _encoder = JsonEncoder.withIndent('  ');

/// Splits a single SmartPlaylist JSON file into multi-file structure.
///
/// [jsonInput] - the raw JSON string of the single-file config
/// [outputDir] - directory to write the split files into
void migrate(String jsonInput, String outputDir) {
  final data = jsonDecode(jsonInput) as Map<String, dynamic>;
  final patterns = data['patterns'] as List<dynamic>;

  final patternSummaries = <Map<String, dynamic>>[];

  for (final raw in patterns) {
    final pattern = raw as Map<String, dynamic>;
    final patternId = pattern['id'] as String;
    final playlists = pattern['playlists'] as List<dynamic>;
    final feedUrlPatterns =
        (pattern['feedUrlPatterns'] as List<dynamic>?)?.cast<String>() ?? [];
    final yearGrouped = (pattern['yearGroupedEpisodes'] as bool?) ?? false;
    final podcastGuid = pattern['podcastGuid'] as String?;

    // Create directories
    final playlistDir = Directory('$outputDir/$patternId/playlists');
    playlistDir.createSync(recursive: true);

    // Write each playlist file
    final playlistIds = <String>[];
    for (final p in playlists) {
      final playlist = p as Map<String, dynamic>;
      final playlistId = playlist['id'] as String;
      playlistIds.add(playlistId);

      final file = File('$outputDir/$patternId/playlists/$playlistId.json');
      file.writeAsStringSync(_encoder.convert(playlist));
    }

    // Write pattern meta.json
    final patternMeta = <String, dynamic>{
      'version': 1,
      'id': patternId,
      if (podcastGuid != null) 'podcastGuid': podcastGuid,
      'feedUrlPatterns': feedUrlPatterns,
      if (yearGrouped) 'yearGroupedEpisodes': yearGrouped,
      'playlists': playlistIds,
    };
    File('$outputDir/$patternId/meta.json')
        .writeAsStringSync(_encoder.convert(patternMeta));

    // Build summary for root meta
    final displayName = _deriveDisplayName(patternId);
    final feedUrlHint = feedUrlPatterns.isNotEmpty
        ? _stripRegexEscapes(feedUrlPatterns[0])
        : '';

    patternSummaries.add({
      'id': patternId,
      'version': 1,
      'displayName': displayName,
      'feedUrlHint': feedUrlHint,
      'playlistCount': playlistIds.length,
    });
  }

  // Write root meta.json
  final rootMeta = {
    'version': 1,
    'patterns': patternSummaries,
  };
  File('$outputDir/meta.json')
      .writeAsStringSync(_encoder.convert(rootMeta));

  // Print summary
  // ignore: avoid_print
  print('Migration complete:');
  // ignore: avoid_print
  print('  Patterns: ${patternSummaries.length}');
  for (final summary in patternSummaries) {
    // ignore: avoid_print
    print('  - ${summary['id']}: ${summary['playlistCount']} playlists');
  }
}

String _deriveDisplayName(String id) {
  return id
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _stripRegexEscapes(String pattern) {
  return pattern.replaceAll(r'\', '');
}

void main(List<String> args) {
  if (2 != args.length) {
    // ignore: avoid_print
    print('Usage: dart run scripts/migrate.dart <input.json> <output_dir>');
    exit(1);
  }
  final input = File(args[0]).readAsStringSync();
  migrate(input, args[1]);
}
```

**Step 4: Run test to verify it passes**

Run: `dart test scripts/migrate_test.dart`
Expected: PASS

**Step 5: Commit**

---

## Phase 4: CI - Version Bump GitHub Action

### Task 11: Create version bump workflow

**Files:**
- Create: `ci/bump-versions.yml` (template for the config repo)

This task is documentation/template only - the actual file lives in the config repo.

**Step 1: Write the workflow template**

```yaml
# ci/bump-versions.yml
# Deploy to: reedom/audiflow-smart-playlists/.github/workflows/bump-versions.yml
name: Bump Versions

on:
  push:
    branches: [main]

jobs:
  bump:
    # Skip CI bot commits to prevent infinite loops
    if: "!contains(github.event.head_commit.message, '[skip ci]')"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Detect changed patterns
        id: detect
        run: |
          CHANGED=$(git diff HEAD~1 --name-only | grep -oP '^[^/]+(?=/)' | sort -u | grep -v '^\.' || true)
          echo "patterns=$CHANGED" >> $GITHUB_OUTPUT
          if [ -z "$CHANGED" ]; then
            echo "skip=true" >> $GITHUB_OUTPUT
          else
            echo "skip=false" >> $GITHUB_OUTPUT
          fi

      - name: Bump versions
        if: steps.detect.outputs.skip == 'false'
        run: |
          for PATTERN in ${{ steps.detect.outputs.patterns }}; do
            if [ -f "$PATTERN/meta.json" ]; then
              # Bump pattern version
              jq '.version += 1' "$PATTERN/meta.json" > tmp.json && mv tmp.json "$PATTERN/meta.json"

              # Bump in root meta.json
              NEW_VERSION=$(jq '.version' "$PATTERN/meta.json")
              PLAYLIST_COUNT=$(jq '.playlists | length' "$PATTERN/meta.json")
              jq --arg id "$PATTERN" --argjson ver "$NEW_VERSION" --argjson count "$PLAYLIST_COUNT" \
                '(.patterns[] | select(.id == $id)) |= (.version = $ver | .playlistCount = $count)' \
                meta.json > tmp.json && mv tmp.json meta.json
            fi
          done

      - name: Commit and push
        if: steps.detect.outputs.skip == 'false'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add -A
          git diff --cached --quiet || git commit -m "chore: bump versions [skip ci]"
          git push
```

**Step 2: Commit**

---

## Phase 5: Quality Gates

### Task 12: Run full analysis and test suite

**Step 1: Format**

Run: `dart format .`

**Step 2: Analyze**

Run: `dart analyze`
Expected: No issues

**Step 3: Run all tests**

Run: `dart test packages/sp_shared && dart test packages/sp_server`
Expected: ALL PASS

**Step 4: Final commit and bookmark**

```bash
jj bookmark create feat/split-config-repo
```

---

## Summary of Deliverables

| Phase | Package | What |
|-------|---------|------|
| 1 | sp_shared | PatternSummary, RootMeta, PatternMeta models + ConfigAssembler |
| 2 | sp_server | Package scaffold, ConfigRepository, GitHubAppService, config routes, submit routes |
| 3 | scripts | Migration script to split existing JSON |
| 4 | ci | Version bump GitHub Action template |
| 5 | all | Format, analyze, test quality gates |

## Future Tasks (Not in This Plan)

- sp_web: Flutter web UI with browse flow (pattern list, playlist list, editor)
- mcp_server: MCP protocol server with updated tools
- GitHubAppService: Full Git Trees API implementation for PR creation
- OAuth flow for GitHub authentication
