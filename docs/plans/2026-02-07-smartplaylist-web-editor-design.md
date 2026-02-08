# SmartPlaylist Web Editor - Design Document

## Overview

A standalone web service for community contributors to create and edit SmartPlaylist
configurations for Audiflow. Provides both a human-facing editor UI and an API/MCP
interface for AI agents. Completed configs are submitted as GitHub PRs to a shared
config repository.

## Key Decisions

| Decision | Choice |
|---|---|
| Audience | Community contributors |
| Stack | Dart Shelf backend + Flutter web frontend |
| Preview | Functional/structural (debug-focused) |
| Feed data | Server-side fetch with `audiflow_podcast` + caching |
| Config storage | GitHub repo as source of truth |
| Auth | GitHub OAuth (humans) + API keys (AI) |
| PR workflow | Automated via GitHub App |
| API | Full CRUD, same endpoints for human and AI |
| MCP | Thin stateless wrapper over API |
| Shared code | `sp_shared` package with `EpisodeData` interface |
| Deployment | Single server + static frontend |

## Repository Structure

New repo: `audiflow-smartplaylist-web/`

```
audiflow-smartplaylist-web/
├── packages/
│   ├── sp_shared/             # Shared models & logic
│   │   ├── lib/src/
│   │   │   ├── models/
│   │   │   │   ├── smart_playlist.dart
│   │   │   │   ├── smart_playlist_definition.dart
│   │   │   │   ├── smart_playlist_sort.dart
│   │   │   │   ├── smart_playlist_pattern_config.dart
│   │   │   │   └── episode_data.dart              # Minimal interface
│   │   │   ├── resolvers/
│   │   │   │   ├── smart_playlist_resolver.dart    # Interface
│   │   │   │   ├── rss_metadata_resolver.dart
│   │   │   │   ├── category_resolver.dart
│   │   │   │   ├── year_resolver.dart
│   │   │   │   └── title_appearance_order_resolver.dart
│   │   │   ├── services/
│   │   │   │   └── resolver_service.dart
│   │   │   ├── schema/
│   │   │   │   └── smart_playlist_schema.dart      # JSON Schema generation
│   │   │   └── loaders/
│   │   │       └── pattern_loader.dart
│   │   └── test/
│   ├── sp_server/             # Dart Shelf backend
│   │   ├── lib/src/
│   │   │   ├── routes/
│   │   │   │   ├── auth_routes.dart
│   │   │   │   ├── config_routes.dart
│   │   │   │   ├── feed_routes.dart
│   │   │   │   ├── key_routes.dart
│   │   │   │   └── schema_routes.dart
│   │   │   ├── middleware/
│   │   │   │   ├── auth_middleware.dart
│   │   │   │   ├── cors_middleware.dart
│   │   │   │   └── rate_limit_middleware.dart
│   │   │   └── services/
│   │   │       ├── github_oauth_service.dart
│   │   │       ├── github_app_service.dart         # PR creation
│   │   │       ├── feed_cache_service.dart
│   │   │       ├── config_repository.dart          # Reads from GitHub repo
│   │   │       ├── api_key_service.dart
│   │   │       └── user_service.dart
│   │   ├── bin/server.dart
│   │   └── test/
│   └── sp_web/                # Flutter web frontend
│       ├── lib/
│       │   ├── app/
│       │   │   ├── app.dart
│       │   │   └── providers.dart
│       │   ├── features/
│       │   │   ├── auth/
│       │   │   │   ├── login_screen.dart
│       │   │   │   └── auth_controller.dart
│       │   │   ├── editor/
│       │   │   │   ├── screens/editor_screen.dart
│       │   │   │   ├── widgets/
│       │   │   │   │   ├── config_form.dart
│       │   │   │   │   ├── json_editor.dart
│       │   │   │   │   ├── playlist_definition_form.dart
│       │   │   │   │   ├── regex_tester.dart
│       │   │   │   │   └── feed_url_input.dart
│       │   │   │   └── controllers/editor_controller.dart
│       │   │   ├── preview/
│       │   │   │   ├── widgets/
│       │   │   │   │   ├── preview_panel.dart
│       │   │   │   │   ├── playlist_tree.dart
│       │   │   │   │   └── debug_info_panel.dart
│       │   │   │   └── controllers/preview_controller.dart
│       │   │   └── settings/
│       │   │       ├── screens/settings_screen.dart
│       │   │       └── widgets/api_key_manager.dart
│       │   └── routing/
│       │       └── app_router.dart
│       └── web/
│           └── index.html
├── mcp_server/                # MCP server binary
│   ├── lib/src/
│   │   └── tools/
│   │       ├── search_configs_tool.dart
│   │       ├── get_config_tool.dart
│   │       ├── get_schema_tool.dart
│   │       ├── fetch_feed_tool.dart
│   │       ├── validate_config_tool.dart
│   │       ├── preview_config_tool.dart
│   │       └── submit_config_tool.dart
│   └── bin/mcp_server.dart
└── pubspec.yaml               # Workspace root
```

