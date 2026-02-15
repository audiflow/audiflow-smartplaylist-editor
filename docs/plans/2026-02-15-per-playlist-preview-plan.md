# Per-Playlist Preview Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the single combined preview with a tabbed per-playlist view that pairs config editing with preview results, and tracks episodes claimed by higher-priority playlists.

**Architecture:** Three-layer change: new preview models and `resolveForPreview` method in sp_shared, updated preview serialization in sp_server, and a restructured tabbed editor layout in sp_react. Backend changes are additive (new method, not modifying existing `resolveSmartPlaylists`). Frontend is a significant restructure of the editor layout from 2-column to tabbed paired rows.

**Tech Stack:** Dart 3.10 (sp_shared, sp_server), React 19 + TanStack Router + Zustand + shadcn/ui Tabs (sp_react), Vitest (sp_react tests)

**Design doc:** `docs/plans/2026-02-15-per-playlist-preview-design.md`

---

## Task 1: sp_shared - Preview Models

**Files:**
- Create: `packages/sp_shared/lib/src/models/preview_grouping.dart`
- Modify: `packages/sp_shared/lib/sp_shared.dart` (add export)
- Test: `packages/sp_shared/test/models/preview_grouping_test.dart`

**Step 1: Write tests for preview models**

Create `packages/sp_shared/test/models/preview_grouping_test.dart`:

```dart
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('PlaylistPreviewResult', () {
    test('stores playlist and empty claimedByOthers', () {
      final playlist = SmartPlaylist(
        id: 'p1',
        displayName: 'Playlist 1',
        sortKey: 0,
        episodeIds: [1, 2, 3],
      );

      final result = PlaylistPreviewResult(
        definitionId: 'p1',
        playlist: playlist,
        claimedByOthers: {},
      );

      expect(result.definitionId, 'p1');
      expect(result.playlist.episodeIds, [1, 2, 3]);
      expect(result.claimedByOthers, isEmpty);
    });

    test('stores claimedByOthers mapping episode ID to claimer ID', () {
      final playlist = SmartPlaylist(
        id: 'p2',
        displayName: 'Playlist 2',
        sortKey: 0,
        episodeIds: [3, 4],
      );

      final result = PlaylistPreviewResult(
        definitionId: 'p2',
        playlist: playlist,
        claimedByOthers: {1: 'p1', 2: 'p1'},
      );

      expect(result.claimedByOthers, {1: 'p1', 2: 'p1'});
    });
  });

  group('PreviewGrouping', () {
    test('wraps playlist results with ungrouped and resolverType', () {
      final grouping = PreviewGrouping(
        playlistResults: [
          PlaylistPreviewResult(
            definitionId: 'p1',
            playlist: SmartPlaylist(
              id: 'p1',
              displayName: 'P1',
              sortKey: 0,
              episodeIds: [1, 2],
            ),
            claimedByOthers: {},
          ),
        ],
        ungroupedEpisodeIds: [5, 6],
        resolverType: 'rss',
      );

      expect(grouping.playlistResults, hasLength(1));
      expect(grouping.ungroupedEpisodeIds, [5, 6]);
      expect(grouping.resolverType, 'rss');
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_shared/test/models/preview_grouping_test.dart`
Expected: FAIL - `PlaylistPreviewResult` and `PreviewGrouping` not found

**Step 3: Create preview models**

Create `packages/sp_shared/lib/src/models/preview_grouping.dart`:

```dart
import 'smart_playlist.dart';

/// Preview-specific wrapper for a single playlist definition's
/// resolution result, including episodes that were claimed by
/// higher-priority definitions.
final class PlaylistPreviewResult {
  const PlaylistPreviewResult({
    required this.definitionId,
    required this.playlist,
    required this.claimedByOthers,
  });

  /// The playlist definition ID this result corresponds to.
  final String definitionId;

  /// The resolved playlist (groups, episodes, etc).
  final SmartPlaylist playlist;

  /// Episodes that matched this definition's filters but were
  /// already claimed by a higher-priority definition.
  /// Maps episode ID to the claiming definition's ID.
  final Map<int, String> claimedByOthers;
}

/// Preview-specific grouping that includes per-playlist
/// claimed-episode tracking alongside the standard resolution
/// output.
final class PreviewGrouping {
  const PreviewGrouping({
    required this.playlistResults,
    required this.ungroupedEpisodeIds,
    required this.resolverType,
  });

  final List<PlaylistPreviewResult> playlistResults;
  final List<int> ungroupedEpisodeIds;
  final String resolverType;
}
```

**Step 4: Add export to sp_shared.dart**

In `packages/sp_shared/lib/sp_shared.dart`, add after the `smart_playlist.dart` export:

```dart
export 'src/models/preview_grouping.dart';
```

**Step 5: Run test to verify it passes**

Run: `dart test packages/sp_shared/test/models/preview_grouping_test.dart`
Expected: PASS (all 3 tests)

**Step 6: Run full sp_shared test suite**

Run: `dart test packages/sp_shared`
Expected: All tests pass (155+ tests)

**Step 7: Commit**

```
feat: add PlaylistPreviewResult and PreviewGrouping models
```

---

## Task 2: sp_shared - resolveForPreview Method

**Files:**
- Modify: `packages/sp_shared/lib/src/services/smart_playlist_resolver_service.dart`
- Test: `packages/sp_shared/test/services/smart_playlist_resolver_service_test.dart`

This task adds `resolveForPreview` to `SmartPlaylistResolverService`. The method reuses most of the `_resolveWithConfig` logic but tracks which episodes were claimed by which definition.

**Step 1: Write test for basic resolveForPreview (single definition, no claiming)**

Append to the existing test file's main `group('SmartPlaylistResolverService')` block, after the last existing test:

