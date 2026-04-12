# v5 GroupDef Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename GroupDef (per-classifier override) fields to match playlist-level v5 block names. Replace the v4-era `display` and `episodeList` sub-objects with `groupItem`, `groupListing`, `episodeListing`, `episodeItem` — a 1:1 mirror of the playlist-level structure.

**Architecture:** Rename in schema JSON (SSoT), Rust model, Rust consumers, TypeScript Zod schema, and existing data files. No version bump — change is made in-place in v5. No backward-compat aliases. Mobile app coordinates separately.

**Tech Stack:** Rust (sp_core), TypeScript/Zod (sp_react), JSON Schema.

**Spec:** `docs/superpowers/specs/2026-04-12-v5-editor-form-restructure-design.md` (plus decision in PR discussion: rename GroupDef override blocks to mirror playlist-level).

**Prereq for:** Plan A (form restructure) — update field names referenced there after this plan lands.

---

## Rename map

| Old (inside GroupDef) | New (inside GroupDef) |
|---|---|
| `display.showDateRange` | `groupItem.showDateRange` |
| `display.yearBinding` | `groupListing.yearBinding` |
| `episodeList.showYearHeaders` | `episodeListing.showYearHeaders` |
| `episodeList.sort` | `episodeListing.sort` |
| `episodeList.titleExtractor` | `episodeItem.titleExtractor` |
| `numberingExtractor` | unchanged |
| `episodeExtractor` (deprecated v3 alias) | unchanged (left alone here; cleanup is out of scope) |

The old blocks (`display`, `episodeList`) are removed entirely. No alias.

---

## File Plan

**Modify (editor repo `audiflow-smartplaylist-editor`):**
- `crates/sp_core/assets/playlist-definition.schema.json` — GroupDef section
- `crates/sp_core/src/models/group_def.rs` — Rust types
- `crates/sp_core/src/models/mod.rs` — re-exports
- `crates/sp_core/src/resolvers/category_resolver.rs` — consumer
- `crates/sp_core/src/services/resolver_service.rs` — consumer
- `crates/sp_core/src/resolvers/*.rs` tests, `crates/sp_core/tests/*.rs` — update fixtures
- `packages/sp_react/src/schemas/config-schema.ts` — Zod schema
- `packages/sp_react/src/schemas/__tests__/schema-conformance.test.ts` — fixtures
- `packages/sp_react/src/schemas/__tests__/config-schema.test.ts` — fixtures
- Any editor code consuming `display` / `episodeList` per-group fields (search + update; notably `playlist-tab-content.tsx` references `g?.display?.yearBinding` and `g?.episodeList?.sort`)

**Modify (data repo `audiflow-smartplaylist`):**
- `schema/playlist-definition.schema.json` — re-vendor
- `patterns/2e86c4b573b7/playlists/extras.json` — migrate override fields

**Verify:**
- All other pattern files in the data repo remain unchanged (only extras.json uses `display`/`episodeList`).

---

## Task 1: Rename fields in the editor's schema JSON (SSoT)

**Files:**
- Modify: `crates/sp_core/assets/playlist-definition.schema.json` — `GroupDef` definition (lines 133–197)

- [ ] **Step 1: Edit the schema**

In `crates/sp_core/assets/playlist-definition.schema.json`, replace the GroupDef `properties` block (currently contains `display`, `episodeList`, `numberingExtractor`, `episodeExtractor`) with:

