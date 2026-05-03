# Thumbnail Visibility Flags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add boolean flags that let editors hide thumbnails on entries within the native podcast Episodes tab, the smartplaylist group list, and the per-group episode list. Defaults preserve current behavior (thumbnails shown).

**Architecture:** Three new fields, all defaulting to `true`. `showEpisodeThumbnail` lives at pattern-meta root. `showThumbnail` lives on `GroupItemConfig`, `EpisodeItemConfig`, `GroupDef.groupItem`, and `GroupDef.episodeItem` inside playlist definitions. Editor UI surfaces all three through new checkboxes wired to the same Zustand-backed forms that already host `showDateRange` and `yearGroupedEpisodes`.

**Tech Stack:** Rust 2024 (serde, jsonschema), JSON Schema draft-07, React 19 + TypeScript, Zod 4, react-hook-form, Vitest.

---

## File Map

Create / modify:

- Modify `crates/sp_core/assets/pattern-meta.schema.json` — add `showEpisodeThumbnail` property.
- Modify `crates/sp_core/assets/playlist-definition.schema.json` — add `showThumbnail` to `GroupItemConfig`, `EpisodeItemConfig`, and the inline `groupItem` / `episodeItem` blocks under `GroupDef`.
- Modify `crates/sp_core/src/models/pattern_meta.rs` — add `show_episode_thumbnail: bool` with default `true`.
- Modify `crates/sp_core/src/models/playlist_definition.rs` — add `show_thumbnail: Option<bool>` to `GroupItemConfig` and `EpisodeItemConfig`.
- Modify `crates/sp_core/src/models/group_def.rs` — add `show_thumbnail: Option<bool>` to `GroupDefGroupItem` and `GroupDefEpisodeItem`.
- Modify `packages/sp_react/src/schemas/config-schema.ts` — extend Zod schemas.
- Modify `packages/sp_react/src/components/editor/pattern-settings.tsx` — add `showEpisodeThumbnail` checkbox.
- Modify `packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx` — add two `showThumbnail` checkboxes (group / episode) with per-group override paths.
- Modify `packages/sp_react/src/components/editor/group-def-card.tsx` — add a `showThumbnail` checkbox in display overrides.
- Modify `packages/sp_react/src/locales/en/editor.json`, `packages/sp_react/src/locales/ja/editor.json` — labels.
- Modify `packages/sp_react/src/locales/en/hints.json`, `packages/sp_react/src/locales/ja/hints.json` — hint text.
- Modify `docs/schema-reference.md` — document the three new fields.
- Regenerate via `make schema-doc` (no manual edits to generated output).

Add tests:

- Append cases to `crates/sp_core/src/models/playlist_definition.rs` `tests` module (serde round-trip).
- Add a small `cfg(test)` block in `crates/sp_core/src/models/pattern_meta.rs` (file currently has none).
- Append cases to `crates/sp_core/tests/schema_tests.rs` (JSON Schema accepts both presence and absence; rejects wrong type).
- Append cases to `packages/sp_react/src/schemas/__tests__/config-schema.test.ts` and `packages/sp_react/src/schemas/__tests__/schema-conformance.test.ts`.

---

## Conventions

Two intentionally different serde shapes, each matching its file's existing siblings:

| Field | Type | Default | Skip when |
|-------|------|---------|-----------|
| `pattern_meta::PatternMeta::show_episode_thumbnail` | `bool` | `true` | value is `true` (mirrors `year_grouped_episodes`, but inverted default) |
| `playlist_definition::GroupItemConfig::show_thumbnail` | `Option<bool>` | implicit `true` (consumer treats `None` as default) | `is_none()` |
| `playlist_definition::EpisodeItemConfig::show_thumbnail` | `Option<bool>` | implicit `true` | `is_none()` |
| `group_def::GroupDefGroupItem::show_thumbnail` | `Option<bool>` | inherit playlist | `is_none()` |
| `group_def::GroupDefEpisodeItem::show_thumbnail` | `Option<bool>` | inherit playlist | `is_none()` |

The `Option<bool>` flavor matches every other display flag in `playlist_definition.rs` and `group_def.rs`. Default-true is documented only in the JSON Schema's `default: true`; in Rust `None` is the sentinel for "not set, use default".

Pattern meta uses concrete `bool` to mirror `year_grouped_episodes`. We need a small helper for the default and the skip predicate so the JSON omits the field when it equals the default.

---

## Task 1: JSON Schema -- pattern-meta `showEpisodeThumbnail`

**Files:**
- Modify: `crates/sp_core/assets/pattern-meta.schema.json`
- Test: `crates/sp_core/tests/schema_tests.rs`

- [ ] **Step 1: Add a failing schema test that requires the new property to be accepted with both values and to reject a non-boolean.**

Append this block at the bottom of `crates/sp_core/tests/schema_tests.rs` (inside its existing `mod` if any, otherwise at file scope):