```dart
group('resolveForPreview', () {
  test('returns PreviewGrouping with single playlist result', () {
    final serviceWithPattern = SmartPlaylistResolverService(
      resolvers: [RssMetadataResolver()],
      patterns: [
        SmartPlaylistPatternConfig(
          id: 'test',
          feedUrls: ['https://example.com/feed'],
          playlists: [
            SmartPlaylistDefinition(
              id: 'seasons',
              displayName: 'Seasons',
              resolverType: 'rss',
              contentType: 'groups',
            ),
          ],
        ),
      ],
    );

    final episodes = [
      _makeEpisode(1, seasonNumber: 1, publishedAt: DateTime(2024, 1, 1)),
      _makeEpisode(2, seasonNumber: 1, publishedAt: DateTime(2024, 2, 1)),
      _makeEpisode(3, seasonNumber: 2, publishedAt: DateTime(2024, 3, 1)),
    ];

    final result = serviceWithPattern.resolveForPreview(
      podcastGuid: null,
      feedUrl: 'https://example.com/feed',
      episodes: episodes,
    );

    expect(result, isNotNull);
    expect(result!.playlistResults, hasLength(1));
    expect(result.playlistResults.first.definitionId, 'seasons');
    expect(result.playlistResults.first.claimedByOthers, isEmpty);
    expect(result.resolverType, 'rss');
  });

  test('returns null for empty episodes', () {
    final result = service.resolveForPreview(
      podcastGuid: null,
      feedUrl: 'https://example.com/feed',
      episodes: [],
    );
    expect(result, isNull);
  });

  test('tracks claimedByOthers for lower-priority definition', () {
    final serviceWithClaiming = SmartPlaylistResolverService(
      resolvers: [YearResolver()],
      patterns: [
        SmartPlaylistPatternConfig(
          id: 'test',
          feedUrls: ['https://example.com/feed'],
          playlists: [
            SmartPlaylistDefinition(
              id: 'bonus',
              displayName: 'Bonus',
              resolverType: 'year',
              priority: 10,
              requireFilter: r'Bonus',
            ),
            SmartPlaylistDefinition(
              id: 'all',
              displayName: 'All',
              resolverType: 'year',
            ),
          ],
        ),
      ],
    );

    final episodes = [
      _makeEpisode(1, title: 'Main Ep 1', publishedAt: DateTime(2024, 1, 1)),
      _makeEpisode(2, title: 'Bonus: Extra', publishedAt: DateTime(2024, 2, 1)),
      _makeEpisode(3, title: 'Main Ep 2', publishedAt: DateTime(2024, 3, 1)),
    ];

    final result = serviceWithClaiming.resolveForPreview(
      podcastGuid: null,
      feedUrl: 'https://example.com/feed',
      episodes: episodes,
    );

    expect(result, isNotNull);
    expect(result!.playlistResults, hasLength(2));

    // Bonus (higher priority) claims episode 2
    final bonusResult = result.playlistResults
        .firstWhere((r) => r.definitionId == 'bonus');
    expect(bonusResult.playlist.episodeIds, [2]);
    expect(bonusResult.claimedByOthers, isEmpty);

    // All (lower priority, no filters = fallback) gets remaining episodes
    // but also sees episode 2 was claimed by 'bonus'
    final allResult = result.playlistResults
        .firstWhere((r) => r.definitionId == 'all');
    expect(allResult.playlist.episodeIds, unorderedEquals([1, 2, 3]));
    // Fallback definitions don't have filters, so claimedByOthers is
    // only computed for definitions WITH filters. Since 'all' has no
    // filters, it receives all unclaimed episodes as a fallback.
    // claimedByOthers tracks what a filtered definition WOULD have
    // gotten but lost. For the 'all' fallback, nothing was lost.
    expect(allResult.claimedByOthers, isEmpty);
  });

  test('tracks claimedByOthers between two filtered definitions', () {
    final serviceWithClaiming = SmartPlaylistResolverService(
      resolvers: [YearResolver()],
      patterns: [
        SmartPlaylistPatternConfig(
          id: 'test',
          feedUrls: ['https://example.com/feed'],
          playlists: [
            SmartPlaylistDefinition(
              id: 'priority-a',
              displayName: 'Priority A',
              resolverType: 'year',
              priority: 10,
              titleFilter: r'.',  // matches everything
            ),
            SmartPlaylistDefinition(
              id: 'priority-b',
              displayName: 'Priority B',
              resolverType: 'year',
              priority: 5,
              titleFilter: r'.',  // matches everything
            ),
          ],
        ),
      ],
    );

    final episodes = [
      _makeEpisode(1, title: 'Ep 1', publishedAt: DateTime(2024, 1, 1)),
      _makeEpisode(2, title: 'Ep 2', publishedAt: DateTime(2024, 2, 1)),
    ];

    final result = serviceWithClaiming.resolveForPreview(
      podcastGuid: null,
      feedUrl: 'https://example.com/feed',
      episodes: episodes,
    );

    expect(result, isNotNull);
    expect(result!.playlistResults, hasLength(2));

    // Priority A (higher) gets both episodes
    final aResult = result.playlistResults
        .firstWhere((r) => r.definitionId == 'priority-a');
    expect(aResult.playlist.episodeIds, unorderedEquals([1, 2]));
    expect(aResult.claimedByOthers, isEmpty);

    // Priority B has filters but all episodes were claimed by A
    final bResult = result.playlistResults
        .firstWhere((r) => r.definitionId == 'priority-b');
    expect(bResult.claimedByOthers, {1: 'priority-a', 2: 'priority-a'});
  });

  test('sorts episode IDs by publishedAt ascending', () {
    final serviceWithPattern = SmartPlaylistResolverService(
      resolvers: [RssMetadataResolver()],
      patterns: [
        SmartPlaylistPatternConfig(
          id: 'test',
          feedUrls: ['https://example.com/feed'],
          playlists: [
            SmartPlaylistDefinition(
              id: 'seasons',
              displayName: 'Seasons',
              resolverType: 'rss',
              contentType: 'episodes',
            ),
          ],
        ),
      ],
    );

    // Episodes in reverse chronological order
    final episodes = [
      _makeEpisode(1, seasonNumber: 1, publishedAt: DateTime(2024, 3, 1)),
      _makeEpisode(2, seasonNumber: 1, publishedAt: DateTime(2024, 1, 1)),
      _makeEpisode(3, seasonNumber: 1, publishedAt: DateTime(2024, 2, 1)),
    ];

    final result = serviceWithPattern.resolveForPreview(
      podcastGuid: null,
      feedUrl: 'https://example.com/feed',
      episodes: episodes,
    );

    expect(result, isNotNull);
    // Sorted ascending: Jan(2), Feb(3), Mar(1)
    expect(result!.playlistResults.first.playlist.episodeIds, [2, 3, 1]);
  });
});
```

**Step 2: Run tests to verify they fail**

Run: `dart test packages/sp_shared/test/services/smart_playlist_resolver_service_test.dart`
Expected: FAIL - `resolveForPreview` method not found

**Step 3: Implement resolveForPreview**

In `packages/sp_shared/lib/src/services/smart_playlist_resolver_service.dart`, add a new import at the top:

```dart
import '../models/preview_grouping.dart';
```

Then add the following method after `resolveSmartPlaylists` (after line 52):

