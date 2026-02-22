# Architecture

Dart monorepo with three Dart workspace packages plus a React SPA.

## Package Overview

```
audiflow-smartplaylist-web/
├── packages/
│   ├── sp_shared/     # Domain models, resolvers, services (pure Dart)
│   ├── sp_server/     # Local API server (shelf)
│   └── sp_react/      # React SPA web editor (TanStack + Zustand + shadcn/ui)
└── mcp_server/        # MCP server for Claude integration
```

| Package | Role | Dependencies |
|---------|------|-------------|
| `sp_shared` | Shared domain layer: models, resolvers, schema, services, DiskFeedCacheService | None (pure Dart) |
| `sp_server` | Local API server: config CRUD, preview, feed caching, file watching | sp_shared, shelf |
| `sp_react` | Web editor UI: pattern browsing, config editing, preview | React 19, TanStack Query/Router, Zustand, RHF, Zod, CodeMirror 6 |
| `mcp_server` | Exposes smart playlist operations as MCP tools | sp_shared, sp_server |

## Ecosystem Context

This repo is one part of a three-component ecosystem:

```
User clones data repo locally
                |
                v
[audiflow-smartplaylist-web]              Local data repo clone         GitHub (remote)
 (this repo)                  read/write  (on user's machine)  push    (source of truth)
 sp_server + sp_react  <────────────────>  JSON files on disk  ──────>  origin/main
 mcp_server            <────────────────>
                                                                CI sync
                                                                ──────>  GitHub Pages / GCS
                                                                            ^
                                                                            |
                                                                         audiflow app fetches
```

- **audiflow-smartplaylist** (data repo): Static JSON files on GitHub, source of truth
- **GitHub Pages / GCS**: Mirrors the data repo; the mobile app fetches configs from here
- **audiflow app**: Consumes configs via `audiflow_domain` with local caching
- **This repo**: Local web editor and MCP server that read/write files in a cloned data repo

Model serialization (JSON keys, field structure) must stay aligned across all three.

## sp_shared

Pure Dart package with no framework dependencies. All domain logic lives here.

### Models

Core types use `final class` with hand-written `fromJson()`/`toJson()`. No code generation.

| Model | Purpose |
|-------|---------|
| `EpisodeData` | Abstract interface for episode data; `SimpleEpisodeData` for concrete use |
| `SmartPlaylist` | A playlist containing episode IDs, with optional groups |
| `SmartPlaylistGroup` | A group within a playlist (when contentType is `groups`) |
| `SmartPlaylistGrouping` | Resolver output: playlists + ungrouped episode IDs |
| `SmartPlaylistDefinition` | Per-playlist config: resolver type, filters, extractors |
| `SmartPlaylistPatternConfig` | Per-podcast config: feed URL matching + playlist definitions |
| `PatternMeta` / `PatternSummary` / `RootMeta` | Split config metadata hierarchy |
| `SmartPlaylistSort` | Sealed sort specification (simple or composite) |
| `SmartPlaylistGroupDef` | Static group definitions for category resolver |
| `SmartPlaylistTitleExtractor` | Regex-based display name extraction with templates and fallbacks |
| `SmartPlaylistEpisodeExtractor` | Season/episode number extraction from titles |
| `EpisodeNumberExtractor` | Episode number extraction with RSS fallback |

### Resolver Chain

Resolvers implement `SmartPlaylistResolver` and group episodes by different strategies:

| Resolver | Strategy |
|----------|----------|
| `RssMetadataResolver` | Groups by `seasonNumber` RSS field |
| `CategoryResolver` | Groups by regex patterns against group definitions |
| `YearResolver` | Groups by publication year |
| `TitleAppearanceOrderResolver` | Groups by title pattern, ordered by first appearance |

`SmartPlaylistResolverService` orchestrates the chain:

1. Match podcast by GUID or feed URL against `SmartPlaylistPatternConfig` list
2. If matched: route episodes through definitions in priority order, filtering by title/exclude/require regexes
3. If no match: try resolvers in order with no definition (auto-detect mode)
4. Sort all episode IDs by `publishedAt` ascending (nulls last)
5. Return `SmartPlaylistGrouping` or null

Content type determines output shape:
- `episodes`: Each resolver playlist becomes a top-level `SmartPlaylist`
- `groups`: Resolver playlists become `SmartPlaylistGroup` entries inside one parent playlist

### Services

| Service | Purpose |
|---------|---------|
| `SmartPlaylistResolverService` | Resolver chain orchestrator (described above) |
| `ConfigAssembler` | Combines `PatternMeta` + playlist definitions into unified config |
| `SmartPlaylistPatternLoader` | Parses JSON into pattern configs with version validation |
| `DiskFeedCacheService` | Disk-based feed cache with SHA-256 URL hashing and configurable TTL |
| `sortEpisodeIdsByPublishedAt` | Episode sorting utility (ascending, nulls last, stable) |

### Schema

`SmartPlaylistSchema` generates JSON Schema and validates configs at runtime.

