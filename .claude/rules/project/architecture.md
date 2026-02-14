# Architecture

Dart monorepo with four workspace packages sharing models and logic.

## Package Overview

```
audiflow-smartplaylist-web/
├── packages/
│   ├── sp_shared/     # Domain models, resolvers, services (pure Dart)
│   ├── sp_server/     # REST API server (shelf)
│   └── sp_web/        # Flutter web editor (Riverpod + GoRouter)
└── mcp_server/        # MCP server for Claude integration
```

| Package | Role | Dependencies |
|---------|------|-------------|
| `sp_shared` | Shared domain layer: models, resolvers, schema, services | None (pure Dart) |
| `sp_server` | Backend API: auth, config fetching, preview, PR submission | sp_shared, shelf |
| `sp_web` | Web editor UI: pattern browsing, config editing, preview | sp_shared, Flutter |
| `mcp_server` | Exposes smart playlist operations as MCP tools | sp_shared |

## Ecosystem Context

This repo is one part of a three-component ecosystem:

```
[audiflow-smartplaylist-web]     [audiflow-smartplaylist]        [GCS]              [audiflow app]
 (this repo)              PR      (config data repo)      CI sync  (static hosting)    fetch
 sp_web  ────────────────────>  JSON files on GitHub  ──────────>  GCS bucket  <────────  audiflow_domain
 sp_server                      (source of truth)                                        (cached locally)
```

- **audiflow-smartplaylist** (data repo): Static JSON files on GitHub, source of truth
- **GCS**: Mirrors the data repo; the mobile app fetches configs from here
- **audiflow app**: Consumes configs via `audiflow_domain` with local caching
- **This repo**: Web editor that reads configs and submits changes as PRs

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
| `sortEpisodeIdsByPublishedAt` | Episode sorting utility (ascending, nulls last, stable) |

### Schema

`SmartPlaylistSchema` generates JSON Schema and validates configs at runtime.

## sp_server

Shelf-based REST API with Cascade routing.

### Routes

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `GET /api/health` | None | Health check |
| `GET /api/schema` | None | JSON Schema for configs |
| `GET /api/configs/patterns` | JWT/Key | List pattern summaries |
| `GET /api/configs/patterns/<id>` | JWT/Key | Get pattern metadata |
| `GET /api/configs/patterns/<id>/playlists/<pid>` | JWT/Key | Get playlist definition |
| `GET /api/configs/patterns/<id>/assembled` | JWT/Key | Assemble full config |
| `POST /api/configs/validate` | JWT/Key | Validate config against schema |
| `POST /api/configs/preview` | JWT/Key | Preview smart playlists from config + feed |
| `POST /api/configs/submit` | JWT | Submit config changes as PR |
| `GET /api/feeds` | JWT/Key | Fetch and parse RSS feed |
| `POST /api/drafts` | JWT/Key | Draft CRUD |
| `GET /api/auth/github` | None | OAuth flow |
| `POST /api/auth/refresh` | None | Token refresh |
| `POST /api/keys` | JWT | API key management |

### Services

| Service | Purpose |
|---------|---------|
| `ConfigRepository` | Lazy-loads configs from GitHub with TTL caching (5min root, 30min files) |
| `FeedCacheService` | Fetches/parses RSS feeds with 15min memory cache |
| `JwtService` | JWT generation and validation (access + refresh tokens) |
| `ApiKeyService` | API key CRUD |
| `GitHubOAuthService` | OAuth authorization flow |
| `GitHubAppService` | GitHub API: branches, commits, PRs via Git Trees API |
| `DraftService` | In-memory draft storage |

### PR Submission Flow

1. Validate playlist JSON against schema
2. Parse into `SmartPlaylistDefinition`
3. Create branch: `smartplaylist/{patternId}-{timestamp}`
4. Commit playlist file to `{patternId}/playlists/{playlistId}.json`
5. Commit pattern meta if provided
6. Create PR with formatted body
7. Return PR URL

### Authentication

- **JWT Bearer**: Primary auth for authenticated users
- **API Key**: Secondary auth for programmatic access
- `unifiedAuthMiddleware` accepts either
- Silent token refresh on 401 via `ApiClient` in sp_web

## sp_web

Flutter web app using Riverpod 4.x for state and GoRouter for routing.

### Routes

| Route | Screen |
|-------|--------|
| `/login` | OAuth login |
| `/browse` | Pattern listing |
| `/editor` | Create new config |
| `/editor/:id` | Edit existing pattern |
| `/settings` | API key management |

### Key Components

- `ApiClient`: HTTP wrapper with automatic JWT/API key headers and silent refresh
- `LocalDraftService`: Browser localStorage persistence for drafts
- Controllers (Riverpod): `AuthController`, `BrowseController`, `EditorController`, `PreviewController`

## Split Config Structure

Configs are stored as a three-level file hierarchy:

```
meta.json                               # Root: version + pattern summaries
{patternId}/
  meta.json                             # Pattern: feedUrls, playlistIds, flags
  playlists/
    {playlistId}.json                   # SmartPlaylistDefinition
```

`ConfigRepository` lazy-loads each level independently with TTL caching.
`ConfigAssembler` combines pattern meta + playlist files into a unified `SmartPlaylistPatternConfig`.

## Key Design Decisions

- **Hand-written JSON serialization**: No code generation; `fromJson()`/`toJson()` on every model
- **`final class` for models**: Immutable value objects throughout
- **`abstract interface class` for abstractions**: `EpisodeData`, `SmartPlaylistResolver`
- **Dependency injection via function types**: `HttpGetFn`, `GitHubHttpFn` for testability
- **TTL-based caching**: ConfigRepository caches at each level; FeedCacheService caches feeds
- **Schema validation at boundaries**: Validate JSON before parsing into `SmartPlaylistDefinition`