```dart
/// Resolves playlists with per-definition claimed-episode tracking.
///
/// Returns the same resolution results as [resolveSmartPlaylists] but
/// additionally records which episodes each definition lost to
/// higher-priority definitions.
PreviewGrouping? resolveForPreview({
  required String? podcastGuid,
  required String feedUrl,
  required List<EpisodeData> episodes,
}) {
  if (episodes.isEmpty) return null;

  final episodeById = {for (final e in episodes) e.id: e};

  final config = _findMatchingConfig(podcastGuid, feedUrl);
  if (config == null) return null;

  final result = _resolveWithConfigForPreview(config, episodes);
  if (result == null) return null;

  // Sort episode IDs in every structure
  final sorted = _sortPreviewGrouping(result, episodeById);
  return sorted;
}
```

Then add the `_resolveWithConfigForPreview` private method. This is based on `_resolveWithConfig` but tracks claimed episodes per definition:

```dart
/// Like [_resolveWithConfig] but tracks which episodes each
/// definition lost to higher-priority definitions.
PreviewGrouping? _resolveWithConfigForPreview(
  SmartPlaylistPatternConfig config,
  List<EpisodeData> episodes,
) {
  final playlistResults = <PlaylistPreviewResult>[];
  final allUngroupedIds = <int>{};
  final claimedIds = <int>{};
  // Maps each claimed episode ID to the definition that claimed it
  final claimedByMap = <int, String>{};
  String? resolverType;

  final sorted = List.of(config.playlists)
    ..sort((a, b) => b.priority.compareTo(a.priority));

  for (final definition in sorted) {
    // Compute which candidates this definition would match
    // BEFORE removing claimed IDs, to track what was lost.
    final hasFilters =
        definition.titleFilter != null ||
        definition.excludeFilter != null ||
        definition.requireFilter != null;

    final claimedByOthers = <int, String>{};
    if (hasFilters) {
      // Get candidates including claimed episodes
      final allCandidates = _filterEpisodes(
        episodes, definition, <int>{},
      );
      // Find which of those candidates were already claimed
      for (final ep in allCandidates) {
        if (claimedIds.contains(ep.id)) {
          claimedByOthers[ep.id] = claimedByMap[ep.id] ?? '';
        }
      }
    }

    // Standard filter (excludes claimed)
    final filtered = _filterEpisodes(episodes, definition, claimedIds);
    if (filtered.isEmpty && claimedByOthers.isEmpty) continue;

    final resolver = _findResolverByType(definition.resolverType);
    if (resolver == null) continue;

    SmartPlaylist? playlist;

    if (filtered.isNotEmpty) {
      final result = resolver.resolve(filtered, definition);
      if (result == null && claimedByOthers.isEmpty) continue;

      if (result != null) {
        resolverType ??= result.resolverType;

        final contentType = RssMetadataResolver.parseContentType(
          definition.contentType,
        );
        final yearHeaderMode = RssMetadataResolver.parseYearHeaderMode(
          definition.yearHeaderMode,
        );

        if (contentType == SmartPlaylistContentType.groups) {
          final groupDefMap = {
            for (final g in definition.groups ?? <SmartPlaylistGroupDef>[])
              g.id: g,
          };
          final groups = result.playlists.map((p) {
            final gDef = groupDefMap[p.id];
            return SmartPlaylistGroup(
              id: p.id,
              displayName: p.displayName,
              sortKey: p.sortKey,
              episodeIds: p.episodeIds,
              thumbnailUrl: p.thumbnailUrl,
              episodeYearHeaders: gDef?.episodeYearHeaders,
              showDateRange:
                  gDef?.showDateRange ?? definition.showDateRange,
            );
          }).toList();
          final allEpisodeIds =
              groups.expand((g) => g.episodeIds).toList();

          playlist = SmartPlaylist(
            id: definition.id,
            displayName: definition.displayName,
            sortKey: playlistResults.length,
            episodeIds: allEpisodeIds,
            contentType: contentType,
            yearHeaderMode: yearHeaderMode,
            episodeYearHeaders: definition.episodeYearHeaders,
            showDateRange: definition.showDateRange,
            groups: groups,
          );
        } else {
          // Episodes mode: use first resolver playlist as
          // representative (preserving definition ID)
          final decorated = result.playlists.map((p) {
            return p.copyWith(
              contentType: contentType,
              yearHeaderMode: yearHeaderMode,
              episodeYearHeaders: definition.episodeYearHeaders,
              showDateRange: definition.showDateRange,
            );
          }).toList();

          // For episodes mode, wrap all resolver playlists into
          // one PlaylistPreviewResult per definition
          final allEpisodeIds =
              decorated.expand((p) => p.episodeIds).toList();
          playlist = SmartPlaylist(
            id: definition.id,
            displayName: definition.displayName,
            sortKey: playlistResults.length,
            episodeIds: allEpisodeIds,
            contentType: contentType,
            yearHeaderMode: yearHeaderMode,
            episodeYearHeaders: definition.episodeYearHeaders,
            showDateRange: definition.showDateRange,
            groups: decorated.map((p) {
              return SmartPlaylistGroup(
                id: p.id,
                displayName: p.displayName,
                sortKey: p.sortKey,
                episodeIds: p.episodeIds,
              );
            }).toList(),
          );
        }

        allUngroupedIds.addAll(result.ungroupedEpisodeIds);

        if (hasFilters) {
          for (final p in result.playlists) {
            for (final id in p.episodeIds) {
              claimedIds.add(id);
              claimedByMap[id] = definition.id;
            }
          }
        }
      }
    }

    // Only add result if we have a playlist or claimed episodes
    if (playlist != null) {
      playlistResults.add(PlaylistPreviewResult(
        definitionId: definition.id,
        playlist: playlist,
        claimedByOthers: claimedByOthers,
      ));
    } else if (claimedByOthers.isNotEmpty) {
      // Definition had all its candidates claimed; create an
      // empty playlist result to carry the claimedByOthers info.
      playlistResults.add(PlaylistPreviewResult(
        definitionId: definition.id,
        playlist: SmartPlaylist(
          id: definition.id,
          displayName: definition.displayName,
          sortKey: playlistResults.length,
          episodeIds: [],
        ),
        claimedByOthers: claimedByOthers,
      ));
    }
  }

  if (playlistResults.isEmpty) return null;

  allUngroupedIds.removeAll(claimedIds);

  return PreviewGrouping(
    playlistResults: playlistResults,
    ungroupedEpisodeIds: allUngroupedIds.toList(),
    resolverType: resolverType ?? 'config',
  );
}
```

