# Smart Playlist Data Repo Contract

## Purpose

Documents the file structure and format contract between this editor and the smart playlist data repositories (`audiflow-smartplaylist` for production, `audiflow-smartplaylist-dev` for dev/staging).

## Scope

This document covers:
- The split config file structure that this editor reads and writes
- Format and naming conventions the editor enforces
- What the editor assumes about the data directory
- How data repos are deployed and consumed downstream

## Responsibilities

- Read and write config files following the split config structure
- Enforce JSON Schema validation on all written files
- Use atomic writes (`.tmp` then rename) to prevent partial reads
- Validate path segments to prevent directory traversal
- Provide `format` CLI command for JSON normalization
- Provide `validate` CLI command for schema validation (usable in data repo CI)

## Non-responsibilities

- Managing git operations on data repos (user responsibility)
- CI/CD deployment of data repos to hosting (owned by data repo pipelines)
- Content decisions about which podcasts or playlists exist
- Hosting config files for app consumption (owned by GitHub Pages / GCS)

## File structure contract

The editor expects and produces this directory layout in the data directory:

```
patterns/
  meta.json                         # Root index: dataVersion, schemaVersion, pattern summaries
  {patternId}/
    meta.json                       # Pattern metadata: id, feedUrls, podcastGuid, yearGroupedEpisodes, playlists[]
    playlists/
      {playlistId}.json             # Playlist definition: resolverType, filters, groups, sort, display
```

### File-level schema mapping

| File | Schema | SchemaType enum value |
|------|--------|-----------------------|
| `patterns/meta.json` | `pattern-index.schema.json` | `PatternIndex` |
| `patterns/{id}/meta.json` | `pattern-meta.schema.json` | `PatternMeta` |
| `patterns/{id}/playlists/{pid}.json` | `playlist-definition.schema.json` | `PlaylistDefinition` |

### Naming rules

- `patternId`: string identifier, used as directory name (no path separators allowed)
- `playlistId`: string identifier, used as filename without extension (no path separators allowed)
- All JSON files use 2-space indentation with trailing newline

### Version fields

- `dataVersion` in root `meta.json`: incremented by the editor when patterns change
- `schemaVersion` in root `meta.json`: tracks which schema version the data conforms to

## Data flow

```
Editor writes -> Local data repo clone -> User pushes -> CI deploys -> Hosting -> App fetches
```

- Production: `audiflow-smartplaylist` -> GitHub Pages
- Dev/staging: `audiflow-smartplaylist-dev` -> GCS bucket (`audiflow-dev-config`)

## Integration assumptions

- The data directory contains a valid `patterns/meta.json` before the server starts (`serve` command validates this)
- External tools or manual edits may modify files while the server is running (FileWatcherService handles this)
- Feed cache is stored in `$dataDir/.cache/feeds/` and is not part of the data contract
- `.tmp` files are transient and should be gitignored

## Related documents

- docs/integration/editor-to-schema.md -- schema definitions that validate this file structure
- docs/architecture/module-boundaries.md -- LocalConfigRepository in sp_server owns file I/O
- docs/overview.md -- overall purpose and concepts

## When to update

Update this document when:
- Split config file structure changes (new levels, renamed files)
- Naming conventions or version field semantics change
- New data repos are added to the ecosystem
- Deployment targets change (e.g., new hosting provider)