```rust
#[test]
fn pattern_meta_accepts_show_episode_thumbnail() {
    let validator = sp_core::schema::Validator::from_embedded().unwrap();
    let base = serde_json::json!({
        "dataVersion": 1,
        "id": "abc",
        "feedUrls": ["https://example.com/rss"],
        "playlists": ["p1"]
    });

    let mut with_true = base.clone();
    with_true["showEpisodeThumbnail"] = serde_json::json!(true);
    let errs = validator.validate(sp_core::schema::SchemaType::PatternMeta, &with_true);
    assert!(errs.is_empty(), "true should be accepted: {:?}", errs);

    let mut with_false = base.clone();
    with_false["showEpisodeThumbnail"] = serde_json::json!(false);
    let errs = validator.validate(sp_core::schema::SchemaType::PatternMeta, &with_false);
    assert!(errs.is_empty(), "false should be accepted: {:?}", errs);

    let mut with_string = base.clone();
    with_string["showEpisodeThumbnail"] = serde_json::json!("yes");
    let errs = validator.validate(sp_core::schema::SchemaType::PatternMeta, &with_string);
    assert!(!errs.is_empty(), "string should be rejected");
}
```

Before writing, run:

```bash
grep -n "SchemaType" /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor/crates/sp_core/tests/schema_tests.rs | head -5
```

If `SchemaType::PatternMeta` is named differently in this codebase (e.g., `PatternMetaSchema`), use the exact variant from `crates/sp_core/src/schema/validator.rs`. Do **not** invent the variant name.

- [ ] **Step 2: Run the test and confirm it fails.**

```bash
cargo test -p sp_core --test schema_tests pattern_meta_accepts_show_episode_thumbnail -- --nocapture
```

Expected: FAIL on the third assertion (the schema currently allows arbitrary keys to be rejected by `additionalProperties: false`, so `with_true` will fail first with a "additional property not allowed" message; `with_string` will also "fail" by being rejected which keeps the third assert green but the first two will fail). Confirm at least one of the first two assertions fails.

- [ ] **Step 3: Add the property to `pattern-meta.schema.json`.**

In `crates/sp_core/assets/pattern-meta.schema.json`, inside `"properties"` between `"yearGroupedEpisodes"` and `"playlists"`, add:

```json
    "showEpisodeThumbnail": {
      "type": "boolean",
      "default": true,
      "description": "When true (default), each episode row in the main podcast episode list shows the episode (or fallback podcast) thumbnail. When false, no thumbnail is rendered on these rows. The page header artwork is unaffected."
    },
```

Keep alphabetical/logical grouping consistent with surrounding fields and preserve the trailing comma rules (the next property is `playlists`).

- [ ] **Step 4: Run the test and confirm it passes.**

```bash
cargo test -p sp_core --test schema_tests pattern_meta_accepts_show_episode_thumbnail -- --nocapture
```

Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add crates/sp_core/assets/pattern-meta.schema.json \
        crates/sp_core/tests/schema_tests.rs
git commit -m "feat(sp_core): add showEpisodeThumbnail to pattern meta schema"
```

---

## Task 2: JSON Schema -- playlist-definition `showThumbnail`

**Files:**
- Modify: `crates/sp_core/assets/playlist-definition.schema.json`
- Test: `crates/sp_core/tests/schema_tests.rs`

- [ ] **Step 1: Add a failing schema test covering the four insertion points.**

Append to `crates/sp_core/tests/schema_tests.rs`:

```rust
#[test]
fn playlist_definition_accepts_show_thumbnail_everywhere() {
    let validator = sp_core::schema::Validator::from_embedded().unwrap();
    let doc = serde_json::json!({
        "id": "test",
        "displayName": "Test",
        "priority": 0,
        "grouping": {
            "by": "titleClassifier",
            "staticClassifiers": [
                {
                    "id": "g1",
                    "displayName": "G1",
                    "pattern": { "source": "title", "pattern": ".*" },
                    "groupItem": { "showThumbnail": false },
                    "episodeItem": { "showThumbnail": true }
                }
            ]
        },
        "groupItem": { "showThumbnail": false },
        "episodeItem": { "showThumbnail": false }
    });
    let errs = validator.validate(sp_core::schema::SchemaType::PlaylistDefinition, &doc);
    assert!(errs.is_empty(), "expected accept, got: {:?}", errs);

    let mut bad = doc.clone();
    bad["groupItem"]["showThumbnail"] = serde_json::json!("nope");
    let errs = validator.validate(sp_core::schema::SchemaType::PlaylistDefinition, &bad);
    assert!(!errs.is_empty(), "non-boolean must be rejected");
}
```

- [ ] **Step 2: Run the test and confirm it fails.**

```bash
cargo test -p sp_core --test schema_tests playlist_definition_accepts_show_thumbnail_everywhere -- --nocapture
```

Expected: FAIL with "additional property 'showThumbnail' not allowed" (because both `GroupItemConfig` and the inline override blocks set `additionalProperties: false`).

- [ ] **Step 3: Add `showThumbnail` to all four schema locations.**

In `crates/sp_core/assets/playlist-definition.schema.json`:

3a. Under `"$defs"."GroupItemConfig"."properties"`, append (before the closing brace of `properties`):

```json
        ,
        "showThumbnail": {
          "type": "boolean",
          "default": true,
          "description": "When true (default), each group card shows a thumbnail image. When false, no thumbnail is rendered on group cards in this playlist."
        }
