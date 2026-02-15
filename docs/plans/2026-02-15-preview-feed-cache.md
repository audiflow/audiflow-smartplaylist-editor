# Preview Feed Cache Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate the client-to-server round-trip of episode data during preview by having the server use its own FeedCacheService.

**Architecture:** The preview endpoint changes from `{config, episodes}` to `{config, feedUrl}`. Server fetches episodes from FeedCacheService (likely a cache hit since the client already triggered `/api/feeds`). Client sends only the feed URL, not hundreds of episode objects.

**Tech Stack:** Dart (shelf), TypeScript (React + TanStack Query)

---

### Task 1: Server -- Inject FeedCacheService into configRouter

**Files:**
- Modify: `packages/sp_server/lib/src/routes/config_routes.dart:16-20` (configRouter signature)
- Modify: `packages/sp_server/bin/server.dart:84-88` (configRouter call site)

**Step 1: Add `feedCacheService` parameter to `configRouter`**

In `config_routes.dart`, add `FeedCacheService` to the required params and pass it to `_handlePreview`:

```dart
Router configRouter({
  required ConfigRepository configRepository,
  required FeedCacheService feedCacheService,
  required JwtService jwtService,
  required ApiKeyService apiKeyService,
})
```

Update the preview handler registration:

```dart
final previewHandler = const Pipeline()
    .addMiddleware(auth)
    .addHandler((Request r) => _handlePreview(r, feedCacheService));
```

**Step 2: Wire in server.dart**

```dart
final configs = configRouter(
  configRepository: configRepository,
  feedCacheService: feedCacheService,
  jwtService: jwtService,
  apiKeyService: apiKeyService,
);
```

**Step 3: Verify it compiles**

Run: `dart analyze packages/sp_server`
Expected: Zero errors (tests will fail until Task 2)

---

### Task 2: Server -- Change _handlePreview to accept feedUrl

**Files:**
- Modify: `packages/sp_server/lib/src/routes/config_routes.dart:238-298` (_handlePreview)

**Step 1: Update test expectations first**

In `config_routes_test.dart`, update the preview test group. Change body payloads from `{config, episodes}` to `{config, feedUrl}`. Add a FeedCacheService to the test setup.

The test setUp needs a FeedCacheService that returns canned episodes:

```dart
late FeedCacheService feedCacheService;

setUp(() {
  // ... existing setup ...
  feedCacheService = FeedCacheService(
    httpGet: (Uri url) async {
      if (url.toString() == 'https://example.com/feed.xml') {
        return _sampleRss();
      }
      throw Exception('Unknown feed URL: $url');
    },
  );

  final router = configRouter(
    configRepository: configRepository,
    feedCacheService: feedCacheService,
    jwtService: jwtService,
    apiKeyService: apiKeyService,
  );
  handler = router.call;
});
```

Update preview test bodies:
- `'episodes': [...]` becomes `'feedUrl': 'https://example.com/feed.xml'`
- Validation test for missing episodes becomes missing feedUrl
- Add test: returns 502 when feed fetch fails

**Step 2: Run tests to confirm they fail**

Run: `dart test packages/sp_server/test/routes/config_routes_test.dart`
Expected: Preview tests FAIL

**Step 3: Implement new _handlePreview**

Replace the `episodes` field parsing with `feedUrl`:

```dart
Future<Response> _handlePreview(
  Request request,
  FeedCacheService feedCacheService,
) async {
  // ... existing JSON parsing ...

  final configJson = parsed['config'];
  final feedUrl = parsed['feedUrl'];

  if (configJson is! Map<String, dynamic>) {
    return _error(400, 'Missing or invalid "config" field');
  }
  if (feedUrl is! String || feedUrl.isEmpty) {
    return _error(400, 'Missing or invalid "feedUrl" field');
  }

  try {
    final config = SmartPlaylistPatternConfig.fromJson(configJson);
    final episodeMaps = await feedCacheService.fetchFeed(feedUrl);
    final episodes = episodeMaps
        .map((e) => _parseEpisode(e.cast<String, dynamic>()))
        .toList();
    final result = _runPreview(config, episodes);
    return Response.ok(jsonEncode(result), headers: _jsonHeaders);
  } on Object catch (e) {
    return Response(400, body: jsonEncode({'error': 'Preview failed: $e'}),
        headers: _jsonHeaders);
  }
}
```

**Step 4: Run tests**

Run: `dart test packages/sp_server/test/routes/config_routes_test.dart`
Expected: All PASS

**Step 5: Run full sp_server tests**

Run: `dart test packages/sp_server`
Expected: All 208+ tests PASS

---

### Task 3: Client -- Update usePreviewMutation to send feedUrl

**Files:**
- Modify: `packages/sp_react/src/api/queries.ts:47-53` (usePreviewMutation)
- Modify: `packages/sp_react/src/components/editor/editor-layout.tsx:129-143` (handleRunPreview)

**Step 1: Update mutation type**

Change `usePreviewMutation` params from `{config, episodes}` to `{config, feedUrl}`:

```typescript
export function usePreviewMutation() {
  const client = useApiClient();
  return useMutation({
    mutationFn: (params: { config: unknown; feedUrl: string }) =>
      client.post<PreviewResult>('/api/configs/preview', params),
  });
}
```

**Step 2: Update handleRunPreview in editor-layout.tsx**

Send `feedUrl` instead of `episodes`:

```typescript
const handleRunPreview = useCallback(() => {
  if (!feedUrl) {
    toast.error('Enter a feed URL before running preview');
    return;
  }
  let config: unknown;
  if (isJsonMode) {
    try {
      config = JSON.parse(jsonText);
    } catch {
      toast.error('Invalid JSON: cannot run preview');
      return;
    }
  } else {
    config = form.getValues();
  }
  previewMutation.mutate({ config, feedUrl });
}, [isJsonMode, jsonText, form, feedUrl, previewMutation]);
```

Remove `feedQuery.data` from the dependency array (no longer needed for preview).

**Step 3: Verify build**

Run: `cd packages/sp_react && pnpm build`
Expected: Build succeeds

**Step 4: Run client tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: All 70 tests PASS

---

### Task 4: Verify end-to-end and commit

**Step 1: Run all Dart tests**

Run: `dart test packages/sp_shared && dart test packages/sp_server`
Expected: All pass

**Step 2: Run all React tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: All pass

**Step 3: Format and analyze**

Run: `dart format packages/sp_server/lib/src/routes/config_routes.dart packages/sp_server/bin/server.dart packages/sp_server/test/routes/config_routes_test.dart`
Run: `dart analyze packages/sp_server`
Expected: Zero issues

**Step 4: Commit**

```bash
jj bookmark create refactor/preview-feed-cache
```

Commit message: `refactor: use server-side feed cache for preview instead of client-sent episodes`
