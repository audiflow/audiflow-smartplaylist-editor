# Selector partitionBy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `presentation` with a `selector` config block that supports `partitionBy` for organizing resolver groups into separate selector entries by group, seasonNumber, or year.

**Architecture:** The primary resolver produces groups (e.g., professors via titleDiscovery). The `selector.partitionBy` field determines how those groups map to selector entries: no partition (single entry with group cards), by group (each group becomes its own entry), by seasonNumber (one entry per season, groups as cards within each), or by year (same, by publication year). This replaces the old `presentation: "combined" | "separate"` enum.

**Tech Stack:** Rust (sp_core, sp_server), TypeScript/React (sp_react), JSON Schema, Zod

**Working directory:** `/Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor`

---

## Schema migration: presentation → selector

| Old (v4) | New (v5) |
|----------|----------|
| `"presentation": "combined"` | `"selector": {}` or absent |
| `"presentation": "separate"` | `"selector": { "partitionBy": "group" }` |
| NEW | `"selector": { "partitionBy": "seasonNumber", "titleExtractor": {...} }` |
| NEW | `"selector": { "partitionBy": "year", "titleExtractor": {...} }` |

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `crates/sp_core/assets/playlist-definition.schema.json` | Replace `presentation` with `selector` |
| Modify | `crates/sp_core/src/models/playlist_definition.rs` | Add `SelectorConfig`, replace `presentation` field |
| Modify | `crates/sp_core/src/models/playlist.rs` | Add `sub_groups` to `PlaylistGroup` |
| Modify | `crates/sp_core/src/models/mod.rs` | Export new types |
| Modify | `crates/sp_core/src/services/resolver_service.rs` | Implement partition logic |
| Modify | `crates/sp_core/src/services/helpers.rs` | Update presentation parsing |
| Modify | `crates/sp_server/src/routes/preview.rs` | Serialize partitioned results |
| Modify | `crates/sp_core/tests/resolver_tests.rs` | Add partition tests |
| Modify | `packages/sp_react/src/schemas/config-schema.ts` | Add selector schema |
| Modify | `packages/sp_react/src/schemas/api-schema.ts` | Add subGroups to preview |
| Modify | `packages/sp_react/src/components/preview/playlist-tree.tsx` | Render sub-groups |

---

## Task 1: Add `SelectorConfig` and update `PlaylistDefinition` model

Add the new `selector` field alongside the existing `presentation` field (keeping `presentation` as a deprecated alias during migration).

## Task 2: Add `sub_groups` to `PlaylistGroup`

For partitionBy seasonNumber/year, each selector entry contains groups, and those groups contain episodes. The `PlaylistGroup` needs a `sub_groups` field to support this nesting.

## Task 3: Update JSON Schema

Replace `presentation` with `selector` in the JSON Schema definition.

## Task 4: Implement partition logic in ResolverService

After the primary resolver produces groups, apply partitioning based on `selector.partitionBy`.

## Task 5: Serialize partitioned results in preview API

Update the preview serialization to handle sub-groups.

## Task 6: Update TypeScript Zod schemas

Add `selectorConfigSchema` and `subGroups` to preview schema.

## Task 7: Render sub-groups in preview tree

Add nested accordion rendering for partitioned results.

## Task 8: Full-stack verification

Run all tests, linting, and type checking.
