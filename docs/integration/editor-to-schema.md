# Editor-to-Schema Integration

## Purpose

Documents the relationship between the editor codebase and the JSON Schema definitions it owns, including how schemas are consumed by other repositories.

## Scope

This document covers:
- Schema file locations and ownership
- How schemas are embedded and used within this repo
- How consumer repos adopt and validate against these schemas
- The schema update coordination process

## Responsibilities

- Own and maintain three canonical JSON Schema files in `crates/sp_core/assets/`:
  - `pattern-index.schema.json` -- validates root `patterns/meta.json`
  - `pattern-meta.schema.json` -- validates per-pattern `{id}/meta.json`
  - `playlist-definition.schema.json` -- validates playlist definition files
- Embed schemas at compile time via `include_str!` in sp_core
- Validate configs at runtime via `sp_core::schema::Validator`
- Expose playlist-definition schema via `GET /api/schema` endpoint
- Mirror schemas as Zod 4 schemas in `sp_react` (`src/schemas/config-schema.ts`)
- Regenerate schema HTML docs via `make schema-doc`
- Sync schemas to/from the data repo via `make sync-schema`

## Non-responsibilities

- Vendoring schema copies into consumer repos (consumer repos copy them manually)
- Running conformance tests in consumer repos
- Deciding what config data is valid beyond structural schema (semantic validation is app-specific)

## Integration rules

- Schema files in `crates/sp_core/assets/` are the single source of truth
- Any schema change requires updating:
  1. Schema JSON files in `crates/sp_core/assets/`
  2. sp_core Rust models and serde attributes (if field names/types change)
  3. sp_core conformance tests (`crates/sp_core/tests/schema_tests.rs`)
  4. sp_react Zod schema (`packages/sp_react/src/schemas/config-schema.ts`)
  5. sp_react conformance tests
  6. Schema HTML docs (`make schema-doc`)
- Consumer repos (audiflow, data repos) must update their vendored copies after schema changes
- Valid resolver types (via `grouping.by`): `seasonNumber`, `titleClassifier`, `year`, `titleDiscovery`
- Shared `$defs` in playlist-definition schema: `EpisodeFilterEntry`, `YearBinding`, `GroupDef`, `SortOrder`, `SortRule`, `EpisodeSortRule`, `TitleExtractor`, `NumberingExtractor`, `SelectorConfig`, `GroupingConfig`, `GroupListingConfig`, `GroupItemConfig`, `EpisodeListingConfig`, `EpisodeItemConfig`

## Consumer adoption process

1. Copy schema files from `crates/sp_core/assets/*.schema.json` to consumer's `test/fixtures/`
2. Add schema validation dev dependency (e.g., `json_schema: ^5.2.2` for Dart)
3. Write conformance tests: construct models with `toJson()`, validate against appropriate schema
4. Extract enum values from vendored schema and compare against production code constants
5. Use schema-valid values in all test data

## Related documents

- docs/integration/smartplaylist-contract.md -- file structure the schemas validate
- docs/architecture/module-boundaries.md -- sp_core owns schemas, sp_react mirrors as Zod
- docs/development/change-workflow.md -- steps for schema changes
- docs/schema-reference.md -- complete field-level schema reference (v5)

## When to update

Update this document when:
- Schema files are added, removed, or restructured
- New consumer repos start using the schemas
- The schema update coordination process changes
- New `$defs` or resolver types are added
