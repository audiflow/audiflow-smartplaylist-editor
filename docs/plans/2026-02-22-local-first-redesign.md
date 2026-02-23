# Local-First Redesign

## Motivation

The current architecture treats the web editor as a remote GitHub client: users sign in with OAuth, edit configs in the browser, and submit changes as pull requests. This design couples the editor to GitHub's API, requires authentication infrastructure, and keeps drafts in volatile storage (browser localStorage and server memory).

The redesign shifts to a local-first model. Users clone the data repository, run the editor as a local tool, and manage commits and PRs themselves. The editor becomes a development tool rather than a hosted service.

## Repository Model

### Current: four repos

| Repo | Role |
|------|------|
| `audiflow-smartplaylist-web` | Editor + server + MCP + schema models |
| `audiflow-smartplaylist-schema` | JSON Schema + docs + examples + validation scripts |
| `audiflow-smartplaylist` | Production config data |
| `audiflow-smartplaylist-dev` | Dev config data |

### New: three repos

| Repo | Role |
|------|------|
| `audiflow-smartplaylist-web` | Editor tool (server + SPA + MCP); installed globally |
| `audiflow-smartplaylist` | Production configs + schema + docs + examples |
| `audiflow-smartplaylist-dev` | Dev configs + schema (same structure, independent) |

The schema repo merges into each data repo. Each data repo is self-contained. The editor is a tool installed separately and run against any data repo.

## Data Repo Structure

```
audiflow-smartplaylist/
  schema/
    schema.json                          # Full config schema (draft-07)
    playlist-definition.schema.json      # Individual playlist schema ($ref)
    docs/
      schema.html                        # Browsable HTML documentation
      schema_doc.min.js
      schema_doc.css
      file-structure.md                  # Config hierarchy docs
    examples/
      rss-resolver.json
      category-resolver.json
      year-resolver.json
      title-appearance-order-resolver.json
    scripts/
      validate.sh                        # Validate configs against schema
      generate-docs.sh                   # Regenerate HTML docs
  patterns/
    meta.json                            # Root meta: version + pattern summaries
    {patternId}/
      meta.json                          # Pattern meta: feedUrls, playlistIds
      playlists/
        {playlistId}.json                # SmartPlaylistDefinition
  .cache/                                # gitignored
    feeds/
  .gitignore
  LICENSE
  README.md
```

Config paths are prefixed with `patterns/` (e.g., `patterns/meta.json`). The editor reads `schema/schema.json` for validation.

## Architecture

```
Browser (sp_react)          sp_server (Dart)              MCP server (Dart)
   |                           |                              |
   |<--- HTTP REST API ------->|                              |
   |<--- SSE (file changes) ---|                              |
   |                           |                              |
   |                     local data repo directory
   |                     +-- schema/schema.json
   |                     +-- patterns/meta.json
   |                     +-- patterns/{id}/meta.json
   |                     +-- patterns/{id}/playlists/{pid}.json
   |                     +-- .cache/feeds/          (gitignored)
   |                           |                              |
   |                           |--- reads/writes/watches ---->|
   |                           |                              |
   |                           |<---- reads/writes -----------|
   |                           |                              |
                          localhost:8080              stdio JSON-RPC
                        (auto-detect CWD)          (auto-detect CWD)
```

### Design decisions

- **No authentication.** The server binds to `127.0.0.1` only. All requests are trusted.
- **No GitHub integration.** No OAuth, no PR submission, no API keys. Users commit and push themselves.
- **No drafts.** Files on disk are the working copy. The editor reads and writes them directly.
- **Auto-detect from CWD.** Both servers detect the data repo root from the current working directory.
- **Separate processes, shared filesystem.** The web server and MCP server run independently. The filesystem is the shared state.
- **SSE for file change notifications.** The server watches the data directory and pushes events to the browser via Server-Sent Events.
- **Explicit save with conflict dialog.** The user saves manually (button or Ctrl+S). When an external change conflicts with unsaved edits, the browser shows a dialog: "Reload from disk" or "Keep your changes."
- **Shared disk-based feed cache.** Both servers read and write feed data to `.cache/feeds/`. TTL is configurable via `SP_FEED_CACHE_TTL` env var (default: 1 hour).
- **Single server for production.** The Dart server serves the built React SPA as static files. One command, one URL.