```json
        "pattern": {
          "type": "string",
          "description": "A text pattern matched against episode titles. Episodes matching this pattern are assigned to this group. Omit this field to create a catch-all group for unmatched episodes."
        },
        "groupListing": {
          "type": "object",
          "description": "Per-group overrides for the group list (applied when this group appears in the list). Omitted fields use the playlist defaults.",
          "additionalProperties": false,
          "properties": {
            "yearBinding": {
              "$ref": "#/$defs/YearBinding",
              "description": "Custom year-group relationship for this group. When not set, uses the playlist default."
            }
          }
        },
        "groupItem": {
          "type": "object",
          "description": "Per-group overrides for this group's card. Omitted fields use the playlist defaults.",
          "additionalProperties": false,
          "properties": {
            "showDateRange": {
              "type": "boolean",
              "description": "Show or hide date range on this group's card. When not set, uses the playlist default."
            }
          }
        },
        "episodeListing": {
          "type": "object",
          "description": "Per-group overrides for the episode list inside this group. Omitted fields use the playlist defaults.",
          "additionalProperties": false,
          "properties": {
            "showYearHeaders": {
              "type": "boolean",
              "description": "Show or hide year dividers in this group's episode list."
            },
            "sort": {
              "$ref": "#/$defs/EpisodeSortRule",
              "description": "Custom episode sort for this group."
            }
          }
        },
        "episodeItem": {
          "type": "object",
          "description": "Per-group overrides for individual episode rows inside this group.",
          "additionalProperties": false,
          "properties": {
            "titleExtractor": {
              "$ref": "#/$defs/TitleExtractor",
              "description": "Custom episode title transformation for this group."
            }
          }
        },
        "numberingExtractor": {
          "$ref": "#/$defs/NumberingExtractor",
          "description": "Custom number rule for this group. When not set, uses the playlist default."
        },
        "episodeExtractor": {
          "$ref": "#/$defs/NumberingExtractor",
          "description": "Deprecated v3 alias for 'numberingExtractor'. Use 'numberingExtractor' for new configs."
        }
```

Also update the GroupDef `description` on line 135 from:
> "Groups can customize display, episodeList, and numberingExtractor settings."

to:
> "Groups can override `groupListing`, `groupItem`, `episodeListing`, `episodeItem`, and `numberingExtractor` settings. Omitted fields use the playlist defaults."

- [ ] **Step 2: Verify JSON validity**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor && node -e "JSON.parse(require('fs').readFileSync('crates/sp_core/assets/playlist-definition.schema.json')); console.log('valid')"
```

Expected: `valid`.

- [ ] **Step 3: Commit**

```bash
git add crates/sp_core/assets/playlist-definition.schema.json
git commit -m "schema: rename GroupDef override blocks to match playlist-level v5 names"
```

---

## Task 2: Update Rust `GroupDef` model in `sp_core`

**Files:**
- Modify: `crates/sp_core/src/models/group_def.rs`
- Modify: `crates/sp_core/src/models/mod.rs`

- [ ] **Step 1: Rewrite `group_def.rs`**

Replace `crates/sp_core/src/models/group_def.rs` with:

```rust
use serde::{Deserialize, Serialize};

use super::numbering_extractor::NumberingExtractor;
use super::sort::EpisodeSortRule;
use super::title_extractor::TitleExtractor;

/// Static group definition within a playlist.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDef {
    pub id: String,
    pub display_name: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub pattern: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_listing: Option<GroupDefGroupListing>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub group_item: Option<GroupDefGroupItem>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_listing: Option<GroupDefEpisodeListing>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub episode_item: Option<GroupDefEpisodeItem>,

    /// Accepts legacy `episodeExtractor` key for v3 backward compatibility.
    #[serde(skip_serializing_if = "Option::is_none", alias = "episodeExtractor")]
    pub numbering_extractor: Option<NumberingExtractor>,
}

/// Per-group overrides for the group list section.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefGroupListing {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year_binding: Option<String>,
}

/// Per-group overrides for the group card.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefGroupItem {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_date_range: Option<bool>,
}

/// Per-group overrides for the episode list.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefEpisodeListing {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_year_headers: Option<bool>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub sort: Option<EpisodeSortRule>,
}

/// Per-group overrides for individual episode rows.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefEpisodeItem {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,
}
```

- [ ] **Step 2: Update re-exports**

Open `crates/sp_core/src/models/mod.rs` and replace:

```rust
pub use group_def::{GroupDef, GroupDefDisplay, GroupDefEpisodeList};
```

with:

```rust
pub use group_def::{
    GroupDef, GroupDefEpisodeItem, GroupDefEpisodeListing, GroupDefGroupItem, GroupDefGroupListing,
};
```

- [ ] **Step 3: Build to surface downstream compile errors**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor && cargo build -p sp_core
```

Expected: FAIL with errors in `category_resolver.rs` and `resolver_service.rs` (and possibly tests) because they reference `.display` / `.episode_list`. These are fixed in Tasks 3 and 4.

- [ ] **Step 4: Commit (yes, with failing build — the next tasks fix it)**

Commit the type change even though downstream still has errors; it makes the diff reviewable:

```bash
git add crates/sp_core/src/models/group_def.rs crates/sp_core/src/models/mod.rs
git commit -m "refactor(sp_core): rename GroupDef override blocks (downstream WIP)"
```

---

