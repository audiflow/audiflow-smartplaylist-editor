# Module Boundaries

## Modules

### Module: sp_core

#### Responsibilities
- Define all domain models (PatternConfig, PlaylistDefinition, SelectorConfig, GroupingConfig, GroupListingConfig, GroupItemConfig, EpisodeListingConfig, EpisodeItemConfig, Playlist, GroupDef, etc.)
- Implement resolver trait and concrete resolvers (seasonNumber, titleClassifier, year, titleDiscovery)
- Provide schema validation via embedded JSON Schema files
- Implement services: ResolverService, ConfigAssembler, sorting utilities
- Derive deterministic pattern IDs from podcast identity (`derive_pattern_id`, `is_deterministic_id`)
- Provide EpisodeData trait abstraction for episode data
- Cross-pattern uniqueness validation (`check_uniqueness` for podcastGuid and feedUrl conflicts)
- Support nested sub-groups via partitionBy logic (seasonNumber, year)

#### Non-responsibilities
- HTTP handling, routing, or request/response types
- File I/O or filesystem access
- UI concerns
- Feed fetching or caching

#### Depends on
- External crates: serde, jsonschema, regex, chrono, md5

#### Used by
- sp_server (models, resolvers, schema validation, services, uniqueness, pattern ID derivation)
- sp_cli (schema validation via sp_core::schema, uniqueness validation, deterministic ID validation)

### Module: sp_server

#### Responsibilities
- Axum REST API: config CRUD, preview, feed proxy, schema endpoint, health check, pattern identifiers, pattern ID derivation
- `POST /api/configs/derive-pattern-id`: derive deterministic pattern ID from podcastGuid/feedUrls
- Enforce deterministic ID on pattern creation
- LocalConfigRepository: read/write split config files with atomic writes
- DiskFeedCacheService: disk-based RSS feed caching with SHA-256 hashing and TTL
- FileWatcherService: watch data directory, debounce events, broadcast via SSE
- FeedParser: RSS feed parsing via feed-rs
- Static file serving (rust-embed or --static-dir) with SPA fallback
- AppError: structured JSON error responses
- Cross-pattern uniqueness enforcement on pattern create/update
- 404 JSON fallback for unmatched `/api/*` paths
- Strip resolver-irrelevant fields from preview and save responses

#### Non-responsibilities
- Domain logic (resolvers, sorting, schema definitions) -- delegated to sp_core
- CLI argument parsing -- handled by sp_cli
- Frontend rendering

#### Depends on
- sp_core (models, resolvers, schema, services, uniqueness, pattern_id)
- External crates: axum 0.8, tokio, reqwest, feed-rs, notify 7, rust-embed, tower-http

#### Used by
- sp_cli (starts server via sp_server::app)

### Module: sp_cli

#### Responsibilities
- CLI argument parsing via clap (serve, validate, format, bump-versions subcommands)
- `serve`: start sp_server with --data-dir, --host, --port, --static-dir flags
- `validate`: walk config files and validate against JSON Schema; check cross-pattern uniqueness; verify deterministic pattern ID integrity (exit codes: 0/1/2)
- `format`: normalize JSON files with --check mode for CI; supports directory arguments
- `bump-versions`: detect changed patterns via git diff and increment their dataVersion fields (CI use)
- `config_walker`: walk pattern directory tree with schema type detection

#### Non-responsibilities
- Domain logic, API routing, or file watching
- Frontend concerns

#### Depends on
- sp_core (schema validation, models, uniqueness, pattern_id)
- sp_server (app construction for serve command)
- External crates: clap, anyhow

#### Used by
- End users (as the `audiflow-editor` binary)

### Module: sp_react

#### Responsibilities
- Web editor UI: pattern browsing, config editing forms (tabbed layout with 6 categories), live preview
- Filtered episodes panel with debounced auto-preview
- API client: HTTP wrapper for sp_server REST endpoints
- Auto-derive read-only pattern ID for new configs via `useDerivedPatternId` hook (debounced, calls derive endpoint)
- State management: Zustand for editor UI state, TanStack Query for server state
- Form validation: React Hook Form + Zod 4 schemas mirroring JSON Schema
- SSE hook (`useFileEvents`): invalidate TanStack Query cache on file changes
- Inline duplicate detection for podcast identifiers (podcastGuid, feedUrls)
- Client-side episode filtering utility
- i18n: English and Japanese translations
- Playlist reorder dialog for managing priority

#### Non-responsibilities
- Backend logic, file I/O, schema definitions
- Git operations
- Domain model definitions (mirrors sp_core models via Zod schemas)

#### Depends on
- sp_server REST API (runtime dependency, not build dependency)
- External packages: React 19, TanStack Query/Router, Zustand, RHF, Zod 4, CodeMirror 6, Tailwind v4, shadcn/ui, dnd-kit, i18next

#### Used by
- End users (in the browser)

## Boundary rules

- sp_core must remain a pure library crate with no I/O or framework dependencies
- sp_server depends on sp_core but never the reverse
- sp_cli depends on both sp_core and sp_server; neither depends on sp_cli
- sp_react communicates with sp_server only via REST API; no shared code at build time
- Domain model changes in sp_core require corresponding Zod schema updates in sp_react
- JSON Schema files live in sp_core (`crates/sp_core/assets/`); sp_react mirrors them as Zod schemas

## When to update

Update when: crates or packages added/removed, dependency direction changes, responsibility shifts between modules.
