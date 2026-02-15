# Per-Playlist Preview Design

## Problem

The preview sends the entire pattern config to the server and displays all results as a single tree. Users cannot see the effect of editing a single playlist definition in isolation. When a pattern has multiple playlists with priority-based episode claiming, it is hard to understand which playlist captures which episodes and why.

## Design

### Overview

Replace the current side-by-side editor/preview layout with a tabbed per-playlist view. Each tab pairs config editing with preview results in horizontally-aligned rows. Add claimed-episode tracking so users can see episodes that matched their filters but were taken by a higher-priority playlist. Add a feed viewer route that opens in a new browser window for inspecting raw RSS data.

### Changes by Layer

#### sp_shared (Domain)

**New models:**

```dart
/// Preview-specific wrapper for a playlist's resolution result.
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
  /// Each entry maps episode ID to the claiming definition ID.
  final Map<int, String> claimedByOthers;
}

/// Preview-specific grouping that wraps SmartPlaylistGrouping
/// with per-playlist claimed-episode tracking.
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

**New method on `SmartPlaylistResolverService`:**

```dart
PreviewGrouping? resolveForPreview({
  required String? podcastGuid,
  required String feedUrl,
  required List<EpisodeData> episodes,
})
```

This method follows the same logic as `resolveSmartPlaylists` but additionally tracks claimed episodes:

1. Sort definitions by priority (descending).
2. For each definition, apply titleFilter/excludeFilter/requireFilter to get the full candidate set.
3. Compute `claimedByOthers = candidates intersect alreadyClaimedIds`. Record which definition claimed each.
4. Remove claimed IDs from candidates, pass remainder to resolver.
5. Return `PreviewGrouping` with per-playlist `PlaylistPreviewResult`.

#### sp_server (API)

**Updated preview response shape:**

```json
{
  "playlists": [
    {
      "id": "playlist-1",
      "displayName": "Season Groups",
      "sortKey": "season-groups",
      "resolverType": "rss",
      "episodeCount": 45,
      "groups": [
        {
          "id": "season-1",
          "displayName": "Season 1",
          "sortKey": 1,
          "episodeCount": 10,
          "episodes": [...]
        }
      ],
      "claimedByOthers": [
        {
          "id": 12,
          "title": "Episode 12",
          "seasonNumber": 2,
          "episodeNumber": 1,
          "claimedBy": "playlist-2"
        }
      ],
      "debug": {
        "filterMatched": 50,
        "episodeCount": 45,
        "claimedByOthersCount": 5
      }
    }
  ],
  "ungrouped": [...],
  "resolverType": "rss",
  "debug": {
    "totalEpisodes": 100,
    "groupedEpisodes": 80,
    "ungroupedEpisodes": 20
  }
}
```

Key additions per playlist:
- `claimedByOthers`: Episodes that matched filters but were claimed. Each entry includes `claimedBy` (the claiming playlist's ID).
- `debug`: Per-playlist stats (filterMatched, episodeCount, claimedByOthersCount).

**Changes to `_runPreview`:** Call `resolveForPreview` instead of `resolveSmartPlaylists`. Serialize the `claimedByOthers` map using the episode lookup.

**New route: `GET /api/feeds` already exists.** The feed viewer page uses this endpoint. No backend change needed for the feed viewer.

#### sp_react (Frontend)

**New route: `/feeds`**

A standalone page that opens in a new browser tab. Shows a searchable, sortable table of episodes from the RSS feed:
- Columns: title, seasonNumber, episodeNumber, publishedAt
- Search/filter input for title text
- Feed URL passed as query parameter

**Editor layout restructure:**

Current layout:
```
[Toolbar: feed URL, mode toggle, actions]
[Editor form/JSON (left)]  [Preview panel (right)]
```

New layout:
```
[Toolbar: feed URL, View Feed button, Run Preview, mode toggle]
[Pattern-level fields: feedUrls, podcastGuid]
[Tabs: Playlist A | Playlist B | + New]
[Tab content: paired config/preview rows]
```

**Per-playlist tab content:**

Each tab contains vertically stacked rows. Each row is a horizontal pair:

```
Row 0 - Playlist header:
  [Config: resolverType, priority, contentType, filters]
  [Preview: episode count, debug stats]

Rows 1..N - Groups (when contentType=groups):
  [Config: group regex, displayName, sort]
  [Preview: matched episodes list]

Row N+1 - Episodes (when contentType=episodes):
  [Config: (included in row 0)]
  [Preview: episode list]

Final row - Claimed by others (if any):
  [Full width: dimmed episodes with "claimed by {playlistName}" badge]
```

**New components:**

| Component | Purpose |
|-----------|---------|
| `PlaylistTab` | Per-playlist paired layout container |
| `ConfigPreviewRow` | Horizontal pair: config (left) + preview (right) |
| `GroupConfigPreviewRow` | Paired row for a single group definition |
| `ClaimedEpisodesSection` | Dimmed list of episodes claimed by other playlists |
| `FeedViewerPage` | Route component for `/feeds`, searchable episode table |
| `PlaylistDebugStats` | Per-playlist debug info (filterMatched, claimed, etc.) |

**Schema updates (`api-schema.ts`):**

Add to `previewPlaylistSchema`:
```typescript
claimedByOthers: z.array(z.object({
  id: z.number(),
  title: z.string(),
  seasonNumber: z.number().nullish(),
  episodeNumber: z.number().nullish(),
  claimedBy: z.string(),
})).optional().default([]),

debug: z.object({
  filterMatched: z.number(),
  episodeCount: z.number(),
  claimedByOthersCount: z.number(),
}).optional(),
```

**Form restructure:**

Currently one form manages the entire pattern config. With per-playlist tabs, each tab manages its own playlist definition fields via React Hook Form's `useFieldArray` or nested field paths (`playlists.${index}.resolverType`, etc.). Pattern-level fields (feedUrls, podcastGuid) live above the tabs.

### Feed Viewer Page

Route: `/feeds?url={encodedFeedUrl}`

Fetches episodes via `GET /api/feeds?url={feedUrl}` and displays them in a table. Features:
- Sortable columns (click header to sort)
- Text filter input for title search
- Columns: #, title, season, episode, publishedAt
- Opens in a new browser window from the editor toolbar

### Data Flow

```
User edits playlist config in tab
  |
  v
User clicks "Run Preview"
  |
  v
Frontend sends full pattern config + feedUrl
POST /api/configs/preview
  |
  v
Server: SmartPlaylistResolverService.resolveForPreview()
  - resolves all playlists with claiming
  - tracks claimedByOthers per playlist
  |
  v
Server returns enhanced preview response
  - per-playlist: groups/episodes + claimedByOthers + debug
  - global: ungrouped + debug
  |
  v
Frontend distributes results to tabs
  - Each tab receives its playlist's slice of the response
  - Tab renders paired config/preview rows
  - Claimed section shows episodes taken by other playlists
```

### What Does Not Change

- The "Run Preview" action still sends the full config (all playlists) in one request.
- The resolver chain logic (priority, claiming, sorting) is unchanged.
- JSON mode still works - user can toggle to see/edit raw JSON.
- The submit flow (PR creation) is unchanged.
- The backend feed caching (15min TTL) is unchanged.