## Server API

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `GET /api/health` | GET | Health check |
| `GET /api/schema` | GET | JSON Schema (from `schema/schema.json`) |
| `GET /api/configs/patterns` | GET | List pattern summaries |
| `GET /api/configs/patterns/<id>` | GET | Get pattern metadata |
| `GET /api/configs/patterns/<id>/playlists/<pid>` | GET | Get playlist definition |
| `GET /api/configs/patterns/<id>/assembled` | GET | Assemble full config |
| `POST /api/configs/validate` | POST | Validate config JSON |
| `POST /api/configs/preview` | POST | Preview playlists from config + feed |
| `PUT /api/configs/patterns/<id>/playlists/<pid>` | PUT | Save playlist to disk |
| `PUT /api/configs/patterns/<id>/meta` | PUT | Save pattern meta to disk |
| `POST /api/configs/patterns` | POST | Create new pattern |
| `DELETE /api/configs/patterns/<id>/playlists/<pid>` | DELETE | Delete playlist file |
| `DELETE /api/configs/patterns/<id>` | DELETE | Delete pattern directory |
| `GET /api/feeds` | GET | Fetch and parse RSS feed (disk-cached) |
| `GET /api/events` | SSE | File change event stream |

## Server Changes (sp_server)

### New services

**`LocalConfigRepository`** replaces `ConfigRepository`. Reads and writes split config files directly on disk. Validates against the schema before writing. No caching needed.

**`DiskFeedCacheService`** replaces `FeedCacheService`. Lives in `sp_shared` so both servers share the implementation. Caches feed XML and metadata in `.cache/feeds/`, keyed by SHA-256 of the feed URL. Each entry has a `.xml` file and a `.meta` file (URL + fetched-at timestamp). Checks freshness against configurable TTL before fetching.

**`FileWatcherService`** watches the data directory recursively via `dart:io` `FileSystemEntity.watch()`. Debounces rapid changes (~200ms). Emits structured events: `{ type, path }`. Ignores `.cache/`.

**SSE endpoint** (`GET /api/events`) streams file change events to connected browsers. Browsers reconnect automatically via `EventSource`.

**Static file serving** serves the built React SPA for non-API routes, with fallback to `index.html` for client-side routing.

### Removed services

- `GitHubOAuthService`, `GitHubAppService`, `JwtService`, `ApiKeyService`, `UserService`
- `DraftService`
- All auth middleware
- `submit_routes.dart`, `auth_routes.dart`, `draft_routes.dart`, `key_routes.dart`

## Frontend Changes (sp_react)

### Removed

- Auth store, login route, OAuth callback
- Token injection and 401 refresh in `ApiClient`
- Draft service, `useAutoSave` hook
- `SubmitDialog` and PR submission UI
- Settings page (API key management)
- Auth guards on routes

### Simplified

**`ApiClient`**: plain fetch wrapper with base URL and JSON handling. No auth headers.

**Routing:**

| Route | Purpose |
|-------|---------|
| `/` | Redirects to `/browse` |
| `/browse` | Pattern listing |
| `/editor` | Create new pattern |
| `/editor/$id` | Edit existing pattern |

### Added

**`useFileEvents()` hook**: connects to `GET /api/events` via `EventSource`. On file change, invalidates matching TanStack Query cache keys. TanStack Query refetches; UI updates.

**Save flow**: "Save" button + Ctrl+S calls `PUT`. Dirty indicator compares form state against last-loaded data. On external change to a file with unsaved edits, a conflict dialog appears.

**File operations**: create pattern (`POST`), delete playlist (`DELETE`), delete pattern (`DELETE`), each with confirmation.

### Unchanged

- Editor form components (playlist, groups, extractors, sort rules)
- CodeMirror JSON editor
- Feed viewer, preview panel
- TanStack Query, Zustand, Tailwind + shadcn/ui

## MCP Server Changes

**Config operations** use local filesystem directly. `submit_config` writes files to disk (was: create GitHub PR). `get_config` and `search_configs` read from disk. `get_schema` reads `schema/schema.json`.

**Feed operations** use `DiskFeedCacheService` (shared with web server via `sp_shared`).

**Removed**: all GitHub API dependencies.

**Unchanged**: `validate_config`, `preview_config` logic. JSON-RPC transport over stdio. Tool and resource names.

## Shared Code (sp_shared)

**New**: `DiskFeedCacheService` extracted to `sp_shared` for reuse by both servers. Handles concurrent access with atomic writes.

**Changed**: `SmartPlaylistValidator` reads `schema.json` from the data directory at runtime (was: bundled asset). Path provided via constructor.

**Unchanged**: all domain models, JSON serialization, resolver chain, `ConfigAssembler`, `SmartPlaylistResolverService`, `SmartPlaylistPatternLoader`.

## Summary of Net Changes

| Area | Removed | Added |
|------|---------|-------|
| sp_server | Auth, GitHub, drafts (~40% of code) | LocalConfigRepository, FileWatcherService, SSE, static serving, write endpoints |
| sp_react | Auth, drafts, submit, settings (~30% of code) | SSE hook, save flow, conflict dialog, file operation UI |
| sp_shared | -- | DiskFeedCacheService, runtime schema loading |
| MCP | GitHub submit | Local file write, DiskFeedCacheService |
| Repos | 4 repos | 3 repos (schema merges into data repos) |

The core domain -- models, resolvers, schema validation, preview -- stays intact. The change affects the I/O layer: GitHub API gives way to the local filesystem.