## Config Repository

Separate GitHub repo: `audiflow/smartplaylist-configs`

```
smartplaylist-configs/
├── configs/
│   ├── coten-radio.json
│   ├── rebuild-fm.json
│   └── ...
├── schema/
│   └── smart-playlist-pattern.schema.json
└── index.json                 # Auto-generated manifest
```

GitHub serves as the source of truth for configs. Version history, review workflow,
and contributor attribution come for free.

## Authentication

### Human Users - GitHub OAuth

1. User clicks "Sign in with GitHub" on the web frontend
2. Redirect to GitHub OAuth authorization URL
3. GitHub redirects back with authorization code
4. Server exchanges code for access token
5. Server creates/updates user record, issues session JWT
6. JWT stored in browser, sent as `Authorization: Bearer <jwt>`
7. OAuth token stored server-side for PR creation

### AI Agents - API Keys

1. Authenticated user visits Settings page
2. Clicks "Generate API Key"
3. Server generates random key, stores bcrypt hash, returns plaintext once
4. AI sends `X-API-Key: sp_key_...` header on requests
5. Keys can be revoked from Settings page

## API Endpoints

```
# Auth
POST   /api/auth/github/callback     # OAuth callback
GET    /api/auth/me                   # Current user info

# API Keys
POST   /api/keys                      # Generate API key
DELETE /api/keys/:id                  # Revoke API key

# Feeds
GET    /api/feeds?url=<feed_url>      # Fetch & parse RSS feed (cached)

# Configs
GET    /api/configs                   # List all configs from repo
GET    /api/configs/:id               # Get specific config
POST   /api/configs/validate          # Validate config against schema
POST   /api/configs/preview           # Run resolvers, return grouping results
POST   /api/configs/submit            # Create PR with config

# Schema
GET    /api/schema                    # JSON Schema for SmartPlaylistPatternConfig
```

Both human UI and AI agents use the same endpoints. The only difference is
the auth mechanism (JWT vs API key).

## Shared Package Extraction (`sp_shared`)

Extracted from `audiflow_domain` SmartPlaylist models and resolvers, removing
Drift and Riverpod dependencies.

### EpisodeData Interface

Resolvers currently take Drift-generated `Episode` objects. In `sp_shared`, a
minimal interface decouples resolvers from any specific data source:

```dart
abstract class EpisodeData {
  int get id;
  String get title;
  String? get description;
  int? get seasonNumber;
  int? get episodeNumber;
  DateTime? get publishedAt;
  String? get imageUrl;
}
```

Both the audiflow app (wrapping Drift `Episode`) and the web service (wrapping
parsed RSS data from `audiflow_podcast`) implement this interface.

### What Moves to sp_shared

| Current audiflow_domain location | sp_shared location |
|---|---|
| `smart_playlist.dart` (models) | `models/smart_playlist.dart` (freezed, no Drift) |
| `smart_playlist_definition.dart` | `models/smart_playlist_definition.dart` |
| `smart_playlist_sort.dart` | `models/smart_playlist_sort.dart` |
| `smart_playlist_pattern_config.dart` | `models/smart_playlist_pattern_config.dart` |
| `smart_playlist_resolver_service.dart` | `services/resolver_service.dart` (no Riverpod) |
| All resolvers | `resolvers/` |
| `smart_playlist_pattern_loader.dart` | `loaders/pattern_loader.dart` |

### What Stays in audiflow_domain

- Drift tables (`SmartPlaylists`, `SmartPlaylistGroups`)
- Local datasource (database queries)
- Riverpod providers
- Thumbnail/metadata enrichment tied to app's episode model

### Impact on audiflow Monorepo

The audiflow app depends on `sp_shared` (via git dependency) instead of having
its own copy of models and resolvers. This is a refactor but improves
maintainability: one source of truth for SmartPlaylist logic.

## Editor UI

### Layout

```
+--------------------------------------------------+
|  Feed URL: [https://anchor.fm/...]  [Load Feed]  |
+------------------------+-------------------------+
|                        |                         |
|   Config Editor        |   Preview Panel         |
|                        |                         |
|   Pattern Info         |   Playlists             |
|   - ID, Feed URLs      |   > Season 1 (12 eps)  |
|   - Podcast GUID       |   > Season 2 (8 eps)   |
|                        |   > Specials (3 eps)    |
|   Playlists            |                         |
|   + Add Playlist       |   Ungrouped (2)         |
|   > Playlist 1         |   - Episode: "Bonus..." |
|     resolverType       |   - Episode: "Live..."  |
|     titleFilter        |                         |
|     groups...          |   Debug Info            |
|                        |   - Resolver: rss       |
|   [JSON view toggle]   |   - Filter matched: 23  |
|                        |   - Excluded: 2         |
|   Raw JSON             |   - Unclaimed: 2        |
|   { "id": "..."        |                         |
|     ...                |                         |
+------------------------+-------------------------+
|            [Save Draft]  [Submit as PR]           |
+--------------------------------------------------+
```

