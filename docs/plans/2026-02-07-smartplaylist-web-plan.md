# SmartPlaylist Web Editor - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a standalone web service for community contributors to create/edit SmartPlaylist configs, with API/MCP support and GitHub PR workflow.

**Architecture:** Dart Shelf backend + Flutter web frontend + MCP server. Shared `sp_shared` package extracts SmartPlaylist models/resolvers from audiflow_domain. GitHub repo as source of truth for configs, GitHub OAuth for auth, API keys for AI.

**Tech Stack:** Dart 3.10+, Flutter 3.38+ (web), Shelf, Riverpod, audiflow_podcast, GitHub OAuth/API, SQLite (drift for server), MCP SDK (dart_mcp)

**Design doc:** `docs/plans/2026-02-07-smartplaylist-web-editor-design.md`

---

## Phase 1: Project Scaffolding & sp_shared Package

### Task 1: Initialize workspace and package structure

**Files:**
- Create: `~/Documents/src/projects/audiflow-smartplaylist-web/pubspec.yaml`
- Create: `~/Documents/src/projects/audiflow-smartplaylist-web/melos.yaml`
- Create: `~/Documents/src/projects/audiflow-smartplaylist-web/packages/sp_shared/pubspec.yaml`
- Create: `~/Documents/src/projects/audiflow-smartplaylist-web/packages/sp_server/pubspec.yaml`
- Create: `~/Documents/src/projects/audiflow-smartplaylist-web/packages/sp_web/pubspec.yaml`
- Create: `~/Documents/src/projects/audiflow-smartplaylist-web/mcp_server/pubspec.yaml`

**Step 1: Create directory structure**

```bash
mkdir -p ~/Documents/src/projects/audiflow-smartplaylist-web/packages/{sp_shared,sp_server,sp_web}
mkdir -p ~/Documents/src/projects/audiflow-smartplaylist-web/mcp_server
```

**Step 2: Initialize git and create workspace pubspec.yaml**

```yaml
# ~/Documents/src/projects/audiflow-smartplaylist-web/pubspec.yaml
name: audiflow_smartplaylist_web_workspace
publish_to: none

workspace:
  - packages/sp_shared
  - packages/sp_server
  - packages/sp_web
  - mcp_server

environment:
  sdk: ^3.10.0
```

**Step 3: Create sp_shared pubspec.yaml**

```yaml
# packages/sp_shared/pubspec.yaml
name: sp_shared
description: Shared SmartPlaylist models, resolvers, and schema
publish_to: none
resolution: workspace

environment:
  sdk: ^3.10.0

dependencies:
  json_annotation: ^4.9.0
  meta: ^1.16.0

dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.9.0
  test: ^1.25.0
```

**Step 4: Create sp_server pubspec.yaml (minimal for now)**

```yaml
# packages/sp_server/pubspec.yaml
name: sp_server
description: SmartPlaylist web editor backend
publish_to: none
resolution: workspace

environment:
  sdk: ^3.10.0

dependencies:
  sp_shared:
    path: ../sp_shared
  shelf: ^1.4.0
  shelf_router: ^1.1.0
```

**Step 5: Create sp_web pubspec.yaml (minimal Flutter web app)**

Use `mcp__dart-mcp-server__create_project` for sp_web since it's a Flutter app.

**Step 6: Create mcp_server pubspec.yaml (minimal for now)**

```yaml
# mcp_server/pubspec.yaml
name: sp_mcp_server
description: MCP server for SmartPlaylist web editor
publish_to: none
resolution: workspace

environment:
  sdk: ^3.10.0

dependencies:
  sp_shared:
    path: ../packages/sp_shared
```

**Step 7: Initialize git repo**

```bash
cd ~/Documents/src/projects/audiflow-smartplaylist-web
jj git init
```

**Step 8: Run `dart pub get` in workspace root**

**Step 9: Commit**

```
chore: initialize workspace with sp_shared, sp_server, sp_web, mcp_server
```

---

### Task 2: Create EpisodeData interface in sp_shared

The current `EpisodeData` in audiflow_core has only 4 fields (`title`, `description`, `seasonNumber`, `episodeNumber`). Resolvers also need `id`, `publishedAt`, and `imageUrl`. Create an expanded interface for sp_shared.

**Files:**
- Create: `packages/sp_shared/lib/src/models/episode_data.dart`
- Test: `packages/sp_shared/test/models/episode_data_test.dart`