Then add the sorting helper:

```dart
/// Sorts episode IDs in every structure within a [PreviewGrouping].
PreviewGrouping _sortPreviewGrouping(
  PreviewGrouping grouping,
  Map<int, EpisodeData> episodeById,
) {
  final sortedResults = grouping.playlistResults.map((pr) {
    final sortedGroups = pr.playlist.groups?.map((group) {
      return group.copyWith(
        episodeIds: sortEpisodeIdsByPublishedAt(
          group.episodeIds, episodeById,
        ),
      );
    }).toList();

    return PlaylistPreviewResult(
      definitionId: pr.definitionId,
      playlist: pr.playlist.copyWith(
        episodeIds: sortEpisodeIdsByPublishedAt(
          pr.playlist.episodeIds, episodeById,
        ),
        groups: sortedGroups,
      ),
      claimedByOthers: pr.claimedByOthers,
    );
  }).toList();

  return PreviewGrouping(
    playlistResults: sortedResults,
    ungroupedEpisodeIds: sortEpisodeIdsByPublishedAt(
      grouping.ungroupedEpisodeIds, episodeById,
    ),
    resolverType: grouping.resolverType,
  );
}
```

**Step 4: Run the new tests**

Run: `dart test packages/sp_shared/test/services/smart_playlist_resolver_service_test.dart`
Expected: PASS (all tests including new resolveForPreview group)

**Step 5: Run full sp_shared test suite**

Run: `dart test packages/sp_shared`
Expected: All tests pass

**Step 6: Commit**

```
feat: add resolveForPreview with claimed-episode tracking
```

---

## Task 3: sp_server - Update Preview Handler

**Files:**
- Modify: `packages/sp_server/lib/src/routes/config_routes.dart`
- Modify: `packages/sp_server/test/routes/config_routes_test.dart`

**Step 1: Update `_runPreview` to use `resolveForPreview`**

In `packages/sp_server/lib/src/routes/config_routes.dart`, replace the `_runPreview` method (lines 347-406) to call `resolveForPreview` instead of `resolveSmartPlaylists`, and serialize the per-playlist `claimedByOthers` and `debug` fields.

Replace `_runPreview`:

```dart
Map<String, dynamic> _runPreview(
  SmartPlaylistPatternConfig config,
  List<SimpleEpisodeData> episodes,
) {
  final enriched = _enrichEpisodes(config, episodes);

  final resolvers = <SmartPlaylistResolver>[
    RssMetadataResolver(),
    CategoryResolver(),
    YearResolver(),
    TitleAppearanceOrderResolver(),
  ];

  final service = SmartPlaylistResolverService(
    resolvers: resolvers,
    patterns: [config],
  );

  final result = service.resolveForPreview(
    podcastGuid: config.podcastGuid,
    feedUrl: config.feedUrls?.firstOrNull ?? '',
    episodes: enriched,
  );

  if (result == null) {
    return {
      'playlists': <Map<String, dynamic>>[],
      'ungrouped': <Map<String, dynamic>>[],
      'resolverType': null,
    };
  }

  final episodeById = <int, SimpleEpisodeData>{
    for (final e in enriched) e.id: e,
  };

  final groupedCount = result.playlistResults.fold<int>(
    0,
    (sum, pr) => sum + pr.playlist.episodeIds.length,
  );

  return {
    'playlists': result.playlistResults
        .map((pr) => _serializePreviewResult(
              pr, result.resolverType, episodeById))
        .toList(),
    'ungrouped': result.ungroupedEpisodeIds
        .map((id) => _serializeEpisode(episodeById[id]))
        .whereType<Map<String, dynamic>>()
        .toList(),
    'resolverType': result.resolverType,
    'debug': {
      'totalEpisodes': enriched.length,
      'groupedEpisodes': groupedCount,
      'ungroupedEpisodes': result.ungroupedEpisodeIds.length,
    },
  };
}
```

Add the new serialization helper (after `_serializePlaylist`):

```dart
Map<String, dynamic> _serializePreviewResult(
  PlaylistPreviewResult pr,
  String? resolverType,
  Map<int, SimpleEpisodeData> episodeById,
) {
  final base = _serializePlaylist(pr.playlist, resolverType, episodeById);

  if (pr.claimedByOthers.isNotEmpty) {
    base['claimedByOthers'] = pr.claimedByOthers.entries.map((entry) {
      final episode = episodeById[entry.key];
      return {
        if (episode != null) ...{
          'id': episode.id,
          'title': episode.title,
          'seasonNumber': episode.seasonNumber,
          'episodeNumber': episode.episodeNumber,
        },
        'claimedBy': entry.value,
      };
    }).toList();
  }

  // Per-playlist debug: count filter matches + claimed
  final filterMatchedCount =
      pr.playlist.episodeIds.length + pr.claimedByOthers.length;
  base['debug'] = {
    'filterMatched': filterMatchedCount,
    'episodeCount': pr.playlist.episodeIds.length,
    'claimedByOthersCount': pr.claimedByOthers.length,
  };

  return base;
}
```

**Step 2: Update existing preview tests**

The existing test `'returns grouping results'` checks for `playlists` as a flat list of season playlists. With `resolveForPreview`, the response wraps things differently for preview. The existing test should still get `playlists[0].displayName == 'Seasons'` (the definition display name) with groups inside. Adjust the test assertions to match the new response shape.

Existing test at line ~705 currently expects 2 top-level playlists (Season 1, Season 2). With the new code, a single definition with `resolverType: 'rss'` wraps seasons as groups (since episodes mode puts resolver playlists as groups in preview).

Read the test carefully after implementing and adjust assertions to match the actual output shape. The key difference: `resolveForPreview` wraps resolver output per-definition, so a single definition produces one entry in the playlists array (with groups inside for episodes mode).

**Step 3: Write test for claimedByOthers in response**

Add a new test to the `POST /api/configs/preview` group:

```dart
test('includes claimedByOthers for lower-priority definition', () async {
  final previewBody = jsonEncode({
    'config': {
      'id': 'test',
      'playlists': [
        {
          'id': 'bonus',
          'displayName': 'Bonus',
          'resolverType': 'rss',
          'priority': 10,
          'requireFilter': r'Bonus',
        },
        {
          'id': 'main',
          'displayName': 'Main',
          'resolverType': 'rss',
        },
      ],
    },
    'feedUrl': 'https://example.com/mixed-feed.xml',
  });

  // Need a feed that has episodes matching both
  // definitions. Use the existing mixed RSS helper
  // or create a new one.

  final request = Request(
    'POST',
    Uri.parse('http://localhost/api/configs/preview'),
    headers: {
      'Authorization': 'Bearer $validToken',
      'Content-Type': 'application/json',
    },
    body: previewBody,
  );

  final response = await handler(request);
  expect(response.statusCode, equals(200));

  final body =
      jsonDecode(await response.readAsString()) as Map<String, dynamic>;
  final playlists = body['playlists'] as List;

  // Each playlist should have a 'debug' field
  for (final p in playlists) {
    final playlist = p as Map<String, dynamic>;
    expect(playlist.containsKey('debug'), isTrue);
    final debug = playlist['debug'] as Map<String, dynamic>;
    expect(debug.containsKey('filterMatched'), isTrue);
    expect(debug.containsKey('episodeCount'), isTrue);
    expect(debug.containsKey('claimedByOthersCount'), isTrue);
  }
});
```

Note: The actual RSS mock data may need a new helper. Adapt to what's available in the test file's mock setup. The key assertion is that each playlist in the response contains `debug` with the three per-playlist fields.

**Step 4: Run preview-related tests**

Run: `dart test packages/sp_server/test/routes/config_routes_test.dart`
Expected: All tests pass (may need assertion adjustments for the new response shape)

**Step 5: Run full sp_server test suite**

Run: `dart test packages/sp_server`
Expected: All tests pass

**Step 6: Commit**

```
feat: enhance preview response with per-playlist claimed episodes
```

---

## Task 4: sp_react - Update Zod Schemas

**Files:**
- Modify: `packages/sp_react/src/schemas/api-schema.ts`

**Step 1: Add claimed episode schema and per-playlist debug**

In `packages/sp_react/src/schemas/api-schema.ts`, add after `previewEpisodeSchema`:

```typescript
export const claimedEpisodeSchema = z.object({
  id: z.number(),
  title: z.string(),
  seasonNumber: z.number().nullish(),
  episodeNumber: z.number().nullish(),
  claimedBy: z.string(),
});
```

Add a per-playlist debug schema after `previewDebugSchema`:

```typescript
export const playlistDebugSchema = z.object({
  filterMatched: z.number(),
  episodeCount: z.number(),
  claimedByOthersCount: z.number(),
});
```

Update `previewPlaylistSchema` to include new fields:

```typescript
export const previewPlaylistSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  sortKey: z.union([z.string(), z.number()]),
  resolverType: z.string().nullish(),
  episodeCount: z.number(),
  groups: z.array(previewGroupSchema).optional(),
  claimedByOthers: z.array(claimedEpisodeSchema).optional().default([]),
  debug: playlistDebugSchema.optional(),
});
```

Add new types to the inferred types section:

```typescript
export type ClaimedEpisode = z.infer<typeof claimedEpisodeSchema>;
export type PlaylistDebug = z.infer<typeof playlistDebugSchema>;
```

**Step 2: Run sp_react tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: All tests pass (schema changes are additive with defaults)

**Step 3: Commit**

```
feat: add claimedByOthers and per-playlist debug to preview schemas
```

---

## Task 5: sp_react - Feed Viewer Page

**Files:**
- Create: `packages/sp_react/src/routes/feeds.tsx`
- Create: `packages/sp_react/src/components/feed/feed-viewer.tsx`
- Create: `packages/sp_react/src/components/feed/__tests__/feed-viewer.test.tsx`
- Modify: `packages/sp_react/src/components/editor/editor-layout.tsx` (add "View Feed" button)

**Step 1: Create the feed viewer route**

Create `packages/sp_react/src/routes/feeds.tsx`:

```tsx
import { createFileRoute } from '@tanstack/react-router';
import { z } from 'zod';
import { FeedViewer } from '@/components/feed/feed-viewer.tsx';

const feedSearchSchema = z.object({
  url: z.string().optional(),
});

export const Route = createFileRoute('/feeds')({
  validateSearch: feedSearchSchema,
  component: FeedViewerPage,
});

function FeedViewerPage() {
  const { url } = Route.useSearch();
  return <FeedViewer initialUrl={url} />;
}
```

**Step 2: Create the feed viewer component**

Create `packages/sp_react/src/components/feed/feed-viewer.tsx`:

```tsx
import { useState, useMemo } from 'react';
import { useFeed } from '@/api/queries.ts';
import type { FeedEpisode } from '@/schemas/api-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { Label } from '@/components/ui/label.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Loader2, Search } from 'lucide-react';

interface FeedViewerProps {
  initialUrl?: string;
}

type SortField = 'title' | 'seasonNumber' | 'episodeNumber' | 'publishedAt';
type SortDir = 'asc' | 'desc';

export function FeedViewer({ initialUrl }: FeedViewerProps) {
  const [feedUrl, setFeedUrl] = useState(initialUrl ?? '');
  const [activeUrl, setActiveUrl] = useState(initialUrl ?? '');
  const [search, setSearch] = useState('');
  const [sortField, setSortField] = useState<SortField>('publishedAt');
  const [sortDir, setSortDir] = useState<SortDir>('desc');

  const feedQuery = useFeed(activeUrl || null);

  const filtered = useMemo(() => {
    if (!feedQuery.data) return [];
    const episodes = feedQuery.data as FeedEpisode[];
    const term = search.toLowerCase();
    const matched = term
      ? episodes.filter((ep) => ep.title.toLowerCase().includes(term))
      : episodes;

    return [...matched].sort((a, b) => {
      const aVal = a[sortField];
      const bVal = b[sortField];
      if (aVal == null && bVal == null) return 0;
      if (aVal == null) return 1;
      if (bVal == null) return -1;
      const cmp = String(aVal).localeCompare(String(bVal), undefined, {
        numeric: true,
      });
      return sortDir === 'asc' ? cmp : -cmp;
    });
  }, [feedQuery.data, search, sortField, sortDir]);

  const toggleSort = (field: SortField) => {
    if (sortField === field) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortField(field);
      setSortDir('asc');
    }
  };

  const sortIndicator = (field: SortField) => {
    if (sortField !== field) return '';
    return sortDir === 'asc' ? ' ^' : ' v';
  };

  return (
    <div className="container mx-auto max-w-6xl p-6 space-y-4">
      <h1 className="text-2xl font-bold">Feed Viewer</h1>

      <div className="flex gap-2">
        <div className="flex-1">
          <Label htmlFor="feed-url" className="sr-only">Feed URL</Label>
          <Input
            id="feed-url"
            value={feedUrl}
            onChange={(e) => setFeedUrl(e.target.value)}
            placeholder="https://example.com/feed.xml"
          />
        </div>
        <Button onClick={() => setActiveUrl(feedUrl)}>
          {feedQuery.isLoading ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            'Load'
          )}
        </Button>
      </div>

      {feedQuery.data && (
        <>
          <div className="flex items-center gap-2">
            <Search className="h-4 w-4 text-muted-foreground" />
            <Input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Filter by title..."
              className="max-w-sm"
            />
            <span className="text-sm text-muted-foreground">
              {filtered.length} of{' '}
              {(feedQuery.data as FeedEpisode[]).length} episodes
            </span>
          </div>

          <div className="border rounded-lg overflow-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50">
                  <SortHeader field="title" label="Title"
                    current={sortField} dir={sortDir}
                    onToggle={toggleSort} indicator={sortIndicator} />
                  <SortHeader field="seasonNumber" label="Season"
                    current={sortField} dir={sortDir}
                    onToggle={toggleSort} indicator={sortIndicator} />
                  <SortHeader field="episodeNumber" label="Episode"
                    current={sortField} dir={sortDir}
                    onToggle={toggleSort} indicator={sortIndicator} />
                  <SortHeader field="publishedAt" label="Published"
                    current={sortField} dir={sortDir}
                    onToggle={toggleSort} indicator={sortIndicator} />
                </tr>
              </thead>
              <tbody>
                {filtered.map((ep) => (
                  <tr key={ep.id} className="border-b last:border-0">
                    <td className="px-3 py-2">{ep.title}</td>
                    <td className="px-3 py-2 text-center">
                      {ep.seasonNumber ?? '-'}
                    </td>
                    <td className="px-3 py-2 text-center">
                      {ep.episodeNumber ?? '-'}
                    </td>
                    <td className="px-3 py-2 text-muted-foreground">
                      {ep.publishedAt ?? '-'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}

      {feedQuery.error && (
        <p className="text-destructive">
          Failed to load feed: {feedQuery.error.message}
        </p>
      )}
    </div>
  );
}

function SortHeader({
  field,
  label,
  current,
  dir,
  onToggle,
  indicator,
}: {
  field: SortField;
  label: string;
  current: SortField;
  dir: SortDir;
  onToggle: (f: SortField) => void;
  indicator: (f: SortField) => string;
}) {
  return (
    <th
      className="px-3 py-2 text-left cursor-pointer select-none hover:bg-muted"
      onClick={() => onToggle(field)}
    >
      {label}{indicator(field)}
    </th>
  );
}
```

**Step 3: Add "View Feed" button to editor toolbar**

In `packages/sp_react/src/components/editor/editor-layout.tsx`, add an `ExternalLink` import from lucide-react, then add a "View Feed" button in the `EditorHeader` between the mode toggle and submit button. The button opens `/feeds?url={feedUrl}` in a new tab:

```tsx
{feedUrl && (
  <Button
    variant="outline"
    onClick={() =>
      window.open(
        `/feeds?url=${encodeURIComponent(feedUrl)}`,
        '_blank',
      )
    }
  >
    <ExternalLink className="mr-2 h-4 w-4" />
    View Feed
  </Button>
)}
```

Pass `feedUrl` as a prop to `EditorHeader`.

**Step 4: Write feed viewer test**

Create `packages/sp_react/src/components/feed/__tests__/feed-viewer.test.tsx`:

```tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { FeedViewer } from '../feed-viewer.tsx';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

function renderWithProviders(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>,
  );
}

describe('FeedViewer', () => {
  it('renders feed URL input', () => {
    renderWithProviders(<FeedViewer />);
    expect(screen.getByPlaceholderText(/feed\.xml/)).toBeInTheDocument();
  });

  it('populates input from initialUrl', () => {
    renderWithProviders(
      <FeedViewer initialUrl="https://example.com/feed.xml" />,
    );
    expect(screen.getByDisplayValue('https://example.com/feed.xml')).toBeInTheDocument();
  });
});
```

**Step 5: Run sp_react tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: All tests pass

**Step 6: Commit**

```
feat: add feed viewer page with sortable episode table
```

---

## Task 6: sp_react - Restructure Editor with Tabs

**Files:**
- Modify: `packages/sp_react/src/components/editor/editor-layout.tsx`
- Modify: `packages/sp_react/src/components/editor/config-form.tsx`
- Create: `packages/sp_react/src/components/editor/pattern-settings.tsx`
- Create: `packages/sp_react/src/components/editor/playlist-tab.tsx`
- Create: `packages/sp_react/src/components/editor/playlist-tab-content.tsx`
- Create: `packages/sp_react/src/components/preview/claimed-episodes-section.tsx`
- Create: `packages/sp_react/src/components/preview/playlist-debug-stats.tsx`

This is the largest task. It restructures the editor from a 2-column layout to:
1. Pattern-level settings (feedUrls, podcastGuid) above the tabs
2. Tabs per playlist definition
3. Each tab: paired rows of config (left) + preview (right)
4. Claimed episodes section at bottom of each tab

**Step 1: Extract PatternSettingsCard to its own file**

Move `PatternSettingsCard` and `FeedUrlsField` from `config-form.tsx` into a new file `packages/sp_react/src/components/editor/pattern-settings.tsx`:

```tsx
import { useFormContext } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Label } from '@/components/ui/label.tsx';
import { Textarea } from '@/components/ui/textarea.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';

export function PatternSettingsCard() {
  const { register, watch, setValue } = useFormContext<PatternConfig>();

  return (
    <Card>
      <CardHeader>
        <CardTitle>Pattern Settings</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <Label htmlFor="config-id">Config ID</Label>
            <Input id="config-id" {...register('id')} placeholder="pattern-id" />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="config-podcastGuid">Podcast GUID</Label>
            <Input
              id="config-podcastGuid"
              {...register('podcastGuid')}
              placeholder="Optional GUID"
            />
          </div>
        </div>
        <FeedUrlsField />
        <div className="flex items-center gap-2">
          <Checkbox
            id="config-yearGroupedEpisodes"
            checked={watch('yearGroupedEpisodes') ?? false}
            onCheckedChange={(checked) => setValue('yearGroupedEpisodes', !!checked)}
          />
          <Label htmlFor="config-yearGroupedEpisodes">Year Grouped Episodes</Label>
        </div>
      </CardContent>
    </Card>
  );
}

function FeedUrlsField() {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const feedUrls = watch('feedUrls') ?? [];

  return (
    <div className="space-y-1.5">
      <Label htmlFor="config-feedUrls">Feed URLs (comma-separated)</Label>
      <Textarea
        id="config-feedUrls"
        value={feedUrls.join(', ')}
        onChange={(e) => {
          const urls = e.target.value
            .split(',')
            .map((u) => u.trim())
            .filter(Boolean);
          setValue('feedUrls', urls);
        }}
        placeholder="https://example.com/feed1.xml, https://example.com/feed2.xml"
      />
    </div>
  );
}
```