## sp_server

Shelf-based local API server with Cascade routing. Runs on localhost only, no authentication required.

### Routes

| Endpoint | Purpose |
|----------|---------|
| `GET /api/health` | Health check |
| `GET /api/schema` | JSON Schema for configs |
| `GET /api/configs/patterns` | List pattern summaries |
| `POST /api/configs/patterns` | Create new pattern |
| `GET /api/configs/patterns/<id>` | Get pattern metadata |
| `DELETE /api/configs/patterns/<id>` | Delete pattern and all playlists |
| `PUT /api/configs/patterns/<id>/meta` | Update pattern metadata |
| `GET /api/configs/patterns/<id>/assembled` | Assemble full config |
| `GET /api/configs/patterns/<id>/playlists/<pid>` | Get playlist definition |
| `PUT /api/configs/patterns/<id>/playlists/<pid>` | Save playlist definition |
| `DELETE /api/configs/patterns/<id>/playlists/<pid>` | Delete playlist |
| `POST /api/configs/validate` | Validate config against schema |
| `POST /api/configs/preview` | Preview smart playlists from config + feed |
| `GET /api/feeds` | Fetch and parse RSS feed |
| `GET /api/events` | SSE stream of file change events |

### Services

| Service | Purpose |
|---------|---------|
| `LocalConfigRepository` | Read/write config files on disk with atomic writes |
| `FileWatcherService` | Watch data directory for changes, emit SSE events |
| `DiskFeedCacheService` (from sp_shared) | Disk-based feed cache with SHA-256 URL hashing |
| `SmartPlaylistValidator` (from sp_shared) | Schema validation |

### Local-First Architecture

- Server auto-detects data dir from CWD (requires `patterns/meta.json`)
- Binds to localhost only (`InternetAddress.loopbackIPv4`)
- No authentication required
- File changes trigger SSE events to connected browsers
- Feed cache stored in `$dataDir/.cache/feeds/`

## sp_react

React 19 SPA built with Vite + TypeScript.

### Tech Stack

- **Routing**: TanStack Router (file-based)
- **Server state**: TanStack Query (caching, refetching)
- **Local state**: Zustand (editor-store)
- **Forms**: React Hook Form + Zod (zodResolver)
- **Styling**: Tailwind CSS v4 + shadcn/ui (new-york style)
- **JSON editing**: CodeMirror 6
- **Testing**: Vitest + @testing-library/react

### Routes

| Route | Screen |
|-------|--------|
| `/browse` | Pattern listing |
| `/editor` | Create new config |
| `/editor/$id` | Edit existing pattern |
| `/feeds` | Feed browser |

### Key Components

- `ApiClient`: Simple HTTP wrapper for API calls (no auth)
- Stores (Zustand): `editor-store` (UI state)
- `useFileEvents`: SSE hook for real-time cache invalidation
- Query hooks: `usePatterns`, `useAssembledConfig`, `useFeed`, `usePreviewMutation`, `useSavePlaylist`, `useSavePatternMeta`, `useDeletePlaylist`, `useDeletePattern`, `useCreatePattern`, etc.

## mcp_server

Exposes smart playlist operations as MCP tools over stdio.

### Tools

| Tool | Purpose |
|------|---------|
| `search_configs` | Search pattern configs by keyword |
| `get_config` | Get assembled config by pattern ID |
| `get_schema` | Get JSON Schema from disk |
| `fetch_feed` | Fetch and cache RSS feed |
| `validate_config` | Validate config against schema |
| `preview_config` | Preview playlists from config + feed |
| `submit_config` | Save config to disk (validates first) |

### Architecture

- Auto-detects data directory from CWD (same as sp_server)
- Uses `LocalConfigRepository` for config CRUD
- Uses `DiskFeedCacheService` for feed caching
- Uses `SmartPlaylistValidator` for schema validation
- Communicates via stdio (JSON-RPC over stdin/stdout)

## Split Config Structure

Configs are stored as a three-level file hierarchy:

```
meta.json                               # Root: version + pattern summaries
{patternId}/
  meta.json                             # Pattern: feedUrls, playlistIds, flags
  playlists/
    {playlistId}.json                   # SmartPlaylistDefinition
```

`LocalConfigRepository` reads/writes each level as local files with atomic writes.
`ConfigAssembler` combines pattern meta + playlist files into a unified `SmartPlaylistPatternConfig`.

## Key Design Decisions

- **Hand-written JSON serialization**: No code generation; `fromJson()`/`toJson()` on every model
- **`final class` for models**: Immutable value objects throughout
- **`abstract interface class` for abstractions**: `EpisodeData`, `SmartPlaylistResolver`
- **Local-first**: Server and MCP read/write local files, no remote API calls for config operations
- **Atomic file writes**: Write to `.tmp` then rename to prevent partial reads
- **SSE for reactivity**: FileWatcherService streams changes to connected browsers
- **Schema validation at boundaries**: Validate JSON before parsing into `SmartPlaylistDefinition`