**Step 1: Write the test**

```dart
// packages/sp_shared/test/models/episode_data_test.dart
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SimpleEpisodeData', () {
    test('stores all fields', () {
      final episode = SimpleEpisodeData(
        id: 42,
        title: 'Episode 1',
        description: 'First episode',
        seasonNumber: 1,
        episodeNumber: 1,
        publishedAt: DateTime(2025, 1, 15),
        imageUrl: 'https://example.com/img.jpg',
      );

      expect(episode.id, 42);
      expect(episode.title, 'Episode 1');
      expect(episode.description, 'First episode');
      expect(episode.seasonNumber, 1);
      expect(episode.episodeNumber, 1);
      expect(episode.publishedAt, DateTime(2025, 1, 15));
      expect(episode.imageUrl, 'https://example.com/img.jpg');
    });

    test('nullable fields default to null', () {
      final episode = SimpleEpisodeData(id: 1, title: 'Test');

      expect(episode.description, isNull);
      expect(episode.seasonNumber, isNull);
      expect(episode.episodeNumber, isNull);
      expect(episode.publishedAt, isNull);
      expect(episode.imageUrl, isNull);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `dart test packages/sp_shared/test/models/episode_data_test.dart`
Expected: FAIL - sp_shared package doesn't exist yet

**Step 3: Implement EpisodeData**

```dart
// packages/sp_shared/lib/src/models/episode_data.dart

/// Interface for episode data used by SmartPlaylist resolvers and extractors.
///
/// Abstracts away the storage layer (Drift, RSS parsed data, etc.)
/// so resolvers work with any episode source.
abstract interface class EpisodeData {
  /// Unique episode identifier.
  int get id;

  /// Episode title.
  String get title;

  /// Episode description (optional).
  String? get description;

  /// Season number from RSS metadata (optional).
  int? get seasonNumber;

  /// Episode number from RSS metadata (optional).
  int? get episodeNumber;

  /// Publication date (optional).
  DateTime? get publishedAt;

  /// Episode artwork URL (optional).
  String? get imageUrl;
}

/// Simple implementation of [EpisodeData] for testing and web service use.
final class SimpleEpisodeData implements EpisodeData {
  const SimpleEpisodeData({
    required this.id,
    required this.title,
    this.description,
    this.seasonNumber,
    this.episodeNumber,
    this.publishedAt,
    this.imageUrl,
  });

  @override
  final int id;
  @override
  final String title;
  @override
  final String? description;
  @override
  final int? seasonNumber;
  @override
  final int? episodeNumber;
  @override
  final DateTime? publishedAt;
  @override
  final String? imageUrl;
}
```

**Step 4: Create barrel export**

```dart
// packages/sp_shared/lib/sp_shared.dart
library;

