# Architecture

Rust workspace with three crates plus a React SPA.

## Package Overview

```
audiflow-smartplaylist-editor/
├── crates/
│   ├── sp_core/       # Domain models, resolvers, schema, services (pure Rust)
│   ├── sp_server/     # Local API server (axum)
│   └── sp_cli/        # CLI binary (serve, validate, format commands)
└── packages/
    └── sp_react/      # React SPA web editor (TanStack + Zustand + shadcn/ui)
```

| Crate/Package | Role | Dependencies |
|---------------|------|-------------|
| `sp_core` | Shared domain layer: models, resolvers, schema, services | serde, jsonschema, regex, chrono |
| `sp_server` | Local API server: config CRUD, preview, feed caching, file watching | sp_core, axum, tokio, notify |
| `sp_cli` | CLI binary: serve, validate, format subcommands | sp_core, sp_server, clap |
| `sp_react` | Web editor UI: pattern browsing, config editing, preview | React 19, TanStack Query/Router, Zustand, RHF, Zod, CodeMirror 6 |

## Ecosystem Context

This repo is one part of a three-component ecosystem:

```
User clones data repo locally
                |
                v
[audiflow-smartplaylist-editor]              Local data repo clone         GitHub (remote)
 (this repo)                  read/write  (on user's machine)  push    (source of truth)
 sp_server + sp_react  <────────────────>  JSON files on disk  ──────>  origin/main
                                                                CI sync
                                                                ──────>  GitHub Pages / GCS
                                                                            ^
                                                                            |
                                                                         audiflow app fetches
```

- **audiflow-smartplaylist** (data repo): Static JSON files on GitHub, source of truth
- **GitHub Pages / GCS**: Mirrors the data repo; the mobile app fetches configs from here
- **audiflow app**: Consumes configs via `audiflow_domain` with local caching
- **This repo**: Local web editor that reads/writes files in a cloned data repo

Model serialization (JSON keys, field structure) must stay aligned across all three.

## sp_core

Pure Rust library crate with no framework dependencies. All domain logic lives here.

### Models

Core types use Rust structs with `serde::Serialize`/`Deserialize`. Custom serialization uses `#[serde(...)]` attributes.

| Model | Purpose |
|-------|---------|
| `EpisodeData` | Trait for episode data; `SimpleEpisodeData` for concrete use |
| `SmartPlaylist` | A playlist containing episode IDs, with optional groups |
| `SmartPlaylistGroup` | A group within a playlist (when contentType is `groups`) |
| `SmartPlaylistGrouping` | Resolver output: playlists + ungrouped episode IDs |
| `SmartPlaylistDefinition` | Per-playlist config: resolver type, filters, extractors |
| `SmartPlaylistPatternConfig` | Per-podcast config: feed URL matching + playlist definitions |
| `PatternMeta` / `PatternSummary` / `RootMeta` | Split config metadata hierarchy |
| `SmartPlaylistSort` | Sort specification (simple or composite) |
| `SmartPlaylistGroupDef` | Static group definitions for category resolver |
| `SmartPlaylistTitleExtractor` | Regex-based display name extraction with templates and fallbacks |
| `SmartPlaylistEpisodeExtractor` | Season/episode number extraction from titles |
| `EpisodeNumberExtractor` | Episode number extraction with RSS fallback |

### Resolver Chain

Resolvers implement the `SmartPlaylistResolver` trait and group episodes by different strategies:

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
5. Return `SmartPlaylistGrouping` or `None`

Content type determines output shape:
- `episodes`: Each resolver playlist becomes a top-level `SmartPlaylist`
- `groups`: Resolver playlists become `SmartPlaylistGroup` entries inside one parent playlist

### Services

| Service | Purpose |
|---------|---------|
| `SmartPlaylistResolverService` | Resolver chain orchestrator (described above) |
| `ConfigAssembler` | Combines `PatternMeta` + playlist definitions into unified config |
| `DiskFeedCacheService` | Disk-based feed cache with SHA-256 URL hashing and configurable TTL |
| `sort_episode_ids_by_published_at` | Episode sorting utility (ascending, nulls last, stable) |

### Schema

Schema files are embedded via `include_str!` and validated at runtime using `jsonschema`.

## sp_server

Axum-based local API server with tokio async runtime. Runs on localhost only, no authentication required.

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
| `FileWatcherService` | Watch data directory for changes, emit SSE events (via `notify`) |
| `DiskFeedCacheService` (from sp_core) | Disk-based feed cache with SHA-256 URL hashing |
| `FeedParser` | RSS feed fetching and parsing (via `feed-rs`) |

### Local-First Architecture

- Server accepts `--data-dir` flag pointing to a cloned data repo
- Binds to localhost only
- No authentication required
- File changes trigger SSE events to connected browsers (via `notify` crate)
- Feed cache stored in `$dataDir/.cache/feeds/`
- Static files served via `rust-embed` or `--static-dir` flag

## sp_cli

CLI binary built with `clap`. Provides subcommands:

| Command | Purpose |
|---------|---------|
| `serve` | Start the API server with `--data-dir`, `--port`, `--static-dir` options |
| `validate` | Validate all configs in a data directory against the JSON schema |
| `format` | Format/normalize JSON config files |

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

- **Serde for JSON serialization**: Custom `#[serde(...)]` attributes for field mapping and defaults
- **Immutable structs**: Domain models are plain structs, cloned when modified
- **Trait-based abstractions**: `EpisodeData` trait, `SmartPlaylistResolver` trait
- **Local-first**: Server reads/writes local files, no remote API calls for config operations
- **Atomic file writes**: Write to `.tmp` then rename to prevent partial reads
- **SSE for reactivity**: FileWatcherService streams changes to connected browsers
- **Schema validation at boundaries**: Validate JSON via `jsonschema` crate before deserializing
- **Embedded schema files**: Schema JSON embedded in binary via `include_str!`