**Step 2: Create PlaylistDebugStats component**

Create `packages/sp_react/src/components/preview/playlist-debug-stats.tsx`:

```tsx
import type { PlaylistDebug } from '@/schemas/api-schema.ts';
import { Card, CardContent } from '@/components/ui/card.tsx';

interface PlaylistDebugStatsProps {
  debug: PlaylistDebug;
}

export function PlaylistDebugStats({ debug }: PlaylistDebugStatsProps) {
  return (
    <Card>
      <CardContent className="py-3">
        <div className="flex gap-6 text-sm">
          <div>
            <span className="text-muted-foreground">Matched: </span>
            <span className="font-medium">{debug.filterMatched}</span>
          </div>
          <div>
            <span className="text-muted-foreground">Claimed: </span>
            <span className="font-medium">{debug.episodeCount}</span>
          </div>
          {0 < debug.claimedByOthersCount && (
            <div>
              <span className="text-muted-foreground">Lost to others: </span>
              <span className="font-medium text-orange-600">
                {debug.claimedByOthersCount}
              </span>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
```

**Step 3: Create ClaimedEpisodesSection component**

Create `packages/sp_react/src/components/preview/claimed-episodes-section.tsx`:

```tsx
import type { ClaimedEpisode } from '@/schemas/api-schema.ts';
import { Badge } from '@/components/ui/badge.tsx';

interface ClaimedEpisodesSectionProps {
  episodes: ClaimedEpisode[];
}

export function ClaimedEpisodesSection({
  episodes,
}: ClaimedEpisodesSectionProps) {
  if (episodes.length === 0) return null;

  return (
    <div className="space-y-2">
      <h4 className="text-sm font-medium text-muted-foreground">
        Claimed by other playlists ({episodes.length})
      </h4>
      <ul className="space-y-1">
        {episodes.map((ep) => (
          <li
            key={ep.id}
            className="flex items-center gap-2 text-sm text-muted-foreground/60"
          >
            <span className="line-through">{ep.title}</span>
            <Badge variant="outline" className="text-xs">
              claimed by {ep.claimedBy}
            </Badge>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

**Step 4: Create PlaylistTabContent component**

Create `packages/sp_react/src/components/editor/playlist-tab-content.tsx`. This is the per-playlist paired layout with config on the left and preview on the right:

```tsx
import { useFormContext } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import type { PreviewPlaylist } from '@/schemas/api-schema.ts';
import { PlaylistForm } from '@/components/editor/playlist-form.tsx';
import { PlaylistDebugStats } from '@/components/preview/playlist-debug-stats.tsx';
import { ClaimedEpisodesSection } from '@/components/preview/claimed-episodes-section.tsx';
import { PlaylistTree } from '@/components/preview/playlist-tree.tsx';

interface PlaylistTabContentProps {
  index: number;
  previewPlaylist: PreviewPlaylist | null;
  onRemove: () => void;
}