export 'src/models/episode_data.dart';
```

**Step 5: Run test to verify it passes**

**Step 6: Commit**

```
feat(sp_shared): add EpisodeData interface with SimpleEpisodeData
```

---

### Task 3: Port SmartPlaylist models to sp_shared

Copy pure-Dart models from audiflow_domain. These have no Drift/Riverpod dependencies.

**Source files (audiflow_domain):**
- `packages/audiflow_domain/lib/src/features/feed/models/smart_playlist.dart` (191 lines)
- `packages/audiflow_domain/lib/src/features/feed/models/smart_playlist_definition.dart` (150 lines)
- `packages/audiflow_domain/lib/src/features/feed/models/smart_playlist_group_def.dart` (57 lines)
- `packages/audiflow_domain/lib/src/features/feed/models/smart_playlist_sort.dart` (154 lines)
- `packages/audiflow_domain/lib/src/features/feed/models/smart_playlist_pattern_config.dart` (68 lines)
- `packages/audiflow_domain/lib/src/features/feed/models/smart_playlist_pattern.dart` (87 lines)
- `packages/audiflow_domain/lib/src/features/feed/models/smart_playlist_title_extractor.dart` (165 lines)
- `packages/audiflow_domain/lib/src/features/feed/models/smart_playlist_episode_extractor.dart` (181 lines)

**Target files (sp_shared):**
- Create: `packages/sp_shared/lib/src/models/smart_playlist.dart`
- Create: `packages/sp_shared/lib/src/models/smart_playlist_definition.dart`
- Create: `packages/sp_shared/lib/src/models/smart_playlist_group_def.dart`
- Create: `packages/sp_shared/lib/src/models/smart_playlist_sort.dart`
- Create: `packages/sp_shared/lib/src/models/smart_playlist_pattern_config.dart`
- Create: `packages/sp_shared/lib/src/models/smart_playlist_pattern.dart`
- Create: `packages/sp_shared/lib/src/models/smart_playlist_title_extractor.dart`
- Create: `packages/sp_shared/lib/src/models/smart_playlist_episode_extractor.dart`

**Step 1: Copy model files, adjusting imports**

For each file:
- Replace `import '../../../common/database/app_database.dart'` with `import 'episode_data.dart'`
- Replace `import 'package:audiflow_core/audiflow_core.dart'` with `import 'episode_data.dart'`
- Replace references to `Episode` with `EpisodeData` in extractors
- All these models are already pure Dart - no Drift annotations

**Step 2: Port existing tests from audiflow_domain**

Copy test files from `packages/audiflow_domain/test/features/feed/` that test these models:
- `smart_playlist_test.dart`
- `smart_playlist_definition_test.dart`
- `smart_playlist_group_def_test.dart`
- `smart_playlist_sort_test.dart`
- `smart_playlist_sort_json_test.dart`
- `smart_playlist_pattern_config_test.dart`
- `smart_playlist_episode_extractor_test.dart`
- `smart_playlist_title_extractor_test.dart`

Adjust imports to use `package:sp_shared/sp_shared.dart`.

**Step 3: Update barrel export to include all models**

**Step 4: Run tests**

Run: `dart test packages/sp_shared/`
Expected: All model tests pass

**Step 5: Commit**

```
feat(sp_shared): port SmartPlaylist models from audiflow_domain
```

---

### Task 4: Port resolvers to sp_shared

Resolvers currently take `List<Episode>` (Drift). Refactor to `List<EpisodeData>`.

**Source files:**
- `packages/audiflow_domain/lib/src/features/feed/resolvers/smart_playlist_resolver.dart`
- `packages/audiflow_domain/lib/src/features/feed/resolvers/rss_metadata_resolver.dart`
- `packages/audiflow_domain/lib/src/features/feed/resolvers/category_resolver.dart`
- `packages/audiflow_domain/lib/src/features/feed/resolvers/year_resolver.dart`
- `packages/audiflow_domain/lib/src/features/feed/resolvers/title_appearance_order_resolver.dart`

**Target files:**
- Create: `packages/sp_shared/lib/src/resolvers/smart_playlist_resolver.dart`
- Create: `packages/sp_shared/lib/src/resolvers/rss_metadata_resolver.dart`
- Create: `packages/sp_shared/lib/src/resolvers/category_resolver.dart`
- Create: `packages/sp_shared/lib/src/resolvers/year_resolver.dart`
- Create: `packages/sp_shared/lib/src/resolvers/title_appearance_order_resolver.dart`

**Key changes for each resolver:**

1. `SmartPlaylistResolver` interface: `resolve(List<Episode>...)` becomes `resolve(List<EpisodeData>...)`
2. All resolver implementations: `Episode` becomes `EpisodeData`
3. `episode.toEpisodeData()` calls become unnecessary (episodes already are `EpisodeData`)
4. Remove `import '../../../common/database/app_database.dart'`
5. Remove `import '../extensions/episode_extensions.dart'`

**Step 1: Port resolver interface and implementations**

**Step 2: Port existing resolver tests**

Source: `packages/audiflow_domain/test/features/feed/resolvers/`
- `rss_metadata_resolver_test.dart`
- `category_resolver_test.dart`
- `year_resolver_test.dart`
- `title_appearance_order_resolver_test.dart`

In tests, replace Episode mock objects with `SimpleEpisodeData(...)`.

**Step 3: Run tests**

Run: `dart test packages/sp_shared/`
Expected: All resolver tests pass

**Step 4: Commit**

```
feat(sp_shared): port SmartPlaylist resolvers with EpisodeData interface
```

---

### Task 5: Port resolver service and pattern loader to sp_shared

**Source files:**
- `packages/audiflow_domain/lib/src/features/feed/services/smart_playlist_resolver_service.dart` (227 lines)
- `packages/audiflow_domain/lib/src/features/feed/services/smart_playlist_pattern_loader.dart` (38 lines)

**Target files:**
- Create: `packages/sp_shared/lib/src/services/smart_playlist_resolver_service.dart`
- Create: `packages/sp_shared/lib/src/services/smart_playlist_pattern_loader.dart`

**Key changes:**
- `SmartPlaylistResolverService`: Replace all `Episode` with `EpisodeData`
- `SmartPlaylistPatternLoader`: Already pure Dart, copy as-is

**Step 1: Port service files**

**Step 2: Port tests**

Source:
- `packages/audiflow_domain/test/features/feed/services/smart_playlist_resolver_service_test.dart`
- `packages/audiflow_domain/test/features/feed/services/smart_playlist_pattern_loader_test.dart`

**Step 3: Run all tests**

Run: `dart test packages/sp_shared/`
Expected: All tests pass

**Step 4: Commit**

```
feat(sp_shared): port resolver service and pattern loader
```

---

### Task 6: Generate JSON Schema for SmartPlaylistPatternConfig

Create a JSON Schema that describes the config format. This serves as documentation, validation, and AI reference.

**Files:**
- Create: `packages/sp_shared/lib/src/schema/smart_playlist_schema.dart`
- Create: `packages/sp_shared/test/schema/smart_playlist_schema_test.dart`

**Step 1: Write the test**

```dart
import 'dart:convert';
import 'package:sp_shared/sp_shared.dart';
import 'package:test/test.dart';