```

3b. Under `"$defs"."EpisodeItemConfig"."properties"`, append:

```json
        ,
        "showThumbnail": {
          "type": "boolean",
          "default": true,
          "description": "When true (default), each episode row inside a group shows a thumbnail image. When false, no thumbnail is rendered on episode rows inside groups."
        }
```

3c. Under `"$defs"."GroupDef"."properties"."groupItem"."properties"`, append:

```json
            ,
            "showThumbnail": {
              "type": "boolean",
              "description": "Per-group override for the group card thumbnail. When not set, uses the playlist default."
            }
```

3d. Under `"$defs"."GroupDef"."properties"."episodeItem"."properties"`, the property block currently only contains `titleExtractor`. Add:

```json
            ,
            "showThumbnail": {
              "type": "boolean",
              "description": "Per-group override for the in-group episode row thumbnail. When not set, uses the playlist default."
            }
```

Use a JSON-aware editor (preserve trailing comma rules, do not reflow unrelated lines). Verify with `make format-check` or `cargo run -p sp_cli -- format --check` after editing.

- [ ] **Step 4: Run the test and confirm it passes.**

```bash
cargo test -p sp_core --test schema_tests playlist_definition_accepts_show_thumbnail_everywhere -- --nocapture
```

Expected: PASS.

- [ ] **Step 5: Run the full sp_core test suite to confirm no regression.**

```bash
cargo test -p sp_core
```

Expected: all green.

- [ ] **Step 6: Commit.**

```bash
git add crates/sp_core/assets/playlist-definition.schema.json \
        crates/sp_core/tests/schema_tests.rs
git commit -m "feat(sp_core): add showThumbnail to playlist definition schema"
```

---

## Task 3: Rust model -- `PatternMeta::show_episode_thumbnail`

**Files:**
- Modify: `crates/sp_core/src/models/pattern_meta.rs`

- [ ] **Step 1: Add a failing serde test.**

At the bottom of `crates/sp_core/src/models/pattern_meta.rs`, add (the file currently has no `#[cfg(test)]` block):

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn show_episode_thumbnail_defaults_to_true_when_absent() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        assert!(meta.show_episode_thumbnail, "default should be true");
    }

    #[test]
    fn show_episode_thumbnail_round_trips_false() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "showEpisodeThumbnail": false,
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        assert!(!meta.show_episode_thumbnail);
        let out = serde_json::to_value(&meta).unwrap();
        assert_eq!(out["showEpisodeThumbnail"], serde_json::json!(false));
    }

    #[test]
    fn show_episode_thumbnail_omitted_when_default_true() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        let out = serde_json::to_value(&meta).unwrap();
        assert!(out.get("showEpisodeThumbnail").is_none(),
                "field should be omitted when default true");
    }
}
```

- [ ] **Step 2: Run and confirm failure.**

```bash
cargo test -p sp_core --lib pattern_meta::tests
```

Expected: FAIL ("no field `show_episode_thumbnail`").

- [ ] **Step 3: Add the field with helpers.**

In `crates/sp_core/src/models/pattern_meta.rs`:

```rust
use serde::{Deserialize, Serialize};

use super::default_data_version;

fn default_true() -> bool {
    true
}

fn is_true(b: &bool) -> bool {
    *b
}