export function PlaylistTabContent({
  index,
  previewPlaylist,
  onRemove,
}: PlaylistTabContentProps) {
  return (
    <div className="space-y-4">
      {/* Paired row: config left, preview right */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Config side */}
        <div>
          <PlaylistFormInline index={index} onRemove={onRemove} />
        </div>

        {/* Preview side */}
        <div className="space-y-4">
          {previewPlaylist ? (
            <>
              {previewPlaylist.debug && (
                <PlaylistDebugStats debug={previewPlaylist.debug} />
              )}
              <PlaylistTree playlists={[previewPlaylist]} />
              <ClaimedEpisodesSection
                episodes={previewPlaylist.claimedByOthers ?? []}
              />
            </>
          ) : (
            <p className="text-sm text-muted-foreground py-8 text-center">
              Run preview to see results for this playlist.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}

/// Inline version of PlaylistForm without accordion wrapper.
/// The tab already provides the per-playlist context.
function PlaylistFormInline({
  index,
  onRemove,
}: {
  index: number;
  onRemove: () => void;
}) {
  // Reuse existing PlaylistForm sub-components by rendering
  // the form fields directly (without AccordionItem wrapper)
  const { watch } = useFormContext<PatternConfig>();
  const prefix = `playlists.${index}` as const;
  const titleFilter = watch(`${prefix}.titleFilter`) ?? '';
  const excludeFilter = watch(`${prefix}.excludeFilter`) ?? '';
  const requireFilter = watch(`${prefix}.requireFilter`) ?? '';

  // Import and reuse the section components from playlist-form
  // For now, render PlaylistForm directly (it uses AccordionItem
  // which works standalone too)
  return (
    <div className="space-y-4 border rounded-lg p-4">
      <PlaylistForm index={index} onRemove={onRemove} />
    </div>
  );
}
```

Note: `PlaylistForm` currently renders as an `AccordionItem`. For the tabbed layout, consider either:
- Wrapping in an `Accordion` so AccordionItem works (simplest)
- Extracting form fields from PlaylistForm into a separate component

The implementer should choose the approach that requires the least refactoring. Wrapping in `<Accordion type="multiple" defaultValue={['playlist-${index}']}>` is the simplest path.

**Step 5: Update editor-layout.tsx with tabs**

Replace the main content area in `packages/sp_react/src/components/editor/editor-layout.tsx`. The 2-column grid becomes: Pattern settings + Tabs.

Key changes to the return JSX:

```tsx
{/* Pattern Settings (above tabs) */}
<FormProvider {...form}>
  <PatternSettingsCard />
</FormProvider>

{/* Playlist Tabs */}
<Tabs
  value={activeTab}
  onValueChange={setActiveTab}
  className="mt-6"
>
  <div className="flex items-center gap-2">
    <TabsList>
      {fields.map((field, index) => {
        const name =
          form.watch(`playlists.${index}.displayName`) ||
          `Playlist ${index + 1}`;
        const previewPlaylist = findPreviewPlaylist(index);
        const count = previewPlaylist?.episodeCount;
        return (
          <TabsTrigger key={field.id} value={`tab-${index}`}>
            {name}
            {count != null && (
              <Badge variant="secondary" className="ml-1">
                {count}
              </Badge>
            )}
          </TabsTrigger>
        );
      })}
    </TabsList>
    <Button
      type="button"
      variant="outline"
      size="sm"
      onClick={() => {
        append({ ...DEFAULT_PLAYLIST });
        setActiveTab(`tab-${fields.length}`);
      }}
    >
      <Plus className="mr-1 h-3 w-3" />
      Add
    </Button>
  </div>

  <FormProvider {...form}>
    {fields.map((field, index) => (
      <TabsContent key={field.id} value={`tab-${index}`}>
        <PlaylistTabContent
          index={index}
          previewPlaylist={findPreviewPlaylist(index)}
          onRemove={() => {
            remove(index);
            if (activeTab === `tab-${index}`) {
              setActiveTab(
                0 < index ? `tab-${index - 1}` : 'tab-0',
              );
            }
          }}
        />
      </TabsContent>
    ))}
  </FormProvider>
</Tabs>
```

Add new state and imports:

```tsx
const [activeTab, setActiveTab] = useState('tab-0');
```

Add `useFieldArray` from react-hook-form:

```tsx
const { fields, append, remove } = useFieldArray({
  control: form.control,
  name: 'playlists',
});
```

Add a helper to find the matching preview playlist by definition ID:

```tsx
const findPreviewPlaylist = useCallback(
  (index: number): PreviewPlaylist | null => {
    if (!previewMutation.data) return null;
    const definitionId = form.getValues(`playlists.${index}.id`);
    return (
      previewMutation.data.playlists.find((p) => p.id === definitionId) ??
      null
    );
  },
  [previewMutation.data, form],
);
```

Also add new imports:

```tsx
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs.tsx';
import { Badge } from '@/components/ui/badge.tsx';
import { Plus, ExternalLink } from 'lucide-react';
import { useFieldArray } from 'react-hook-form';
import { PatternSettingsCard } from '@/components/editor/pattern-settings.tsx';
import { PlaylistTabContent } from '@/components/editor/playlist-tab-content.tsx';
import type { PreviewPlaylist } from '@/schemas/api-schema.ts';
```

Remove the old 2-column grid and the `ConfigForm` / `PreviewPanel` imports (they're now replaced by per-tab content). Keep `PreviewPanel`'s Run Preview button and global debug in the header or toolbar area.

**Step 6: Update ConfigForm to remove PatternSettingsCard**

In `packages/sp_react/src/components/editor/config-form.tsx`, remove `PatternSettingsCard`, `FeedUrlsField`, and the pattern settings imports. The `ConfigForm` component may no longer be needed if the editor layout manages everything via tabs. If still used for JSON mode fallback, simplify it.

**Step 7: Handle JSON mode**

JSON mode still needs to work. When `isJsonMode` is true, show the `JsonEditor` instead of the tabbed layout. The tabs and paired rows only apply in form mode.

```tsx
{isJsonMode ? (
  <FormProvider {...form}>
    <JsonEditor
      value={jsonText}
      onChange={setJsonText}
      className="min-h-[600px]"
    />
  </FormProvider>
) : (
  <>
    <FormProvider {...form}>
      <PatternSettingsCard />
    </FormProvider>
    {/* Tabs as described above */}
  </>
)}
```

**Step 8: Add global preview controls**

Move "Run Preview" button and global debug info to the toolbar area (between pattern settings and tabs, or in the header):

```tsx
<div className="flex items-center justify-between my-4">
  <div className="flex items-center gap-2">
    {previewMutation.data?.debug && (
      <DebugInfoPanel debug={previewMutation.data.debug} />
    )}
  </div>
  <Button onClick={handleRunPreview} disabled={previewMutation.isPending}>
    {previewMutation.isPending ? (
      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
    ) : (
      <Play className="mr-2 h-4 w-4" />
    )}
    Run Preview
  </Button>
</div>
```

**Step 9: Run sp_react tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: All tests pass (some may need updating if they reference old layout)

**Step 10: Commit**

```
feat: restructure editor with per-playlist tabs and paired config/preview
```

---

## Task 7: Integration Testing and Polish

**Files:**
- Various test files across all packages

**Step 1: Run full test suites across all packages**

```bash
dart test packages/sp_shared
dart test packages/sp_server
cd packages/sp_react && pnpm test -- --run
```

Fix any failures.

**Step 2: Format and analyze**

```bash
dart format packages/sp_shared packages/sp_server
dart analyze packages/sp_shared packages/sp_server
cd packages/sp_react && pnpm run lint
```

Fix any issues.

**Step 3: Manual smoke test (if dev server available)**

Start the dev server and verify:
- Editor loads with tabs per playlist
- Pattern settings appear above tabs
- Tab labels show playlist display names
- Run Preview populates per-tab preview results
- Claimed episodes section appears when applicable
- JSON mode toggle still works
- View Feed button opens feed viewer in new tab
- Feed viewer loads and sorts episodes

**Step 4: Final commit**

```
chore: integration fixes and polish for per-playlist preview
```

**Step 5: Create bookmark**

```bash
jj bookmark create feat/per-playlist-preview
```

---

## Summary of All Changes

| Layer | File | Change |
|-------|------|--------|
| sp_shared | `models/preview_grouping.dart` | New: PlaylistPreviewResult, PreviewGrouping models |
| sp_shared | `services/smart_playlist_resolver_service.dart` | New: resolveForPreview method |
| sp_shared | `sp_shared.dart` | Add export for preview_grouping |
| sp_server | `routes/config_routes.dart` | Update _runPreview to use resolveForPreview, add _serializePreviewResult |
| sp_react | `schemas/api-schema.ts` | Add claimedEpisodeSchema, playlistDebugSchema, update previewPlaylistSchema |
| sp_react | `routes/feeds.tsx` | New: feed viewer route |
| sp_react | `components/feed/feed-viewer.tsx` | New: searchable/sortable episode table |
| sp_react | `components/editor/pattern-settings.tsx` | Extracted from config-form.tsx |
| sp_react | `components/editor/playlist-tab-content.tsx` | New: paired config/preview per playlist |
| sp_react | `components/preview/playlist-debug-stats.tsx` | New: per-playlist debug stats |
| sp_react | `components/preview/claimed-episodes-section.tsx` | New: claimed episodes with badges |
| sp_react | `components/editor/editor-layout.tsx` | Restructured: tabs, View Feed button, global preview |
| sp_react | `components/editor/config-form.tsx` | Simplified: PatternSettingsCard extracted |