void main() {
  group('SmartPlaylistSchema', () {
    test('generates valid JSON Schema', () {
      final schema = SmartPlaylistSchema.generate();
      final decoded = jsonDecode(schema) as Map<String, dynamic>;

      expect(decoded[r'$schema'], contains('json-schema.org'));
      expect(decoded['type'], 'object');
      expect(decoded['properties'], containsPair('version', isA<Map>()));
      expect(decoded['properties'], containsPair('patterns', isA<Map>()));
    });

    test('validates a known-good config', () {
      final config = {
        'version': 1,
        'patterns': [
          {
            'id': 'test',
            'feedUrlPatterns': ['test\\.com'],
            'playlists': [
              {
                'id': 'main',
                'displayName': 'Main',
                'resolverType': 'rss',
                'priority': 100,
              }
            ],
          }
        ],
      };
      expect(SmartPlaylistSchema.validate(jsonEncode(config)), isEmpty);
    });
  });
}
```

**Step 2: Implement schema generation**

Hand-craft a JSON Schema matching the `SmartPlaylistPatternConfig` structure. Include `description` fields for every property to help contributors and AI understand each field.

**Step 3: Run tests and commit**

```
feat(sp_shared): add JSON Schema generation for SmartPlaylist config
```

---

### Task 7: Finalize sp_shared barrel export and analyze

**Files:**
- Modify: `packages/sp_shared/lib/sp_shared.dart`

**Step 1: Add all exports**

```dart
library;

// Models
export 'src/models/episode_data.dart';
export 'src/models/smart_playlist.dart';
export 'src/models/smart_playlist_definition.dart';
export 'src/models/smart_playlist_group_def.dart';
export 'src/models/smart_playlist_sort.dart';
export 'src/models/smart_playlist_pattern.dart';
export 'src/models/smart_playlist_pattern_config.dart';
export 'src/models/smart_playlist_title_extractor.dart';
export 'src/models/smart_playlist_episode_extractor.dart';

// Resolvers
export 'src/resolvers/smart_playlist_resolver.dart';
export 'src/resolvers/rss_metadata_resolver.dart';
export 'src/resolvers/category_resolver.dart';
export 'src/resolvers/year_resolver.dart';
export 'src/resolvers/title_appearance_order_resolver.dart';

// Services
export 'src/services/smart_playlist_resolver_service.dart';
export 'src/services/smart_playlist_pattern_loader.dart';

// Schema
export 'src/schema/smart_playlist_schema.dart';
```

**Step 2: Run analysis**

Run: `dart analyze packages/sp_shared/`
Expected: Zero issues

**Step 3: Run all tests**

Run: `dart test packages/sp_shared/`
Expected: All tests pass

**Step 4: Commit**

```
chore(sp_shared): finalize exports and verify zero analysis issues
```

---

## Phase 2: Backend (sp_server)

### Task 8: Set up Shelf server with CORS and health check

**Files:**
- Create: `packages/sp_server/bin/server.dart`
- Create: `packages/sp_server/lib/src/middleware/cors_middleware.dart`
- Create: `packages/sp_server/lib/src/routes/health_routes.dart`
- Test: `packages/sp_server/test/routes/health_routes_test.dart`

**Step 1: Write health check test**

Test that `GET /api/health` returns 200 with `{"status": "ok"}`.

**Step 2: Implement health route and CORS middleware**

**Step 3: Run server locally, verify health check**

Run: `dart run packages/sp_server/bin/server.dart`
Test: `curl http://localhost:8080/api/health`
Expected: `{"status": "ok"}`

