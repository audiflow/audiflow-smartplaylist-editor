# Rust Rewrite Design

## Summary

Transform the editor backend from Dart to Rust. Keep the React frontend unchanged. Drop MCP server, replace with a CLI that provides validation and formatting for AI consumers.

## Binary

**Name:** `audiflow-editor`

**Subcommands:**

```
audiflow-editor serve [--data-dir <path>] [--port 8080] [--static-dir <path>]
audiflow-editor validate [--data-dir <path>] [<file>...]
audiflow-editor format [--data-dir <path>] [--check] [<file>...]
```

- `serve` — starts Axum HTTP server with embedded React assets for human users
- `validate` — validates config files against JSON schema; exit 0 = valid, 1 = errors (structured JSON on stderr), 2 = file not found
- `format` — formats config JSON in place; `--check` exits 1 if any file would change (CI use)
- `--data-dir` defaults to CWD (expects `patterns/meta.json`)
- File targeting auto-detects schema type from path structure

## Crate Layout

```
Cargo.toml                        # Workspace root
crates/
  sp_core/                        # Domain models, resolvers, services (pure Rust, no async)
    src/
      models/                     # PlaylistDefinition, PatternConfig, EpisodeData, etc.
      resolvers/                  # Rss, Category, Year, TitleAppearanceOrder
      services/                   # ResolverService, ConfigAssembler, Validator
      schema/                     # JSON Schema loading & validation
  sp_server/                      # Axum HTTP server + SSE file watcher
    src/
      routes/                     # Config CRUD, feed, preview, schema, health
      services/                   # LocalConfigRepository, FileWatcherService
      static_files.rs             # rust-embed + runtime override
  sp_cli/                         # CLI binary entry point
    src/
      main.rs
      cmd_serve.rs
      cmd_validate.rs
      cmd_format.rs
packages/
  sp_react/                       # React SPA (unchanged)
```

## Dependencies

### sp_core (pure, no async)

| Crate | Purpose |
|-------|---------|
| serde + serde_json | JSON serialization |
| regex | Episode filtering, title extraction |
| jsonschema | Schema validation |
| sha2 | Feed cache URL hashing |
| chrono | Date handling |

### sp_server

| Crate | Purpose |
|-------|---------|
| axum | HTTP framework |
| tokio | Async runtime |
| tower-http | CORS, static files middleware |
| notify | File system watching for SSE |
| rust-embed | Embed React dist/ at compile time |
| feed-rs | RSS/Atom feed parsing |
| reqwest | HTTP client for feed fetching |

### sp_cli

| Crate | Purpose |
|-------|---------|
| clap (derive) | CLI argument parsing |

## Domain Model Mapping

| Dart (sp_shared) | Rust (sp_core) |
|------------------|----------------|
| SmartPlaylistDefinition | PlaylistDefinition |
| SmartPlaylistPatternConfig | PatternConfig |
| EpisodeData (abstract interface) | trait EpisodeData + SimpleEpisodeData |
| SmartPlaylist | Playlist |
| SmartPlaylistGroup | PlaylistGroup |
| SmartPlaylistGrouping | Grouping |
| EpisodeFilters | EpisodeFilters |
| SmartPlaylistTitleExtractor | TitleExtractor |
| SmartPlaylistEpisodeExtractor | EpisodeExtractor |
| SmartPlaylistGroupDef | GroupDef |
| SmartPlaylistSortRule | SortRule |
| PatternMeta / RootMeta / PatternSummary | Same names |

All models use `#[derive(Serialize, Deserialize, Clone, Debug)]`. Optional fields use `Option<T>` with `#[serde(skip_serializing_if = "Option::is_none")]`.

Drop the `SmartPlaylist` prefix -- Rust modules provide namespacing.

## Resolvers

```rust
pub trait Resolver {
    fn resolver_type(&self) -> &str;
    fn default_sort(&self) -> SortRule;
    fn resolve(
        &self,
        episodes: &[&dyn EpisodeData],
        definition: Option<&PlaylistDefinition>,
    ) -> Option<Grouping>;
}
```

Four implementations with same algorithms as Dart:

- `RssResolver` -- groups by seasonNumber
- `CategoryResolver` -- groups by regex patterns (first match wins)
- `YearResolver` -- groups by publication year
- `TitleAppearanceOrderResolver` -- groups by title pattern in appearance order

## Server (Axum)

Same API contract as current Dart server -- no React changes needed.

### Routes

```
GET    /api/health
GET    /api/schema
GET    /api/configs/patterns
POST   /api/configs/patterns
GET    /api/configs/patterns/{id}
DELETE /api/configs/patterns/{id}
PUT    /api/configs/patterns/{id}/meta
GET    /api/configs/patterns/{id}/assembled
GET    /api/configs/patterns/{id}/playlists/{pid}
PUT    /api/configs/patterns/{id}/playlists/{pid}
DELETE /api/configs/patterns/{id}/playlists/{pid}
POST   /api/configs/validate
POST   /api/configs/preview
GET    /api/feeds
GET    /api/events
```

### Shared State

```rust
struct AppState {
    config_repo: LocalConfigRepository,
    feed_cache: DiskFeedCacheService,
    validator: Validator,
    file_watcher: FileWatcherService,
}
```

### SSE File Watching

- `notify` crate watches `patterns/` directory
- Changes broadcast via `tokio::sync::broadcast`
- Same event format as current Dart SSE -- React app unchanged

### Static File Serving

- `rust-embed` embeds `sp_react/dist/` at compile time
- `--static-dir` flag overrides with disk serving for development
- SPA fallback: unknown routes serve `index.html`

### Feed Fetching

- `reqwest` fetches RSS URLs
- `feed-rs` parses into structured Feed
- `DiskFeedCacheService` caches on disk (SHA-256 URL hash, 1hr TTL, atomic writes)

## What Gets Removed

| Current | Action |
|---------|--------|
| packages/sp_shared/ | Delete -- replaced by crates/sp_core/ |
| packages/sp_server/ | Delete -- replaced by crates/sp_server/ |
| mcp_server/ | Delete -- CLI replaces it |
| pubspec.yaml | Delete |
| analysis_options.yaml | Delete |
| Makefile | Rewrite for Rust |
| Dockerfile | Rewrite for Rust multi-stage build |

**Unchanged:** packages/sp_react/, pnpm-workspace.yaml, .claude/, docs/

## Build Workflow

```bash
# Development
cargo run -- serve --data-dir ~/path/to/data-repo    # Backend
cd packages/sp_react && pnpm dev                      # Frontend (Vite proxy)

# Production
pnpm --filter sp_react build                          # React -> dist/
cargo build --release                                 # Embeds dist/ into binary
```

## Release

GitHub Releases via `workflow_dispatch` Action. Manual trigger with version input.

**Targets:**

| Target | OS |
|--------|----|
| x86_64-apple-darwin | macOS Intel |
| aarch64-apple-darwin | macOS Apple Silicon |
| x86_64-unknown-linux-gnu | Linux x64 |
| aarch64-unknown-linux-gnu | Linux ARM64 |
| x86_64-pc-windows-msvc | Windows x64 |

Build flow: checkout -> build React -> build Rust per target -> create GitHub release with binaries.

Package manager distribution (Homebrew, crates.io) deferred to later.
