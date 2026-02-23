# Ecosystem Overview

This repo (`audiflow-smartplaylist-editor`) is part of a three-repo ecosystem:

| Repo | Role | What lives there |
|------|------|-----------------|
| [audiflow](https://github.com/reedom/audiflow) | Flutter mobile app (podcast player) | `audiflow_domain` fetches smart playlist configs and caches locally |
| [audiflow-smartplaylist](https://github.com/reedom/audiflow-smartplaylist) | Production config data | JSON files (meta.json, pattern dirs, playlist definitions); deploys to GitHub Pages on push to main |
| [audiflow-smartplaylist-dev](https://github.com/reedom/audiflow-smartplaylist-dev) | Dev config data | Same structure as production; deploys to GCS dev bucket (`audiflow-dev-config`) on push to main |

## Data Flow

```
User clones data repo locally
                |
                v
audiflow-smartplaylist-editor              Local data repo clone         GitHub (remote)
(this repo)                 read/write  (on user's machine)  push    (source of truth)
sp_server + sp_react  <───────────────>  JSON files on disk  ──────>  origin/main
mcp_server            <───────────────>
                                                              CI
                                                              ──────>  GitHub Pages / GCS
                                                                          ^
                                                                          |
                                                                       audiflow app fetches
```

- **This repo** provides a local web editor and MCP server that read/write files in a cloned data repo
- **Users** manage git operations (commit, push, PR) themselves
- **Data repos** are the source of truth; CI syncs them to hosting on merge
- **audiflow app** consumes configs from the hosting layer, never directly from GitHub

## Working with Each Repo

- **audiflow**: Model serialization (JSON keys, field structure) in `audiflow_domain` must stay aligned with the config JSON schema defined in `sp_shared` here
- **audiflow-smartplaylist**: Production data repo; users clone it locally, edit via this web editor or MCP, then commit and push changes themselves
- **audiflow-smartplaylist-dev**: Dev data repo; same workflow as production, safe for experimentation

## JSON Schema as Single Source of Truth

`packages/sp_shared/assets/schema.json` is the **canonical JSON Schema** for all smart playlist configs. When you modify the schema (add fields, change enums, rename properties), all consumers must be updated.

### What the schema defines

- `SmartPlaylistPatternConfig` structure (id, feedUrls, playlists)
- `SmartPlaylistDefinition` fields and their types
- `resolverType` enum values: `rss`, `category`, `year`, `titleAppearanceOrder`
- `contentType`, `yearHeaderMode`, sort fields/orders, extractor sources
- `SmartPlaylistGroupDef`, `SmartPlaylistSortSpec`, `SmartPlaylistTitleExtractor`, `SmartPlaylistEpisodeExtractor`

### Where the schema is consumed

| Consumer | Location | How it uses schema |
|----------|----------|--------------------|
| `sp_shared` (this repo) | `SmartPlaylistValidator` + conformance tests | Runtime validation + test-time enum checks |
| `sp_react` (this repo) | `src/schemas/config-schema.ts` + conformance tests | Zod schema for form validation |
| `audiflow` (mobile app) | `audiflow_domain/test/fixtures/schema.json` (vendored copy) | Conformance tests validate `toJson()` output |

### How consumers adopt the schema

When a consumer repo has its own hand-written models (like `audiflow_domain`), it should:

1. **Vendor `schema.json`** into `test/fixtures/schema.json` (copy from `sp_shared/assets/schema.json`)
2. **Add `json_schema: ^5.2.2`** as a dev dependency for schema validation
3. **Write conformance tests** that:
   - Construct models with `toJson()`, wrap in a valid config envelope, validate against the schema
   - Extract enum values from the vendored schema and compare against the constants/enums used in production code
4. **Use schema-valid values in all test data** (e.g., `'rss'` not `'rssSeason'`, `'category'` not `'categoryGroup'`)

Reference implementations:
- `sp_shared/test/schema/schema_conformance_test.dart` (original pattern)
- `audiflow_domain/test/features/feed/models/schema_conformance_test.dart` (consumer pattern)

### When updating the schema

1. Update `sp_shared/assets/schema.json`
2. Update `sp_shared` models, constants, and conformance tests
3. Update `sp_react` Zod schema and conformance tests
4. Copy updated `schema.json` to consumer repos' `test/fixtures/`
5. Run consumer conformance tests to detect drift and fix as needed