**Step 4: Commit**

```
feat(sp_server): add Shelf server with CORS and health check
```

---

### Task 9: GitHub OAuth authentication

**Files:**
- Create: `packages/sp_server/lib/src/services/github_oauth_service.dart`
- Create: `packages/sp_server/lib/src/routes/auth_routes.dart`
- Create: `packages/sp_server/lib/src/middleware/auth_middleware.dart`
- Create: `packages/sp_server/lib/src/models/user.dart`
- Create: `packages/sp_server/lib/src/services/user_service.dart`

**Endpoints:**
- `GET /api/auth/github` - Redirect to GitHub OAuth
- `GET /api/auth/github/callback` - Handle callback, create user, return JWT
- `GET /api/auth/me` - Return current user info

**Step 1: Implement GitHub OAuth service** (exchanges code for token, fetches user info)

**Step 2: Implement JWT-based session middleware**

**Step 3: Implement user storage** (SQLite via drift or raw sqlite3)

**Step 4: Write integration tests with mocked GitHub API**

**Step 5: Commit**

```
feat(sp_server): add GitHub OAuth authentication with JWT sessions
```

---

### Task 10: API key management

**Files:**
- Create: `packages/sp_server/lib/src/routes/key_routes.dart`
- Create: `packages/sp_server/lib/src/services/api_key_service.dart`
- Create: `packages/sp_server/lib/src/middleware/api_key_middleware.dart`

**Endpoints:**
- `POST /api/keys` - Generate new API key (returns plaintext once)
- `GET /api/keys` - List user's keys (masked)
- `DELETE /api/keys/:id` - Revoke a key

**Step 1: Implement API key generation** (random bytes, bcrypt hash stored)

**Step 2: Implement API key auth middleware** (X-API-Key header)

**Step 3: Unify auth** - requests authenticate via JWT OR API key

**Step 4: Write tests**

**Step 5: Commit**

```
feat(sp_server): add API key generation and authentication
```

---

### Task 11: Feed fetching and caching

**Files:**
- Create: `packages/sp_server/lib/src/routes/feed_routes.dart`
- Create: `packages/sp_server/lib/src/services/feed_cache_service.dart`

**Endpoint:**
- `GET /api/feeds?url=<feed_url>` - Fetch RSS feed, parse with audiflow_podcast, cache, return episode list

**Dependencies to add:** `audiflow_podcast` (git dependency from audiflow repo)

**Step 1: Add audiflow_podcast dependency to sp_server**

**Step 2: Implement feed cache** (SQLite table: url, parsed_data, etag, fetched_at)

**Step 3: Implement feed route** (fetch if not cached or stale, parse, return JSON)

**Step 4: Write tests with mock HTTP**

**Step 5: Commit**

```
feat(sp_server): add RSS feed fetching with caching
```

---

### Task 12: Config CRUD (reads from GitHub repo)

**Files:**
- Create: `packages/sp_server/lib/src/routes/config_routes.dart`
- Create: `packages/sp_server/lib/src/services/config_repository.dart`

**Endpoints:**
- `GET /api/configs` - List all configs (fetches index.json from GitHub repo)
- `GET /api/configs/:id` - Get specific config
- `POST /api/configs/validate` - Validate against JSON Schema
- `POST /api/configs/preview` - Run resolvers, return grouping results with debug info

**Step 1: Implement config repository** (reads from GitHub API or raw.githubusercontent.com)

**Step 2: Implement preview endpoint** (fetches feed, runs resolvers from sp_shared, returns debug info)

**Step 3: Implement validation endpoint** (uses SmartPlaylistSchema from sp_shared)

**Step 4: Write tests**

**Step 5: Commit**

```
feat(sp_server): add config listing, validation, and preview endpoints
```

---

### Task 13: Schema endpoint