## Task 3: Update `category_resolver.rs`

**Files:**
- Modify: `crates/sp_core/src/resolvers/category_resolver.rs`

- [ ] **Step 1: Find current usages**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor && grep -n "\.display\|\.episode_list" crates/sp_core/src/resolvers/category_resolver.rs
```

List the line numbers you'll need to update.

- [ ] **Step 2: Rewrite references**

Apply the rename map throughout the file:
- `group.display.as_ref().and_then(|d| d.year_binding...)` → `group.group_listing.as_ref().and_then(|g| g.year_binding...)`
- `group.display.as_ref().and_then(|d| d.show_date_range)` → `group.group_item.as_ref().and_then(|g| g.show_date_range)`
- `group.episode_list.as_ref().and_then(|e| e.show_year_headers)` → `group.episode_listing.as_ref().and_then(|e| e.show_year_headers)`
- `group.episode_list.as_ref().and_then(|e| e.sort.clone())` → `group.episode_listing.as_ref().and_then(|e| e.sort.clone())`
- `group.episode_list.as_ref().and_then(|e| e.title_extractor.clone())` → `group.episode_item.as_ref().and_then(|e| e.title_extractor.clone())`

(Exact patterns depend on current code. Preserve any `.clone()` / `Option` chaining.)

- [ ] **Step 3: Build this crate**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor && cargo build -p sp_core
```

Expected: remaining errors should come only from `resolver_service.rs` and test files.

- [ ] **Step 4: Commit**

```bash
git add crates/sp_core/src/resolvers/category_resolver.rs
git commit -m "refactor(sp_core): update category_resolver for renamed GroupDef blocks"
```

---

## Task 4: Update `resolver_service.rs` and any other consumers

**Files:**
- Modify: `crates/sp_core/src/services/resolver_service.rs`
- Modify: any other file surfaced by `grep` in Step 1

- [ ] **Step 1: Scan for remaining references**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor && grep -rn "\.display\|\.episode_list\|GroupDefDisplay\|GroupDefEpisodeList" crates/sp_core/src
```

Update every hit using the same rename map from Task 3. Watch for unrelated `.display` (e.g., `display_name`) — skip those.

- [ ] **Step 2: Build**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor && cargo build -p sp_core
```

Expected: PASS (test files may still fail; fixed in Task 5).

- [ ] **Step 3: Commit**

```bash
git add -u crates/sp_core/src
git commit -m "refactor(sp_core): update resolver_service and consumers for GroupDef rename"
```

---

## Task 5: Update Rust tests

**Files:**
- Modify: any `crates/sp_core/**/*test*.rs` or `crates/sp_core/tests/*.rs` with fixtures using old names

- [ ] **Step 1: Scan for old field names in tests**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor && grep -rn "\"display\"\|\"episodeList\"\|GroupDefDisplay\|GroupDefEpisodeList" crates/sp_core
```

- [ ] **Step 2: Update test fixtures**

For each hit, apply the rename map (JSON test strings → new keys; Rust struct names → new types).

- [ ] **Step 3: Run the full test suite**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor && cargo test -p sp_core
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add -u crates/sp_core
git commit -m "test(sp_core): update GroupDef test fixtures to new field names"
```

---

## Task 6: Update TypeScript Zod schema

**Files:**
- Modify: `packages/sp_react/src/schemas/config-schema.ts` (around lines 86–104)

- [ ] **Step 1: Rewrite `groupDefSchema`**

Replace the existing block with:

```typescript
export const groupDefSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  pattern: z.string().optional(),
  groupListing: z
    .object({
      yearBinding: yearBindingSchema.optional(),
    })
    .optional(),
  groupItem: z
    .object({
      showDateRange: z.boolean().optional(),
    })
    .optional(),
  episodeListing: z
    .object({
      showYearHeaders: z.boolean().optional(),
      sort: episodeSortRuleSchema.optional(),
    })
    .optional(),
  episodeItem: z
    .object({
      titleExtractor: titleExtractorSchema.optional(),
    })
    .optional(),
  numberingExtractor: numberingExtractorSchema.optional(),
});
```

Remove any now-unused types (`GroupDefDisplay`, `GroupDefEpisodeList`) if they were inferred and re-exported. Add exported types for the new shapes if needed by downstream code.

