# Schema V4 Renames Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt schema v4 renames from the data repo (`audiflow-smartplaylist` feat/v4 branch) into this editor.

**Architecture:** Mechanical rename across all layers (Rust models, resolvers, JSON schemas, React/TS schemas, components, i18n, tests). No behavioral changes. Serde `rename_all = "camelCase"` handles JSON key mapping automatically for Rust field renames.

**Tech Stack:** Rust (serde, regex), React 19, TypeScript (Zod 4), i18next

---

## Rename Map

| Layer | Old | New |
|-------|-----|-----|
| Resolver type | `"rss"` | `"seasonNumber"` |
| Resolver type | `"category"` | `"titleClassifier"` |
| Resolver type | `"titleAppearanceOrder"` | `"titleDiscovery"` |
| JSON field | `episodeExtractor` | `numberingExtractor` |
| Rust field | `episode_extractor` | `numbering_extractor` |
| Rust struct | `EpisodeExtractor` | `NumberingExtractor` |
| Rust struct | `CompiledEpisodeExtractor` | `CompiledNumberingExtractor` |
| Rust struct | `EpisodeExtractionResult` | `NumberingExtractionResult` |
| Rust module | `episode_extractor` | `numbering_extractor` |
| Schema `$id` | `schema/v3/` | `schema/v4/` |

---

### Task 1: Copy schema JSON files from data repo

**Files:**
- Overwrite: `crates/sp_core/assets/playlist-definition.schema.json`
- Overwrite: `crates/sp_core/assets/pattern-index.schema.json`
- Overwrite: `crates/sp_core/assets/pattern-meta.schema.json`

- [ ] **Step 1: Copy all three schema files from the data repo**

```bash
cp /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist.feat-v4/schema/playlist-definition.schema.json \
   crates/sp_core/assets/playlist-definition.schema.json

cp /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist.feat-v4/schema/pattern-index.schema.json \
   crates/sp_core/assets/pattern-index.schema.json

cp /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist.feat-v4/schema/pattern-meta.schema.json \
   crates/sp_core/assets/pattern-meta.schema.json
```

- [ ] **Step 2: Commit**

```bash
git add crates/sp_core/assets/
git commit -m "chore(schema): update embedded schemas to v4"
```

---

### Task 2: Rename Rust model file and types (episode_extractor -> numbering_extractor)

**Files:**
- Rename: `crates/sp_core/src/models/episode_extractor.rs` -> `crates/sp_core/src/models/numbering_extractor.rs`
- Modify: `crates/sp_core/src/models/mod.rs`

- [ ] **Step 1: Rename the file**

```bash
git mv crates/sp_core/src/models/episode_extractor.rs crates/sp_core/src/models/numbering_extractor.rs
```

- [ ] **Step 2: Rename types in `numbering_extractor.rs`**

In `crates/sp_core/src/models/numbering_extractor.rs`:
- `EpisodeExtractionResult` -> `NumberingExtractionResult` (lines 41, 46)
- `EpisodeExtractor` -> `NumberingExtractor` (lines 56, 103-108, 113, 116, 122, 133)
- `CompiledEpisodeExtractor` -> `CompiledNumberingExtractor` (lines 107, 122, 146)

All doc comments referencing these names should also be updated.

- [ ] **Step 3: Update `mod.rs` module declaration and re-exports**

In `crates/sp_core/src/models/mod.rs`:
- Line 2: `pub mod episode_extractor;` -> `pub mod numbering_extractor;`
- Line 23: `pub use episode_extractor::{CompiledEpisodeExtractor, EpisodeExtractionResult, EpisodeExtractor};` -> `pub use numbering_extractor::{CompiledNumberingExtractor, NumberingExtractionResult, NumberingExtractor};`