**Files:**
- Create: `packages/sp_server/lib/src/routes/schema_routes.dart`

**Endpoint:**
- `GET /api/schema` - Return JSON Schema

**Step 1: Implement** (trivial - returns SmartPlaylistSchema.generate())

**Step 2: Commit**

```
feat(sp_server): add schema endpoint
```

---

### Task 14: PR submission via GitHub App

**Files:**
- Create: `packages/sp_server/lib/src/services/github_app_service.dart`
- Modify: `packages/sp_server/lib/src/routes/config_routes.dart`

**Endpoint:**
- `POST /api/configs/submit` - Create branch, commit config, open PR

**Step 1: Implement GitHub App JWT generation** (signs with private key)

**Step 2: Implement PR creation flow:**
- Create branch `smartplaylist/<config-id>-<timestamp>`
- Create/update config file via GitHub Contents API
- Open PR with description and contributor attribution

**Step 3: Write tests with mocked GitHub API**

**Step 4: Commit**

```
feat(sp_server): add PR submission via GitHub App
```

---

### Task 15: Draft config storage

**Files:**
- Create: `packages/sp_server/lib/src/routes/draft_routes.dart`
- Create: `packages/sp_server/lib/src/services/draft_service.dart`

**Endpoints:**
- `POST /api/drafts` - Save draft config
- `GET /api/drafts` - List user's drafts
- `GET /api/drafts/:id` - Get specific draft
- `DELETE /api/drafts/:id` - Delete draft

**Step 1: Implement draft storage** (SQLite: user_id, config_json, feed_url, updated_at)

**Step 2: Write tests**

**Step 3: Commit**

```
feat(sp_server): add draft config storage
```

---

## Phase 3: Flutter Web Frontend (sp_web)

### Task 16: Set up Flutter web app with routing and auth

**Files:**
- Modify: `packages/sp_web/lib/main.dart`
- Create: `packages/sp_web/lib/app/app.dart`
- Create: `packages/sp_web/lib/app/providers.dart`
- Create: `packages/sp_web/lib/routing/app_router.dart`
- Create: `packages/sp_web/lib/features/auth/screens/login_screen.dart`
- Create: `packages/sp_web/lib/features/auth/controllers/auth_controller.dart`

**Routes:**
- `/login` - GitHub OAuth login
- `/editor` - Main editor (protected)
- `/editor/:id` - Edit existing config (protected)
- `/settings` - User settings (protected)

**Step 1: Configure GoRouter with auth redirect**

**Step 2: Implement login screen** (GitHub OAuth button)

**Step 3: Implement auth controller** (manages JWT, redirects)

**Step 4: Verify login flow works in browser**

**Step 5: Commit**

```
feat(sp_web): add Flutter web app with GitHub OAuth and routing
```

---

### Task 17: Editor screen - config form

**Files:**
- Create: `packages/sp_web/lib/features/editor/screens/editor_screen.dart`
- Create: `packages/sp_web/lib/features/editor/widgets/feed_url_input.dart`
- Create: `packages/sp_web/lib/features/editor/widgets/config_form.dart`
- Create: `packages/sp_web/lib/features/editor/widgets/playlist_definition_form.dart`
- Create: `packages/sp_web/lib/features/editor/widgets/json_editor.dart`
- Create: `packages/sp_web/lib/features/editor/controllers/editor_controller.dart`

**Step 1: Build feed URL input** (text field + "Load Feed" button)

**Step 2: Build config form** (pattern info: ID, feed URL patterns, podcast GUID)

**Step 3: Build playlist definition form** (resolverType dropdown, filters, groups)

**Step 4: Build JSON editor toggle** (switch between form and raw JSON)

**Step 5: Wire up editor controller** (loads feed, manages config state)

**Step 6: Commit**

```
feat(sp_web): add SmartPlaylist editor with form and JSON modes
```

---

### Task 18: Preview panel

**Files:**
- Create: `packages/sp_web/lib/features/preview/widgets/preview_panel.dart`
- Create: `packages/sp_web/lib/features/preview/widgets/playlist_tree.dart`
- Create: `packages/sp_web/lib/features/preview/widgets/debug_info_panel.dart`
- Create: `packages/sp_web/lib/features/preview/controllers/preview_controller.dart`

**Step 1: Build playlist tree widget** (expandable tree: playlists > groups > episodes)