### Key Features

- **Form mode + JSON mode toggle**: Form mode for visual editing with dropdowns
  (resolverType, contentType, yearHeaderMode). JSON mode for power users and
  AI-assisted editing.
- **Live preview**: Resolvers run client-side on every config change. Shows
  resulting playlist tree with episode counts.
- **Debug panel**: Shows which episodes matched/excluded by each filter regex,
  which resolver was used, and ungrouped episodes.
- **Schema reference**: Sidebar link or tooltip showing field descriptions from
  JSON Schema.
- **Regex tester**: Inline regex match highlighting against episode titles when
  editing titleFilter/excludeFilter fields.

Preview updates live as the user types. Resolvers run client-side in Flutter web
using `sp_shared`, so no server round-trips are needed during editing.

## MCP Server

Thin stateless wrapper over the API. Runs as a stdio-transport MCP server that
AI tools can connect to.

### Tools

```
smartplaylist.search_configs     # Find configs by feed URL or podcast name
smartplaylist.get_config         # Get a specific config by ID
smartplaylist.get_schema         # Get JSON Schema for SmartPlaylistPatternConfig
smartplaylist.fetch_feed         # Fetch and parse RSS feed, return episode list
smartplaylist.validate_config    # Validate config JSON against schema
smartplaylist.preview_config     # Run resolvers, return grouping results
smartplaylist.submit_config      # Create/update config and open PR
```

### Resources

```
smartplaylist://schema           # JSON Schema (readable reference)
smartplaylist://configs          # List of all configs
smartplaylist://configs/{id}     # Specific config
```

### Auth

API key configured via environment variable in MCP server config:

```json
{
  "mcpServers": {
    "smartplaylist": {
      "command": "sp-mcp-server",
      "env": { "SP_API_KEY": "sp_key_..." }
    }
  }
}
```

## Deployment

### Backend (sp_server)

- Compiled to native Dart AOT binary (`dart compile exe`)
- Deployed to a single VPS (Fly.io, Railway, or similar)
- SQLite for storage (users, API keys, feed cache, drafts)
- Environment variables: GitHub OAuth client ID/secret, GitHub App private key,
  JWT secret

### Frontend (sp_web)

- Built with `flutter build web`
- Served from the same server or a CDN (Cloudflare Pages)
- Backend URL configured at build time

### GitHub App

- Installed on the `smartplaylist-configs` repo only
- Permissions: contents (write), pull requests (write)
- PRs created as the GitHub App, attributed to the contributor via
  `Co-authored-by` trailer

### MCP Server

- Distributed as a Dart AOT binary or published to pub.dev
- Users download and configure locally
- Communicates with the hosted `sp_server` API

## Data Flow

### Editing Flow

1. User enters a feed URL
2. Server fetches and caches the RSS feed (reuses `audiflow_podcast` parser)
3. Server returns parsed episode list to the frontend
4. User loads existing config from GitHub repo or starts a new one
5. User edits config in form or JSON mode
6. Preview panel runs resolvers client-side (using `sp_shared`) on every change
7. Debug panel shows filter matches, resolver type, ungrouped episodes
8. User clicks "Submit as PR"
9. Server creates a branch on the config repo, commits the config, opens a PR
10. Maintainer reviews and merges the PR

### AI Editing Flow

1. AI reads the schema resource to understand config format
2. AI calls `fetch_feed` with a podcast URL to get episodes
3. AI analyzes episode titles and metadata to determine patterns
4. AI drafts a config, calls `validate_config` to check correctness
5. AI calls `preview_config` to verify grouping results
6. AI calls `submit_config` to open a PR

## Server-Side Storage (SQLite)

Minimal storage for operational data only. Configs live in the GitHub repo.

| Table | Purpose |
|---|---|
| `users` | GitHub ID, display name, avatar URL, OAuth token (encrypted) |
| `api_keys` | User ID, key hash (bcrypt), label, created/revoked timestamps |
| `feed_cache` | Feed URL, parsed episode data (JSON), fetched_at, etag |
| `drafts` | User ID, config JSON, feed URL, updated_at |

## JSON Schema

A `SmartPlaylistPatternConfig` JSON Schema will be generated from the Dart
model definitions in `sp_shared`. This schema serves as:

- Validation for the editor (both form and JSON modes)
- Documentation for contributors (field descriptions, enums, examples)
- Reference for AI agents (via MCP resource or API endpoint)
- CI validation in the config repository (GitHub Action validates PRs)

## Future Considerations

- **Config auto-detection**: Analyze a feed's episode metadata and suggest
  resolver types and filter patterns automatically.
- **Config testing in CI**: GitHub Action that runs resolvers against live feeds
  to verify configs still produce expected groupings.
- **Audiflow app integration**: Mobile app fetches configs from the GitHub repo
  (or a CDN mirror) instead of bundling them in the asset.