- [ ] **Step 2: Scan for remaining TS references**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor && grep -rn "\.display\b\|\.episodeList\b" packages/sp_react/src --include="*.ts*"
```

Skip unrelated hits (e.g., `.displayName`). For each GroupDef-level hit, apply the rename map. Known sites include `playlist-tab-content.tsx` around lines 99–120 where the code reads `g?.display?.yearBinding` and `g?.episodeList?.sort`.

- [ ] **Step 3: Run type check and tests**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor/packages/sp_react && pnpm tsc --noEmit && pnpm vitest run
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add packages/sp_react/src
git commit -m "refactor(sp_react): align GroupDef schema and consumers with v5 names"
```

---

## Task 7: Re-vendor schema to data repo and migrate pattern

**Files (in `audiflow-smartplaylist` data repo):**
- Modify: `schema/playlist-definition.schema.json`
- Modify: `patterns/2e86c4b573b7/playlists/extras.json`

- [ ] **Step 1: Copy the updated schema from editor to data repo**

```bash
cp /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor/crates/sp_core/assets/playlist-definition.schema.json \
   /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist/schema/playlist-definition.schema.json
```

- [ ] **Step 2: Migrate `extras.json`**

Open `patterns/2e86c4b573b7/playlists/extras.json` and apply the rename map. Specifically:

Replace every occurrence of:

```json
        "display": {
          "yearBinding": "splitByYear"
        },
```

with:

```json
        "groupListing": {
          "yearBinding": "splitByYear"
        },
```

(Three groups have this: `special`, `extra`, `other`.)

Replace every occurrence of:

```json
        "episodeList": {
          "showYearHeaders": false
        }
```

with:

```json
        "episodeListing": {
          "showYearHeaders": false
        }
```

(Many groups have this standalone form.)

Replace the more complex occurrences:

```json
        "episodeList": {
          "showYearHeaders": true,
          "sort": {
            "field": "publishedAt",
            "order": "descending"
          }
        }
```

with:

```json
        "episodeListing": {
          "showYearHeaders": true,
          "sort": {
            "field": "publishedAt",
            "order": "descending"
          }
        }
```

(Three groups: `special`, `extra`, `other`.)

Note: this pattern has no `display.showDateRange` or `episodeList.titleExtractor` entries to migrate. If future patterns have them, map them to `groupItem.showDateRange` and `episodeItem.titleExtractor` respectively.

- [ ] **Step 3: Verify no old field names remain**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist && grep -rn '"display":\|"episodeList":' patterns/
```

Expected: no matches.

- [ ] **Step 4: Run schema validation**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist && schema/scripts/validate.sh patterns/
```

Expected: all patterns validate successfully.

- [ ] **Step 5: Commit (in the data repo)**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist
git add schema/playlist-definition.schema.json patterns/2e86c4b573b7/playlists/extras.json
git commit -m "refactor(patterns): align GroupDef overrides with v5 block names"
```

---

## Task 8: Full verification

- [ ] **Step 1: Editor repo full test suite**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor
cargo test -p sp_core
cd packages/sp_react && pnpm tsc --noEmit && pnpm lint && pnpm vitest run
```

Expected: all green.

- [ ] **Step 2: Load the Coten Radio pattern in the editor**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor/packages/sp_react && pnpm dev
```

Open `http://localhost:5173/editor/2e86c4b573b7`. Switch to the "その他(番外編など)" playlist tab. Confirm:
- Loads without console errors.
- Save + reload preserves the migrated field names in the file.
- Preview renders groups as expected (year sections for `special`/`extra`/`other`).

- [ ] **Step 3: Update Plan A and Plan B references**

Search the two follow-on plans for references to `display.*` or `episodeList.*` inside GroupDef contexts:

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor && \
  grep -n "display\.showDateRange\|display\.yearBinding\|episodeList\." docs/superpowers/plans/2026-04-12-v5-form-restructure.md docs/superpowers/plans/2026-04-12-v5-preview-overhaul.md
```

Update each reference to the new block names and commit with `docs: update plan references to new GroupDef names`.

---

## Verification

After all tasks land:

- `cargo test -p sp_core` passes in editor repo.
- `pnpm vitest run`, `pnpm tsc --noEmit`, `pnpm lint` pass in editor repo.
- `schema/scripts/validate.sh patterns/` passes in data repo.
- The editor UI loads the migrated extras.json without errors.
- `grep -rn '"display":\|"episodeList":' patterns/` has zero matches in data repo.
- Plan A and Plan B references to GroupDef override fields use the new names.