**Step 2: Build debug info panel** (filter match counts, resolver type, ungrouped episodes)

**Step 3: Wire up preview controller** (runs resolvers from sp_shared client-side on config changes)

**Step 4: Integrate with editor** (side-by-side layout, live updates)

**Step 5: Commit**

```
feat(sp_web): add live preview panel with debug info
```

---

### Task 19: Regex tester widget

**Files:**
- Create: `packages/sp_web/lib/features/editor/widgets/regex_tester.dart`

**Step 1: Build inline regex tester** (shows match highlighting against episode titles when editing filter fields)

**Step 2: Integrate with playlist definition form** (titleFilter, excludeFilter, requireFilter fields)

**Step 3: Commit**

```
feat(sp_web): add inline regex tester for filter fields
```

---

### Task 20: Settings page with API key management

**Files:**
- Create: `packages/sp_web/lib/features/settings/screens/settings_screen.dart`
- Create: `packages/sp_web/lib/features/settings/widgets/api_key_manager.dart`

**Step 1: Build API key list** (shows masked keys with revoke button)

**Step 2: Build "Generate Key" flow** (shows plaintext once, copy button)

**Step 3: Commit**

```
feat(sp_web): add settings page with API key management
```

---

### Task 21: Draft save and PR submission

**Files:**
- Modify: `packages/sp_web/lib/features/editor/screens/editor_screen.dart`
- Create: `packages/sp_web/lib/features/editor/widgets/submit_dialog.dart`

**Step 1: Add "Save Draft" button** (calls POST /api/drafts)

**Step 2: Add "Submit as PR" button** (confirmation dialog, calls POST /api/configs/submit)

**Step 3: Show PR URL after successful submission**

**Step 4: Commit**

```
feat(sp_web): add draft saving and PR submission
```

---

## Phase 4: MCP Server

### Task 22: Build MCP server with all tools

**Files:**
- Create: `mcp_server/bin/mcp_server.dart`
- Create: `mcp_server/lib/src/tools/search_configs_tool.dart`
- Create: `mcp_server/lib/src/tools/get_config_tool.dart`
- Create: `mcp_server/lib/src/tools/get_schema_tool.dart`
- Create: `mcp_server/lib/src/tools/fetch_feed_tool.dart`
- Create: `mcp_server/lib/src/tools/validate_config_tool.dart`
- Create: `mcp_server/lib/src/tools/preview_config_tool.dart`
- Create: `mcp_server/lib/src/tools/submit_config_tool.dart`

**Step 1: Set up MCP server with stdio transport**

**Step 2: Implement each tool as a thin wrapper over sp_server API calls**

**Step 3: Add MCP resources** (schema, configs)

**Step 4: Test with a local MCP client**

**Step 5: Compile to AOT binary**

Run: `dart compile exe mcp_server/bin/mcp_server.dart -o sp-mcp-server`

**Step 6: Commit**

```
feat(mcp_server): add MCP server with SmartPlaylist tools and resources
```

---

## Phase 5: Audiflow Refactor (Future)

### Task 23: Make audiflow_domain depend on sp_shared

This is a separate effort to be done after the web editor is stable.

**Changes:**
1. Add `sp_shared` as a git dependency in `audiflow_domain/pubspec.yaml`
2. Remove duplicated model files from `audiflow_domain/lib/src/features/feed/models/`
3. Re-export sp_shared models from audiflow_domain barrel
4. Update resolver imports to use sp_shared
5. Keep Drift tables, providers, and local datasource in audiflow_domain
6. Update `EpisodeToEpisodeData` extension to implement expanded `EpisodeData` interface
7. Run all audiflow tests to verify no regressions

**This task should NOT be done in this plan** - it's a separate PR to the audiflow repo after sp_shared is stable and tested.

---

## Execution Notes

- **Phase 1 (Tasks 1-7)** is the foundation and should be done first. No external dependencies needed.
- **Phase 2 (Tasks 8-15)** can start once sp_shared is ready. Tasks 8-10 (server setup, auth, API keys) are sequential. Tasks 11-15 can be parallelized.
- **Phase 3 (Tasks 16-21)** can start once basic server endpoints exist. Tasks 16-18 are sequential (auth -> editor -> preview). Tasks 19-21 can be parallelized.
- **Phase 4 (Task 22)** can start once server API is complete.
- **Phase 5 (Task 23)** is deferred until the web editor is stable.