- [ ] **Step 4: Verify it compiles (expect errors from downstream files -- that's OK for now)**

```bash
cargo check 2>&1 | head -20
```

Expected: errors about unresolved imports in playlist_definition.rs, group_def.rs, and tests. This is correct -- we fix those next.

- [ ] **Step 5: Commit**

```bash
git add crates/sp_core/src/models/
git commit -m "refactor(core): rename EpisodeExtractor to NumberingExtractor"
```

---

### Task 3: Update Rust model consumers (playlist_definition, group_def)

**Files:**
- Modify: `crates/sp_core/src/models/playlist_definition.rs`
- Modify: `crates/sp_core/src/models/group_def.rs`

- [ ] **Step 1: Update `playlist_definition.rs`**

In `crates/sp_core/src/models/playlist_definition.rs`:
- Line 3: `use super::episode_extractor::EpisodeExtractor;` -> `use super::numbering_extractor::NumberingExtractor;`
- Line 48: `pub episode_extractor: Option<EpisodeExtractor>,` -> `pub numbering_extractor: Option<NumberingExtractor>,`

- [ ] **Step 2: Update `group_def.rs`**

In `crates/sp_core/src/models/group_def.rs`:
- Line 3: `use super::episode_extractor::EpisodeExtractor;` -> `use super::numbering_extractor::NumberingExtractor;`
- Line 24: `pub episode_extractor: Option<EpisodeExtractor>,` -> `pub numbering_extractor: Option<NumberingExtractor>,`

- [ ] **Step 3: Commit**

```bash
git add crates/sp_core/src/models/playlist_definition.rs crates/sp_core/src/models/group_def.rs
git commit -m "refactor(core): update model fields to numbering_extractor"
```

---

### Task 4: Update resolver type strings

**Files:**
- Modify: `crates/sp_core/src/resolvers/rss_resolver.rs`
- Modify: `crates/sp_core/src/resolvers/category_resolver.rs`
- Modify: `crates/sp_core/src/resolvers/title_appearance_resolver.rs`

- [ ] **Step 1: Update `rss_resolver.rs`**

In `crates/sp_core/src/resolvers/rss_resolver.rs`:
- Line 14: `"rss"` -> `"seasonNumber"`

- [ ] **Step 2: Update `category_resolver.rs`**

In `crates/sp_core/src/resolvers/category_resolver.rs`:
- Line 26: `"category"` -> `"titleClassifier"`

- [ ] **Step 3: Update `title_appearance_resolver.rs`**

In `crates/sp_core/src/resolvers/title_appearance_resolver.rs`:
- Line 22: `"titleAppearanceOrder"` -> `"titleDiscovery"`

- [ ] **Step 4: Commit**

```bash
git add crates/sp_core/src/resolvers/
git commit -m "refactor(core): rename resolver type strings to v4"
```

---

### Task 5: Update sp_server references

**Files:**
- Modify: `crates/sp_server/src/routes/preview.rs`
- Modify: `crates/sp_server/src/services/local_config_repository.rs`

- [ ] **Step 1: Update `preview.rs` imports**

In `crates/sp_server/src/routes/preview.rs`:
- Line 9: `EpisodeExtractor` -> `NumberingExtractor` in the import
- Lines 221, 252: `extractor: &EpisodeExtractor` -> `extractor: &NumberingExtractor`

- [ ] **Step 2: Update `local_config_repository.rs` test fixtures**

In `crates/sp_server/src/services/local_config_repository.rs`:
- Line 313: `"resolverType": "rss"` -> `"resolverType": "seasonNumber"`
- Line 355: `assert_eq!(playlist.resolver_type, "rss")` -> `assert_eq!(playlist.resolver_type, "seasonNumber")`
- Line 381: `"resolverType": "category"` -> `"resolverType": "titleClassifier"`
- Line 405: `"resolverType": "rss"` -> `"resolverType": "seasonNumber"`

Also update field references:
- Any `"episodeExtractor"` in JSON literals -> `"numberingExtractor"`
- Any `.episode_extractor` field access -> `.numbering_extractor`

- [ ] **Step 3: Commit**

```bash
git add crates/sp_server/
git commit -m "refactor(server): update to v4 schema naming"
```

---

### Task 6: Update sp_cli references

**Files:**
- Modify: `crates/sp_cli/src/cmd_bump_versions.rs`

- [ ] **Step 1: Update resolver type strings in test fixtures**

In `crates/sp_cli/src/cmd_bump_versions.rs`:
- Line 423: `"resolverType": "category"` -> `"resolverType": "titleClassifier"`
- Line 442: `"resolverType": "rss"` -> `"resolverType": "seasonNumber"`
- Line 514: `"resolverType": "category"` -> `"resolverType": "titleClassifier"`
- Line 532: `"resolverType": "rss"` -> `"resolverType": "seasonNumber"`

- [ ] **Step 2: Commit**

```bash
git add crates/sp_cli/
git commit -m "refactor(cli): update to v4 schema naming"
```

---

### Task 7: Run and fix all Rust tests

**Files:**
- Modify: `crates/sp_core/tests/model_tests.rs`
- Modify: `crates/sp_core/tests/resolver_tests.rs`
- Modify: `crates/sp_core/tests/service_tests.rs`
- Modify: `crates/sp_core/tests/schema_tests.rs`

- [ ] **Step 1: Update `model_tests.rs`**

Replace all occurrences:
- `"resolverType": "rss"` -> `"resolverType": "seasonNumber"`
- `"episodeExtractor"` (JSON key in test fixtures) -> `"numberingExtractor"`
- `EpisodeExtractor` (type in test code) -> `NumberingExtractor`
- `EpisodeExtractionResult` -> `NumberingExtractionResult` (if used)
- Comments referencing "EpisodeExtractor" -> "NumberingExtractor"

- [ ] **Step 2: Update `resolver_tests.rs`**

Replace all occurrences:
- `"rss"` -> `"seasonNumber"` (in `resolver_type()` assertions and `minimal_definition()` calls)
- `"category"` -> `"titleClassifier"`
- `"titleAppearanceOrder"` -> `"titleDiscovery"`
- Any `.episode_extractor` field access -> `.numbering_extractor`

- [ ] **Step 3: Update `service_tests.rs`**

Replace all occurrences:
- `resolver_type: "rss".to_string()` -> `resolver_type: "seasonNumber".to_string()`
- `assert_eq!(result.unwrap().resolver_type, "rss")` -> `assert_eq!(result.unwrap().resolver_type, "seasonNumber")`
- Any `.episode_extractor` field access -> `.numbering_extractor`

- [ ] **Step 4: Update `schema_tests.rs`**

Replace all occurrences:
- `"resolverType": "rss"` -> `"resolverType": "seasonNumber"`

- [ ] **Step 5: Run all Rust tests**

```bash
cargo test
```

Expected: all tests pass.

- [ ] **Step 6: Run clippy**

```bash
cargo clippy -- -W warnings
```

Expected: zero warnings.

- [ ] **Step 7: Commit**

```bash
git add crates/sp_core/tests/ crates/sp_server/ crates/sp_cli/
git commit -m "test(core): update all test fixtures for v4 schema naming"
```

---

### Task 8: Update React/TypeScript Zod schema

**Files:**
- Modify: `packages/sp_react/src/schemas/config-schema.ts`

- [ ] **Step 1: Update resolver type enum**

In `packages/sp_react/src/schemas/config-schema.ts`:
- Lines 23-28: Change resolver type enum values:

```typescript
export const resolverTypeSchema = z.enum([
  'seasonNumber',
  'titleClassifier',
  'year',
  'titleDiscovery',
]);
```

- [ ] **Step 2: Rename episodeExtractorSchema to numberingExtractorSchema**

- Line 93: `export const episodeExtractorSchema` -> `export const numberingExtractorSchema`

- [ ] **Step 3: Update groupDefSchema field**

- Line 123: `episodeExtractor: episodeExtractorSchema.optional()` -> `numberingExtractor: numberingExtractorSchema.optional()`

- [ ] **Step 4: Update playlistDefinitionSchema field**

- Line 144: `episodeExtractor: episodeExtractorSchema.nullish()` -> `numberingExtractor: numberingExtractorSchema.nullish()`

- [ ] **Step 5: Update type export**

- Line 174: `export type EpisodeExtractor` -> `export type NumberingExtractor`

- [ ] **Step 6: Commit**

```bash
git add packages/sp_react/src/schemas/config-schema.ts
git commit -m "refactor(react): update Zod schema for v4 naming"
```

---

### Task 9: Rename React component file (episode-extractor-form -> numbering-extractor-form)

**Files:**
- Rename: `packages/sp_react/src/components/editor/episode-extractor-form.tsx` -> `numbering-extractor-form.tsx`
- Modify: (content within the renamed file)

- [ ] **Step 1: Rename the file**

```bash
git mv packages/sp_react/src/components/editor/episode-extractor-form.tsx \
       packages/sp_react/src/components/editor/numbering-extractor-form.tsx
```

- [ ] **Step 2: Rename the component export**

In `numbering-extractor-form.tsx`:
- Line 20: `interface EpisodeExtractorFormProps` -> `interface NumberingExtractorFormProps`
- Line 25: `export function EpisodeExtractorForm(` -> `export function NumberingExtractorForm(`

Note: Keep i18n keys as-is for now (they're updated in Task 12). The form's `fieldPath` prop is passed by the parent and will be updated there.

- [ ] **Step 3: Commit**

```bash
git add packages/sp_react/src/components/editor/
git commit -m "refactor(react): rename EpisodeExtractorForm to NumberingExtractorForm"
```

---

### Task 10: Update React component imports and field paths

**Files:**
- Modify: `packages/sp_react/src/components/editor/extractors-form.tsx`
- Modify: `packages/sp_react/src/components/editor/group-def-card.tsx`
- Modify: `packages/sp_react/src/components/editor/playlist-form.tsx`
- Modify: `packages/sp_react/src/components/editor/config-form.tsx`
- Modify: `packages/sp_react/src/components/editor/title-extractor-form.tsx`

- [ ] **Step 1: Update `extractors-form.tsx`**

- Line 5: `import { EpisodeExtractorForm }` -> `import { NumberingExtractorForm }` from `'./numbering-extractor-form.tsx'`
- Line 24-26: `<EpisodeExtractorForm` -> `<NumberingExtractorForm`
- Line 25: `fieldPath={\`playlists.${index}.episodeExtractor\`}` -> `fieldPath={\`playlists.${index}.numberingExtractor\`}`

- [ ] **Step 2: Update `group-def-card.tsx`**

- Line 24: `import { EpisodeExtractorForm }` -> `import { NumberingExtractorForm }` from `'./numbering-extractor-form.tsx'`
- Line 56: `watch(\`${prefix}.episodeExtractor\` as any)` -> `watch(\`${prefix}.numberingExtractor\` as any)`
- Line 63: `items.push('episodeExtractor')` -> `items.push('numberingExtractor')`
- Line 232: `<AccordionItem value="episodeExtractor">` -> `<AccordionItem value="numberingExtractor">`
- Lines 237-238: `<EpisodeExtractorForm` -> `<NumberingExtractorForm` with `fieldPath={\`${prefix}.numberingExtractor\`}`

- [ ] **Step 3: Update `playlist-form.tsx`**

- Lines 27-32: Update RESOLVER_TYPES array:

```typescript
const RESOLVER_TYPES = [
  'seasonNumber',
  'titleClassifier',
  'year',
  'titleDiscovery',
] as const;
```

- Line 316: `resolverType === 'rss'` -> `resolverType === 'seasonNumber'`

- [ ] **Step 4: Update `config-form.tsx`**

- Line 4: `resolverType: 'rss'` -> `resolverType: 'seasonNumber'`

- [ ] **Step 5: Update `title-extractor-form.tsx`**

- Line 126: `resolverType === 'category'` -> `resolverType === 'titleClassifier'`

- [ ] **Step 6: Commit**

```bash
git add packages/sp_react/src/components/editor/
git commit -m "refactor(react): update components for v4 naming"
```

---

### Task 11: Update React test fixtures and mocks

**Files:**
- Modify: `packages/sp_react/src/mocks/fixtures.ts`
- Modify: `packages/sp_react/src/schemas/__tests__/config-schema.test.ts`
- Modify: `packages/sp_react/src/schemas/__tests__/schema-conformance.test.ts`
- Modify: `packages/sp_react/src/schemas/__tests__/api-schema.test.ts`
- Modify: `packages/sp_react/src/components/editor/__tests__/playlist-form.test.tsx`

- [ ] **Step 1: Update `fixtures.ts`**

- Line 43: `resolverType: 'rss'` -> `resolverType: 'seasonNumber'`
- Line 59: `resolverType: 'category'` -> `resolverType: 'titleClassifier'`
- Line 117: `resolverType: 'rss'` -> `resolverType: 'seasonNumber'`

- [ ] **Step 2: Update `config-schema.test.ts`**

- Line 7: `episodeExtractorSchema` -> `numberingExtractorSchema`
- All `episodeExtractor` JSON keys in test objects -> `numberingExtractor`
- All `result.episodeExtractor` assertions -> `result.numberingExtractor`
- Line 311: `describe('episodeExtractorSchema'` -> `describe('numberingExtractorSchema'`
- All `episodeExtractorSchema.parse(` -> `numberingExtractorSchema.parse(`

- [ ] **Step 3: Update `schema-conformance.test.ts`**

- Line 138: `episodeExtractor:` -> `numberingExtractor:` in test fixture

- [ ] **Step 4: Update `api-schema.test.ts`**

Search for any `episodeExtractor` or resolver type references and update accordingly.

- [ ] **Step 5: Update `playlist-form.test.tsx`**

- Line 18: `resolverType: 'rss'` -> `resolverType: 'seasonNumber'`
- Line 92: `'when resolverType is rss'` -> `'when resolverType is seasonNumber'`
- Line 99: `'when resolverType is not rss'` -> `'when resolverType is not seasonNumber'`
- Update any test setup that sets resolver type values

- [ ] **Step 6: Run React tests**

```bash
cd packages/sp_react && pnpm test -- --run
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add packages/sp_react/src/
git commit -m "test(react): update test fixtures for v4 schema naming"
```

---

### Task 12: Update i18n locale files

**Files:**
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`
- Modify: `packages/sp_react/src/locales/en/hints.json`
- Modify: `packages/sp_react/src/locales/ja/hints.json`

- [ ] **Step 1: Update `en/editor.json`**

Rename keys (keep display values human-readable -- update descriptions to match new names):
- `"resolverLabel_rss"` -> `"resolverLabel_seasonNumber"` (value: "Season Number")
- `"resolverLabel_category"` -> `"resolverLabel_titleClassifier"` (value: "Title Classifier")
- `"resolverLabel_titleAppearanceOrder"` -> `"resolverLabel_titleDiscovery"` (value: "Title Discovery")
- `"resolverDesc_rss"` -> `"resolverDesc_seasonNumber"` (value: "Groups episodes by season number from RSS feed metadata or title extraction")
- `"resolverDesc_category"` -> `"resolverDesc_titleClassifier"` (value: "Groups episodes by matching titles against regex patterns")
- `"resolverDesc_titleAppearanceOrder"` -> `"resolverDesc_titleDiscovery"` (value: "Groups episodes by recurring title pattern, ordered by first appearance")
- `"episodeExtractor"` -> `"numberingExtractor"` (value: "Numbering Extractor")
- `"episodeExtractorSource"` -> `"numberingExtractorSource"` (value: "Source")
- `"episodeExtractorPattern"` -> `"numberingExtractorPattern"` (value: "Pattern (regex)")
- `"episodeExtractorSeasonGroup"` -> `"numberingExtractorSeasonGroup"` (value: "Season Capture Group")
- `"episodeExtractorEpisodeGroup"` -> `"numberingExtractorEpisodeGroup"` (value: "Episode Capture Group")
- `"episodeExtractorFallbackSeason"` -> `"numberingExtractorFallbackSeason"` (value: "Fallback Season Number")
- `"episodeExtractorFallbackPattern"` -> `"numberingExtractorFallbackPattern"` (value: "Fallback Episode Pattern")
- `"episodeExtractorFallbackCaptureGroup"` -> `"numberingExtractorFallbackCaptureGroup"` (value: "Fallback Capture Group")
- `"episodeExtractorFallbackToRss"` -> `"numberingExtractorFallbackToRss"` (value: "Fallback to RSS")
- `"groupEpisodeExtractor"` -> `"groupNumberingExtractor"` (value: "Numbering Extractor")
- `"titleExtractorDisabledNote"`: update "Category resolver" -> "Title Classifier resolver"

- [ ] **Step 2: Update `ja/editor.json`**

Same key renames as English. Update display values:
- `"resolverLabel_rss"` -> `"resolverLabel_seasonNumber"` (value: "シーズン番号")
- `"resolverLabel_category"` -> `"resolverLabel_titleClassifier"` (value: "タイトル分類")
- `"resolverLabel_titleAppearanceOrder"` -> `"resolverLabel_titleDiscovery"` (value: "タイトル探索")
- `"resolverDesc_rss"` -> `"resolverDesc_seasonNumber"` (value: "RSS フィードメタデータまたはタイトル抽出のシーズン番号でグループ化")
- `"resolverDesc_category"` -> `"resolverDesc_titleClassifier"` (value: "タイトルを正規表現パターンで照合してグループ化")
- `"resolverDesc_titleAppearanceOrder"` -> `"resolverDesc_titleDiscovery"` (value: "タイトルの繰り返しパターンで出現順にグループ化")
- `"episodeExtractor"` -> `"numberingExtractor"` (value: "ナンバリング抽出器")
- `"episodeExtractorSource"` -> `"numberingExtractorSource"` (value: "ソース")
- `"episodeExtractorPattern"` -> `"numberingExtractorPattern"` (value: "パターン（正規表現）")
- `"episodeExtractorSeasonGroup"` -> `"numberingExtractorSeasonGroup"` (value: "シーズンキャプチャグループ")
- `"episodeExtractorEpisodeGroup"` -> `"numberingExtractorEpisodeGroup"` (value: "エピソードキャプチャグループ")
- `"episodeExtractorFallbackSeason"` -> `"numberingExtractorFallbackSeason"` (value: "フォールバックシーズン番号")
- `"episodeExtractorFallbackPattern"` -> `"numberingExtractorFallbackPattern"` (value: "フォールバックエピソードパターン")
- `"episodeExtractorFallbackCaptureGroup"` -> `"numberingExtractorFallbackCaptureGroup"` (value: "フォールバックキャプチャグループ")
- `"episodeExtractorFallbackToRss"` -> `"numberingExtractorFallbackToRss"` (value: "RSS にフォールバック")
- `"groupEpisodeExtractor"` -> `"groupNumberingExtractor"` (value: "ナンバリング抽出器")
- `"titleExtractorDisabledNote"`: update "カテゴリリゾルバ" -> "タイトル分類リゾルバ"

- [ ] **Step 3: Update `en/hints.json`**

Rename keys:
- `"resolverType_rss"` -> `"resolverType_seasonNumber"` (update description to mention both title extraction and RSS)
- `"resolverType_category"` -> `"resolverType_titleClassifier"` (keep same description)
- `"resolverType_titleAppearanceOrder"` -> `"resolverType_titleDiscovery"` (keep same description)
- `"episodeExtractor"` -> `"numberingExtractor"` (keep same description)
- `"episodeExtractorSource"` -> `"numberingExtractorSource"`
- `"episodeExtractorPattern"` -> `"numberingExtractorPattern"`
- `"episodeExtractorSeasonGroup"` -> `"numberingExtractorSeasonGroup"`
- `"episodeExtractorEpisodeGroup"` -> `"numberingExtractorEpisodeGroup"`
- `"episodeExtractorFallbackSeason"` -> `"numberingExtractorFallbackSeason"`
- `"episodeExtractorFallbackPattern"` -> `"numberingExtractorFallbackPattern"`
- `"episodeExtractorFallbackCaptureGroup"` -> `"numberingExtractorFallbackCaptureGroup"`
- `"episodeExtractorFallbackToRss"` -> `"numberingExtractorFallbackToRss"`
- `"groupEpisodeExtractor"` -> `"groupNumberingExtractor"`

- [ ] **Step 4: Update `ja/hints.json`**

Same key renames as English hints.

- [ ] **Step 5: Commit**

```bash
git add packages/sp_react/src/locales/
git commit -m "refactor(i18n): update locale keys for v4 schema naming"
```

---

### Task 13: Update i18n key references in React components

**Files:**
- Modify: `packages/sp_react/src/components/editor/numbering-extractor-form.tsx`
- Modify: `packages/sp_react/src/components/editor/group-def-card.tsx`

- [ ] **Step 1: Update `numbering-extractor-form.tsx` i18n keys**

Replace all `t('episodeExtractor...')` calls and `hint="episodeExtractor..."` props:
- `t('episodeExtractor')` -> `t('numberingExtractor')`
- `hint="episodeExtractor"` -> `hint="numberingExtractor"`
- `hint="episodeExtractorSource"` -> `hint="numberingExtractorSource"`
- `t('episodeExtractorSource')` -> `t('numberingExtractorSource')`
- `hint="episodeExtractorPattern"` -> `hint="numberingExtractorPattern"`
- `t('episodeExtractorPattern')` -> `t('numberingExtractorPattern')`
- `hint="episodeExtractorSeasonGroup"` -> `hint="numberingExtractorSeasonGroup"`
- `t('episodeExtractorSeasonGroup')` -> `t('numberingExtractorSeasonGroup')`
- `hint="episodeExtractorEpisodeGroup"` -> `hint="numberingExtractorEpisodeGroup"`
- `t('episodeExtractorEpisodeGroup')` -> `t('numberingExtractorEpisodeGroup')`
- `hint="episodeExtractorFallbackToRss"` -> `hint="numberingExtractorFallbackToRss"`
- `t('episodeExtractorFallbackToRss')` -> `t('numberingExtractorFallbackToRss')`
- `hint="episodeExtractorFallbackSeason"` -> `hint="numberingExtractorFallbackSeason"`
- `t('episodeExtractorFallbackSeason')` -> `t('numberingExtractorFallbackSeason')`
- `hint="episodeExtractorFallbackCaptureGroup"` -> `hint="numberingExtractorFallbackCaptureGroup"`
- `t('episodeExtractorFallbackCaptureGroup')` -> `t('numberingExtractorFallbackCaptureGroup')`
- `hint="episodeExtractorFallbackPattern"` -> `hint="numberingExtractorFallbackPattern"`
- `t('episodeExtractorFallbackPattern')` -> `t('numberingExtractorFallbackPattern')`

- [ ] **Step 2: Update `group-def-card.tsx` i18n keys**

- `t('groupEpisodeExtractor')` -> `t('groupNumberingExtractor')`
- `hint="groupEpisodeExtractor"` -> `hint="groupNumberingExtractor"`

- [ ] **Step 3: Run React tests and type check**

```bash
cd packages/sp_react && pnpm test -- --run && npx tsc -b --noEmit
```

Expected: all tests pass, no type errors.

- [ ] **Step 4: Commit**

```bash
git add packages/sp_react/src/components/
git commit -m "refactor(react): update i18n key references for v4 naming"
```

---

### Task 14: Update schema docs (public/docs)

**Files:**
- Modify: `packages/sp_react/public/docs/schema.json`
- Modify: `packages/sp_react/public/docs/schema.html`

- [ ] **Step 1: Update `schema.json`**

This should match the new `playlist-definition.schema.json`. If it's a copy, replace it:

```bash
cp crates/sp_core/assets/playlist-definition.schema.json packages/sp_react/public/docs/schema.json
```

- [ ] **Step 2: Update `schema.html`**

Search for and replace any references to old resolver type names and episodeExtractor in the HTML file.

- [ ] **Step 3: Commit**

```bash
git add packages/sp_react/public/docs/
git commit -m "docs: update schema docs for v4"
```

---

### Task 15: Update project documentation

**Files:**
- Modify: `CLAUDE.md` (if it references episodeExtractor or resolver types)
- Modify: `.claude/rules/project/architecture.md`
- Modify: `docs/overview.md`
- Modify: `docs/architecture/module-boundaries.md`
- Modify: `docs/integration/editor-to-schema.md`

- [ ] **Step 1: Update `CLAUDE.md`**

Update the "Episode resolver logic" line to mention new resolver type names.

- [ ] **Step 2: Update `.claude/rules/project/architecture.md`**

Update the Models table and Resolver Chain section:
- `EpisodeExtractor` -> `NumberingExtractor`
- `RssResolver` descriptions mentioning "rss" -> "seasonNumber"
- `CategoryResolver` descriptions mentioning "category" -> "titleClassifier"
- `TitleAppearanceResolver` descriptions mentioning "titleAppearanceOrder" -> "titleDiscovery"
- `GroupDef` field description: `episode_extractor` -> `numbering_extractor`

- [ ] **Step 3: Update `docs/overview.md`, `docs/architecture/module-boundaries.md`, `docs/integration/editor-to-schema.md`**

Search and replace old names in these files.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md .claude/ docs/
git commit -m "docs: update documentation for v4 schema naming"
```

---

### Task 16: Final validation

- [ ] **Step 1: Run all Rust tests and clippy**

```bash
cargo test && cargo clippy -- -W warnings
```

Expected: all tests pass, zero warnings.

- [ ] **Step 2: Run all React tests and linting**

```bash
cd packages/sp_react && pnpm test -- --run && npx oxlint && npx tsc -b --noEmit
```

Expected: all pass.

- [ ] **Step 3: Full lint check**

```bash
make lint && make test
```

Expected: all pass.
