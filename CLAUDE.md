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
                                                              CI
                                                              ──────>  GitHub Pages / GCS
                                                                          ^
                                                                          |
                                                                       audiflow app fetches
```

- **This repo** provides a local web editor that reads/writes files in a cloned data repo
- **Users** manage git operations (commit, push, PR) themselves
- **Data repos** are the source of truth; CI syncs them to hosting on merge
- **audiflow app** consumes configs from the hosting layer, never directly from GitHub

## Working with Each Repo

- **audiflow**: Model serialization (JSON keys, field structure) in `audiflow_domain` must stay aligned with the config JSON schema defined in `sp_core` here
- **audiflow-smartplaylist**: Production data repo; users clone it locally, edit via this web editor, then commit and push changes themselves
- **audiflow-smartplaylist-dev**: Dev data repo; same workflow as production, safe for experimentation

## JSON Schema as Single Source of Truth

`crates/sp_core/src/schema/` contains three **canonical JSON Schema** files (embedded via `include_str!`) matching the split file structure:

- `pattern-index.schema.json` -- validates root `meta.json` (dataVersion, schemaVersion, pattern summaries)
- `pattern-meta.schema.json` -- validates per-pattern `meta.json` (feedUrls, flags, playlist IDs)
- `playlist-definition.schema.json` -- validates individual playlist files

When you modify the schema (add fields, change enums, rename properties), all consumers must be updated.

### What the schemas define

- Root pattern index: `dataVersion`, `schemaVersion`, pattern summaries
- Pattern metadata: `id`, `feedUrls`, `playlists`, `podcastGuid`, `yearGroupedEpisodes`
- Playlist definitions: `resolverType`, filters, groups, sort, extractors, display options
- Shared `$defs`: `GroupDef`, `SortSpec`, `SortRule`, `SortCondition`, `TitleExtractor`, `EpisodeExtractor`

### Where the schema is consumed

| Consumer | Location | How it uses schema |
|----------|----------|--------------------|
| `sp_core` (this repo) | Schema validation module + conformance tests | Runtime validation + test-time enum checks |
| `sp_react` (this repo) | `src/schemas/config-schema.ts` + conformance tests | Zod schema for form validation |
| `audiflow` (mobile app) | `audiflow_domain/test/fixtures/schema.json` (vendored copy) | Conformance tests validate `toJson()` output |

### How consumers adopt the schema

When a consumer repo has its own hand-written models (like `audiflow_domain`), it should:

1. **Vendor schema files** into `test/fixtures/` (copy from `crates/sp_core/src/schema/*.schema.json`)
2. **Add `json_schema: ^5.2.2`** as a dev dependency for schema validation
3. **Write conformance tests** that:
   - Construct models with `toJson()`, validate directly against the appropriate schema (no envelope wrapping)
   - Extract enum values from the vendored schema and compare against the constants/enums used in production code
4. **Use schema-valid values in all test data** (e.g., `'rss'` not `'rssSeason'`, `'category'` not `'categoryGroup'`)

### When updating the schema

1. Update schema files in `crates/sp_core/src/schema/`
2. Update `sp_core` models, constants, and conformance tests
3. Update `sp_react` Zod schema and conformance tests
4. Copy updated schema files to consumer repos' `test/fixtures/`
5. Run consumer conformance tests to detect drift and fix as needed