/// Pattern-level meta.json from a pattern directory.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PatternMeta {
    #[serde(default = "default_data_version")]
    pub data_version: i32,

    pub id: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub podcast_guid: Option<String>,

    pub feed_urls: Vec<String>,

    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub year_grouped_episodes: bool,

    /// Show thumbnails on rows of the main podcast episode list. Defaults to true; omitted from JSON when true.
    #[serde(default = "default_true", skip_serializing_if = "is_true")]
    pub show_episode_thumbnail: bool,

    /// Ordered list of playlist IDs.
    pub playlists: Vec<String>,
}
```

- [ ] **Step 4: Run and confirm pass.**

```bash
cargo test -p sp_core --lib pattern_meta::tests
```

Expected: PASS.

- [ ] **Step 5: Run full Rust test suite + clippy to catch downstream impact.**

```bash
cargo test -p sp_core && cargo clippy -- -W warnings
```

Expected: all green, zero warnings. If a constructor anywhere in the crate (search `PatternMeta {`) doesn't include `show_episode_thumbnail`, fix it to use `show_episode_thumbnail: true`.

```bash
grep -rn "PatternMeta {" crates/ --include="*.rs"
```

- [ ] **Step 6: Commit.**

```bash
git add crates/sp_core/src/models/pattern_meta.rs
# also include any constructor sites you had to update
git commit -m "feat(sp_core): add show_episode_thumbnail field to PatternMeta"
```

---

## Task 4: Rust models -- `GroupItemConfig` / `EpisodeItemConfig` `show_thumbnail`

**Files:**
- Modify: `crates/sp_core/src/models/playlist_definition.rs`

- [ ] **Step 1: Add a failing serde test.**

In `crates/sp_core/src/models/playlist_definition.rs`, inside the existing `mod tests`, append:

```rust
    #[test]
    fn show_thumbnail_round_trips_on_group_and_episode_items() {
        let json = serde_json::json!({
            "id": "test",
            "displayName": "Test",
            "priority": 0,
            "grouping": { "by": "seasonNumber" },
            "groupItem": { "showThumbnail": false },
            "episodeItem": { "showThumbnail": false }
        });
        let def: PlaylistDefinition = serde_json::from_value(json).unwrap();
        assert_eq!(def.group_item.as_ref().unwrap().show_thumbnail, Some(false));
        assert_eq!(def.episode_item.as_ref().unwrap().show_thumbnail, Some(false));

        let out = serde_json::to_value(&def).unwrap();
        assert_eq!(out["groupItem"]["showThumbnail"], serde_json::json!(false));
        assert_eq!(out["episodeItem"]["showThumbnail"], serde_json::json!(false));
    }

    #[test]
    fn show_thumbnail_absent_serializes_omitted() {
        let json = serde_json::json!({
            "id": "test",
            "displayName": "Test",
            "priority": 0,
            "grouping": { "by": "seasonNumber" },
            "groupItem": { "showDateRange": true },
            "episodeItem": {}
        });
        let def: PlaylistDefinition = serde_json::from_value(json).unwrap();
        assert!(def.group_item.as_ref().unwrap().show_thumbnail.is_none());
        let out = serde_json::to_value(&def).unwrap();
        assert!(out["groupItem"].get("showThumbnail").is_none());
    }
```

- [ ] **Step 2: Run and confirm failure.**

```bash
cargo test -p sp_core --lib playlist_definition::tests::show_thumbnail_round_trips_on_group_and_episode_items
```

Expected: FAIL ("no field `show_thumbnail`").

- [ ] **Step 3: Add the fields.**

In `crates/sp_core/src/models/playlist_definition.rs`, inside `GroupItemConfig` (after `prepend_season_number`, before `title_extractor`):

```rust
    /// Per-playlist default for showing thumbnails on group cards. None = use schema default (true).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_thumbnail: Option<bool>,
```

Inside `EpisodeItemConfig` (before `title_extractor`):

```rust
    /// Per-playlist default for showing thumbnails on in-group episode rows. None = use schema default (true).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_thumbnail: Option<bool>,
```

- [ ] **Step 4: Run and confirm pass.**

```bash
cargo test -p sp_core --lib playlist_definition
```

Expected: PASS for the two new tests and existing tests still green.

- [ ] **Step 5: Commit.**

```bash
git add crates/sp_core/src/models/playlist_definition.rs
git commit -m "feat(sp_core): add show_thumbnail to GroupItemConfig and EpisodeItemConfig"
```

---

## Task 5: Rust models -- `GroupDefGroupItem` / `GroupDefEpisodeItem` `show_thumbnail`

**Files:**
- Modify: `crates/sp_core/src/models/group_def.rs`

- [ ] **Step 1: Add a failing serde test.**

`crates/sp_core/src/models/group_def.rs` currently has no test module. Append:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn show_thumbnail_round_trips_on_per_group_overrides() {
        let json = serde_json::json!({
            "id": "g1",
            "displayName": "G1",
            "groupItem": { "showThumbnail": false },
            "episodeItem": { "showThumbnail": true }
        });
        let g: GroupDef = serde_json::from_value(json).unwrap();
        assert_eq!(g.group_item.as_ref().unwrap().show_thumbnail, Some(false));
        assert_eq!(g.episode_item.as_ref().unwrap().show_thumbnail, Some(true));

        let out = serde_json::to_value(&g).unwrap();
        assert_eq!(out["groupItem"]["showThumbnail"], serde_json::json!(false));
        assert_eq!(out["episodeItem"]["showThumbnail"], serde_json::json!(true));
    }

    #[test]
    fn show_thumbnail_absent_omitted() {
        let json = serde_json::json!({
            "id": "g1",
            "displayName": "G1",
            "groupItem": { "showDateRange": true }
        });
        let g: GroupDef = serde_json::from_value(json).unwrap();
        assert!(g.group_item.as_ref().unwrap().show_thumbnail.is_none());
        let out = serde_json::to_value(&g).unwrap();
        assert!(out["groupItem"].get("showThumbnail").is_none());
    }
}
```

- [ ] **Step 2: Run and confirm failure.**

```bash
cargo test -p sp_core --lib group_def::tests
```

Expected: FAIL ("no field `show_thumbnail`").

- [ ] **Step 3: Add the fields.**

In `crates/sp_core/src/models/group_def.rs`:

```rust
/// Per-group overrides for the group card.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefGroupItem {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_date_range: Option<bool>,

    /// Per-group override for the group card thumbnail. None = inherit playlist default.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_thumbnail: Option<bool>,
}
```

```rust
/// Per-group overrides for individual episode rows.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupDefEpisodeItem {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title_extractor: Option<TitleExtractor>,

    /// Per-group override for in-group episode row thumbnails. None = inherit playlist default.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_thumbnail: Option<bool>,
}
```

- [ ] **Step 4: Run and confirm pass.**

```bash
cargo test -p sp_core --lib group_def
```

Expected: PASS.

- [ ] **Step 5: Run the whole Rust workspace + clippy.**

```bash
cargo test && cargo clippy -- -W warnings
```

Expected: all green, zero warnings.

- [ ] **Step 6: Commit.**

```bash
git add crates/sp_core/src/models/group_def.rs
git commit -m "feat(sp_core): add show_thumbnail to per-group display overrides"
```

---

## Task 6: Zod schema -- mirror Rust changes

**Files:**
- Modify: `packages/sp_react/src/schemas/config-schema.ts`
- Test: `packages/sp_react/src/schemas/__tests__/config-schema.test.ts`
- Test: `packages/sp_react/src/schemas/__tests__/schema-conformance.test.ts`

- [ ] **Step 1: Add failing Zod tests.**

Append to `packages/sp_react/src/schemas/__tests__/config-schema.test.ts`:

```ts
describe('showThumbnail flags', () => {
  it('parses showThumbnail on groupItem and episodeItem', () => {
    const result = playlistDefinitionSchema.parse({
      id: 'p1',
      displayName: 'P1',
      priority: 0,
      grouping: { by: 'seasonNumber' },
      groupItem: { showThumbnail: false },
      episodeItem: { showThumbnail: false },
    });
    expect(result.groupItem?.showThumbnail).toBe(false);
    expect(result.episodeItem?.showThumbnail).toBe(false);
  });

  it('parses showThumbnail on per-group overrides', () => {
    const result = playlistDefinitionSchema.parse({
      id: 'p1',
      displayName: 'P1',
      priority: 0,
      grouping: {
        by: 'titleClassifier',
        staticClassifiers: [
          {
            id: 'g1',
            displayName: 'G1',
            pattern: { source: 'title', pattern: '.*' },
            groupItem: { showThumbnail: false },
            episodeItem: { showThumbnail: true },
          },
        ],
      },
    });
    const g = result.grouping.staticClassifiers?.[0];
    expect(g?.groupItem?.showThumbnail).toBe(false);
    expect(g?.episodeItem?.showThumbnail).toBe(true);
  });

  it('parses showEpisodeThumbnail on pattern config', () => {
    const result = patternConfigSchema.parse({
      id: 'p1',
      displayName: 'P1',
      podcastGuid: 'g',
      feedUrls: ['https://x'],
      showEpisodeThumbnail: false,
      playlists: [{
        id: 'one',
        displayName: 'One',
        priority: 0,
        grouping: { by: 'seasonNumber' },
      }],
    });
    expect(result.showEpisodeThumbnail).toBe(false);
  });

  it('defaults showEpisodeThumbnail to true when absent', () => {
    const result = patternConfigSchema.parse({
      id: 'p1',
      displayName: 'P1',
      podcastGuid: 'g',
      feedUrls: ['https://x'],
      playlists: [{
        id: 'one',
        displayName: 'One',
        priority: 0,
        grouping: { by: 'seasonNumber' },
      }],
    });
    expect(result.showEpisodeThumbnail).toBe(true);
  });
});
```

If `patternConfigSchema` is not already imported in this test file, add it to the existing import line at the top:

```ts
import { playlistDefinitionSchema, patternConfigSchema } from '../config-schema';
```

(Verify the existing import name with `head -10` of the test file.)

Append to `packages/sp_react/src/schemas/__tests__/schema-conformance.test.ts` a new `describe` near the other field assertions:

```ts
describe('showThumbnail JSON Schema fields', () => {
  it('GroupItemConfig.showThumbnail is boolean with default true', () => {
    const props = (defs.GroupItemConfig as Record<string, Record<string, unknown>>).properties as Record<string, Record<string, unknown>>;
    expect(props.showThumbnail.type).toBe('boolean');
    expect(props.showThumbnail.default).toBe(true);
  });

  it('EpisodeItemConfig.showThumbnail is boolean with default true', () => {
    const props = (defs.EpisodeItemConfig as Record<string, Record<string, unknown>>).properties as Record<string, Record<string, unknown>>;
    expect(props.showThumbnail.type).toBe('boolean');
    expect(props.showThumbnail.default).toBe(true);
  });
});
```

- [ ] **Step 2: Run and confirm failure.**

```bash
cd packages/sp_react && pnpm test -- --run config-schema schema-conformance
```

Expected: FAIL on every new case.

- [ ] **Step 3: Update Zod schemas.**

In `packages/sp_react/src/schemas/config-schema.ts`:

3a. In `groupDefSchema.groupItem`:

```ts
  groupItem: z
    .object({
      showDateRange: z.boolean().optional(),
      showThumbnail: z.boolean().optional(),
    })
    .optional(),
```

3b. In `groupDefSchema.episodeItem`:

```ts
  episodeItem: z
    .object({
      titleExtractor: titleExtractorSchema.optional(),
      showThumbnail: z.boolean().optional(),
    })
    .optional(),
```

3c. In `groupItemConfigSchema`:

```ts
export const groupItemConfigSchema = z.object({
  showDateRange: z.boolean().optional(),
  pinToYear: z.boolean().optional(),
  prependSeasonNumber: z.boolean().optional(),
  showThumbnail: z.boolean().optional(),
  titleExtractor: titleExtractorSchema.nullish(),
});
```

3d. In `episodeItemConfigSchema`:

```ts
export const episodeItemConfigSchema = z.object({
  titleExtractor: titleExtractorSchema.nullish(),
  showThumbnail: z.boolean().optional(),
});
```

3e. In `patternConfigSchema` (mirrors `yearGroupedEpisodes` style with default `true`):

```ts
export const patternConfigSchema = z.object({
  id: z.string(),
  displayName: z.string().nullish().transform((v) => v ?? ''),
  podcastGuid: z.string().nullish(),
  feedUrls: z.array(z.string()).nullish(),
  yearGroupedEpisodes: z.boolean().nullish().transform((v) => v ?? false),
  showEpisodeThumbnail: z.boolean().nullish().transform((v) => v ?? true),
  playlists: z.array(playlistDefinitionSchema),
});
```

- [ ] **Step 4: Run and confirm pass.**

```bash
cd packages/sp_react && pnpm test -- --run config-schema schema-conformance
```

Expected: PASS.

- [ ] **Step 5: Run the whole React test suite + lints + types.**

```bash
cd packages/sp_react && pnpm test -- --run && npx oxlint && npx tsc -b --noEmit
```

Expected: all green.

- [ ] **Step 6: Commit.**

```bash
git add packages/sp_react/src/schemas/
git commit -m "feat(sp_react): mirror showThumbnail and showEpisodeThumbnail in Zod"
```

---

## Task 7: Editor UI -- pattern settings card

**Files:**
- Modify: `packages/sp_react/src/components/editor/pattern-settings.tsx`

- [ ] **Step 1: Add the checkbox below the existing `yearGroupedEpisodes` checkbox.**

In `packages/sp_react/src/components/editor/pattern-settings.tsx`, locate the block that renders `yearGroupedEpisodes` (around lines 123-137 in the current file). Insert immediately after its closing `</div>`:

```tsx
        <div className="flex items-center gap-2">
          <Checkbox
            id="config-showEpisodeThumbnail"
            checked={watch('showEpisodeThumbnail') ?? true}
            onCheckedChange={(checked) =>
              setValue('showEpisodeThumbnail', !!checked, { shouldDirty: true })
            }
          />
          <HintLabel
            htmlFor="config-showEpisodeThumbnail"
            hint="showEpisodeThumbnail"
          >
            {t('showEpisodeThumbnail')}
          </HintLabel>
        </div>
```

Default `?? true` is intentional — the field is the only `show*` flag in this file whose default is on.

- [ ] **Step 2: Run the React test suite to catch any snapshot or behavior regressions.**

```bash
cd packages/sp_react && pnpm test -- --run pattern-settings
```

Expected: existing tests pass. (The locale strings will read as missing keys, returning the key itself; that is fine until Task 10 lands.)

- [ ] **Step 3: Commit.**

```bash
git add packages/sp_react/src/components/editor/pattern-settings.tsx
git commit -m "feat(sp_react): add showEpisodeThumbnail toggle to pattern settings"
```

---

## Task 8: Editor UI -- display settings tab (group + episode defaults)

**Files:**
- Modify: `packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx`

- [ ] **Step 1: Add `showThumbnail` next to `showDateRange` in `GroupsSubsection`.**

In `GroupsSubsection`, after the `showDateRange` checkbox block, append a sibling block that mirrors it but for thumbnails. Insert after the `showDateRangeHl` block (current lines 230-244):

```tsx
      <div className="flex items-center gap-2">
        <Checkbox
          id={`playlist-${index}-group-${activeContext}-showThumbnail`}
          checked={
            watchPath<boolean>(
              watch,
              isSpecific
                ? `${prefix}.grouping.staticClassifiers.${selectedIdx}.groupItem.showThumbnail`
                : `${prefix}.groupItem.showThumbnail`,
            ) ?? true
          }
          onCheckedChange={(c) =>
            setPath(
              setValue,
              isSpecific
                ? `${prefix}.grouping.staticClassifiers.${selectedIdx}.groupItem.showThumbnail`
                : `${prefix}.groupItem.showThumbnail`,
              !!c,
              { shouldDirty: true },
            )
          }
        />
        <HintLabel
          htmlFor={`playlist-${index}-group-${activeContext}-showThumbnail`}
          hint="showThumbnail"
        >
          {t('showThumbnail')}
        </HintLabel>
      </div>
```

The path is computed inline (rather than hoisted to a `const` like `showDateRangeField`) to keep the diff minimal; if the existing review style demands a hoisted const, follow the surrounding convention and add `const showThumbnailField = isSpecific ? ... : ...` at the top of the function.

- [ ] **Step 2: Add `showThumbnail` checkbox in `EpisodesSubsection`.**

In `EpisodesSubsection`, compute a parallel path and add a checkbox before the `<div {...episodeItemTitleHl}>` block:

```tsx
  const episodeShowThumbnailPath = groupPrefix != null
    ? `${groupPrefix}.episodeItem.showThumbnail`
    : `${prefix}.episodeItem.showThumbnail`;
```

Then in the JSX, after the `showYearHeaders` block (current lines 284-298) and before `episodeItemTitleHl`:

```tsx
      <div className="flex items-center gap-2">
        <Checkbox
          id={`playlist-${index}-${activeContext}-episode-showThumbnail`}
          checked={watchPath<boolean>(watch, episodeShowThumbnailPath) ?? true}
          onCheckedChange={(c) =>
            setPath(setValue, episodeShowThumbnailPath, !!c, { shouldDirty: true })
          }
        />
        <HintLabel
          htmlFor={`playlist-${index}-${activeContext}-episode-showThumbnail`}
          hint="showThumbnail"
        >
          {t('showThumbnail')}
        </HintLabel>
      </div>
```

- [ ] **Step 3: Type-check and run the existing tab tests.**

```bash
cd packages/sp_react && npx tsc -b --noEmit && pnpm test -- --run display-settings playlist-form
```

Expected: type check passes, existing tests green.

- [ ] **Step 4: Commit.**

```bash
git add packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx
git commit -m "feat(sp_react): add showThumbnail toggles to display settings tab"
```

---

## Task 9: Editor UI -- per-group override card

**Files:**
- Modify: `packages/sp_react/src/components/editor/group-def-card.tsx`

- [ ] **Step 1: Add the override checkbox in the `displayOverrides` row.**

In `packages/sp_react/src/components/editor/group-def-card.tsx`, the existing display overrides block (lines 195-227 in the current file) renders `showYearHeaders` and `showDateRange` side by side. Add a third checkbox in the same `flex gap-6` row:

```tsx
          <div className="flex items-center gap-2">
            <Checkbox
              id={`group-${playlistIndex}-${groupIndex}-showThumbnail`}
              checked={watch(`${prefix}.groupItem.showThumbnail`) ?? true}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.groupItem.showThumbnail`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel
              htmlFor={`group-${playlistIndex}-${groupIndex}-showThumbnail`}
              hint="showThumbnail"
            >
              {t('showThumbnail')}
            </HintLabel>
          </div>
```

Place it after the existing `showDateRange` block, inside the same `<div className="flex gap-6">`. If three checkboxes wrap awkwardly at narrow widths, that is acceptable -- it matches the layout used elsewhere in the form. Don't restructure the row in this task.

- [ ] **Step 2: Type-check.**

```bash
cd packages/sp_react && npx tsc -b --noEmit
```

Expected: pass.

- [ ] **Step 3: Run existing group form tests.**

```bash
cd packages/sp_react && pnpm test -- --run groups-form group-def-card
```

Expected: green. If the test file is named differently, run `pnpm test -- --run` to run all and pick out failures.

- [ ] **Step 4: Commit.**

```bash
git add packages/sp_react/src/components/editor/group-def-card.tsx
git commit -m "feat(sp_react): add showThumbnail per-group override on GroupDefCard"
```

---

## Task 10: Locales -- labels and hints (en + ja)

**Files:**
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`
- Modify: `packages/sp_react/src/locales/en/hints.json`
- Modify: `packages/sp_react/src/locales/ja/hints.json`

- [ ] **Step 1: Add labels to `editor.json` (en, ja).**

In `packages/sp_react/src/locales/en/editor.json`, near the existing `"showDateRange"` and `"yearGroupedEpisodes"` keys, add:

```json
  "showEpisodeThumbnail": "Show episode thumbnails in main episode list",
  "showThumbnail": "Show thumbnails on entries",
```

In `packages/sp_react/src/locales/ja/editor.json`, near the matching keys:

```json
  "showEpisodeThumbnail": "メインのエピソード一覧にサムネイルを表示",
  "showThumbnail": "各エントリにサムネイルを表示",
```

(Pick a position consistent with the surrounding alphabetical or topical grouping in the file.)

- [ ] **Step 2: Add hints to `hints.json` (en, ja).**

In `packages/sp_react/src/locales/en/hints.json`, near `"yearGroupedEpisodes"` and `"showDateRange"`:

```json
  "showEpisodeThumbnail": "When enabled, each episode in the podcast's main episode list shows its thumbnail (or the podcast artwork). Disable for podcasts whose episodes share uniform artwork.",
  "showThumbnail": "When enabled, each entry in this list shows a thumbnail. Disable to render a denser, text-only list.",
```

In `packages/sp_react/src/locales/ja/hints.json`:

```json
  "showEpisodeThumbnail": "有効にすると、ポッドキャストのメインエピソード一覧の各行にサムネイル（無い場合は番組画像）が表示されます。各回が同一画像の場合は無効化を推奨します。",
  "showThumbnail": "有効にすると、この一覧の各エントリにサムネイルが表示されます。無効にすると文字主体の密な一覧になります。",
```

- [ ] **Step 3: Verify JSON validity.**

```bash
cd packages/sp_react && python3 -m json.tool src/locales/en/editor.json > /dev/null \
  && python3 -m json.tool src/locales/ja/editor.json > /dev/null \
  && python3 -m json.tool src/locales/en/hints.json > /dev/null \
  && python3 -m json.tool src/locales/ja/hints.json > /dev/null \
  && echo OK
```

Expected: prints `OK`.

- [ ] **Step 4: Run lints + tests.**

```bash
cd packages/sp_react && npx oxlint && pnpm test -- --run
```

Expected: green.

- [ ] **Step 5: Commit.**

```bash
git add packages/sp_react/src/locales/
git commit -m "feat(sp_react): localize showThumbnail and showEpisodeThumbnail strings"
```

---

## Task 11: Schema reference docs and HTML regeneration

**Files:**
- Modify: `docs/schema-reference.md`
- Regenerate: schema HTML via `make schema-doc`

- [ ] **Step 1: Document `showEpisodeThumbnail` in pattern meta.**

In `docs/schema-reference.md`, find the Pattern Meta `### Fields` table (around lines 110-117). Insert a new row between `yearGroupedEpisodes` and `playlists`:

```
| `showEpisodeThumbnail` | boolean | no | `true` | Show thumbnails on each row of the main podcast episode list. The page header artwork is unaffected. |
```

In the example block immediately below (around line 121-132), add the field before `"playlists"`:

```json
  "yearGroupedEpisodes": true,
  "showEpisodeThumbnail": false,
  "playlists": ["regular", "extras", "shorts"]
```

- [ ] **Step 2: Document `showThumbnail` in `groupItem`.**

Find `### groupItem` (around line 300). Insert a row in the field table after `prependSeasonNumber`:

```
| `showThumbnail` | boolean | `true` | Show a thumbnail on each group card in this playlist. |
```

In the example block below the table, append `"showThumbnail": false,` (preserve trailing-comma convention).

- [ ] **Step 3: Document `showThumbnail` in `episodeItem`.**

Find `### episodeItem` (around line 353). Add a row to its field table:

```
| `showThumbnail` | boolean | Show a thumbnail on each episode row inside a group. Default `true`. |
```

In the example, add `"showThumbnail": false` alongside `"titleExtractor"`.

- [ ] **Step 4: Document the per-group overrides.**

Search for the per-classifier override table (`grep -n "Per-classifier override" docs/schema-reference.md`). Update the listed fields under each block (around lines 638-653) to include `showThumbnail`:

```
| `groupItem` | `showDateRange`, `showThumbnail`, `pinToYear` |
| `episodeItem` | `titleExtractor`, `showThumbnail` |
```

(Match the exact existing table format -- this plan shows the substantive change, not the surrounding markdown.)

- [ ] **Step 5: Regenerate the HTML schema doc.**

```bash
make schema-doc
```

Expected: rebuilds `docs/schema/*.html` (or wherever the Makefile target writes). If the make target is missing or fails, run the underlying script directly (`grep -n "schema-doc" Makefile` to find the command).

- [ ] **Step 6: Visually skim the markdown diff to make sure tables still render.**

```bash
git diff docs/schema-reference.md | head -120
```

- [ ] **Step 7: Commit.**

```bash
git add docs/schema-reference.md docs/schema/  # second path only if make schema-doc wrote files
git commit -m "docs: document showThumbnail and showEpisodeThumbnail fields"
```

---

## Task 12: Final verification (mandatory project checklist)

**Files:** none (verification only)

- [ ] **Step 1: Full Rust test + clippy.**

```bash
cargo test && cargo clippy -- -W warnings
```

Expected: all green, zero warnings.

- [ ] **Step 2: Full React test + lint + type.**

```bash
cd packages/sp_react && pnpm test -- --run && npx oxlint && npx tsc -b --noEmit
```

Expected: all green.

- [ ] **Step 3: Repo aggregates.**

```bash
make lint && make test
```

Expected: green.

- [ ] **Step 4: Smoke-test in the editor (manual).**

```bash
cargo run -p sp_cli -- serve --data-dir ../audiflow-smartplaylist
```

Open the editor in a browser, load any pattern, and verify:

1. Pattern settings shows the new "Show episode thumbnails" checkbox; toggling it dirties the form and persists to `meta.json` as `showEpisodeThumbnail: false` (omitted when true).
2. A playlist's display-settings tab shows two new "Show thumbnails" toggles -- one in the Groups subsection, one in the Episodes subsection.
3. A `titleClassifier` group's per-group override shows the third toggle alongside `showDateRange`/`showYearHeaders`.

Document any UX-only issues (label clarity, layout) but do not block on them — they are separate from this schema/data change.

- [ ] **Step 5: Confirm no leftover changes.**

```bash
git status
```

Expected: clean (or only untracked unrelated files).
