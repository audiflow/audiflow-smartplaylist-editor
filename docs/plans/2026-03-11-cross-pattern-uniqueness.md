# Cross-Pattern Uniqueness Validation

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent two patterns from claiming the same podcast by enforcing that `podcastGuid` and `feedUrls` values are unique across all patterns.

**Architecture:** Add a reusable validation function in `sp_core` that checks for duplicate `podcastGuid` and `feedUrls` across a set of `PatternMeta` entries. Wire it into three gates: (a) the editor frontend (instant inline warnings as the user types), (b) the editor API server (create/update pattern meta handlers), and (c) the CLI `validate` command for CI. The frontend fetches all pattern identifiers via a lightweight endpoint and checks locally -- no round-trip per keystroke.

**Tech Stack:** Rust (sp_core, sp_server, sp_cli), React (sp_react), TanStack Query, React Hook Form, i18next

---

### Task 1: Add cross-pattern uniqueness validator to sp_core

**Files:**
- Create: `crates/sp_core/src/services/uniqueness.rs`
- Modify: `crates/sp_core/src/services/mod.rs`

**Step 1: Write the failing test**

Create `crates/sp_core/src/services/uniqueness.rs` with tests at the bottom:

```rust
use crate::models::PatternMeta;

/// A conflict found during cross-pattern uniqueness validation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UniquenessConflict {
    /// The field that has a duplicate value.
    pub field: &'static str,
    /// The duplicated value.
    pub value: String,
    /// The pattern ID that already claims this value.
    pub claimed_by: String,
}

impl std::fmt::Display for UniquenessConflict {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{} \"{}\" is already used by pattern \"{}\"",
            self.field, self.value, self.claimed_by
        )
    }
}

/// Checks that the given pattern's `podcastGuid` and `feedUrls` do not
/// overlap with any other pattern in `all_patterns`.
///
/// `all_patterns` should include every pattern except the one being
/// validated (for updates) or every pattern (for creates, where the new
/// pattern is not yet in the list).
pub fn check_uniqueness(
    _candidate: &PatternMeta,
    _others: &[PatternMeta],
) -> Vec<UniquenessConflict> {
    todo!()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn meta(id: &str, guid: Option<&str>, feed_urls: &[&str]) -> PatternMeta {
        PatternMeta {
            data_version: 1,
            id: id.to_string(),
            podcast_guid: guid.map(|s| s.to_string()),
            feed_urls: feed_urls.iter().map(|s| s.to_string()).collect(),
            year_grouped_episodes: false,
            playlists: vec!["p1".to_string()],
        }
    }

    #[test]
    fn no_conflict_when_no_overlap() {
        let candidate = meta("a", Some("guid-a"), &["https://a.com/feed"]);
        let others = vec![meta("b", Some("guid-b"), &["https://b.com/feed"])];
        assert!(check_uniqueness(&candidate, &others).is_empty());
    }

    #[test]
    fn detects_duplicate_podcast_guid() {
        let candidate = meta("a", Some("guid-shared"), &["https://a.com/feed"]);
        let others = vec![meta("b", Some("guid-shared"), &["https://b.com/feed"])];
        let conflicts = check_uniqueness(&candidate, &others);
        assert_eq!(conflicts.len(), 1);
        assert_eq!(conflicts[0].field, "podcastGuid");
        assert_eq!(conflicts[0].value, "guid-shared");
        assert_eq!(conflicts[0].claimed_by, "b");
    }

    #[test]
    fn detects_duplicate_feed_url() {
        let candidate = meta("a", None, &["https://shared.com/feed"]);
        let others = vec![meta("b", None, &["https://shared.com/feed"])];
        let conflicts = check_uniqueness(&candidate, &others);
        assert_eq!(conflicts.len(), 1);
        assert_eq!(conflicts[0].field, "feedUrls");
        assert_eq!(conflicts[0].value, "https://shared.com/feed");
        assert_eq!(conflicts[0].claimed_by, "b");
    }

    #[test]
    fn detects_multiple_conflicts() {
        let candidate = meta("a", Some("guid-x"), &["https://x.com/feed", "https://y.com/feed"]);
        let others = vec![
            meta("b", Some("guid-x"), &["https://b.com/feed"]),
            meta("c", None, &["https://y.com/feed"]),
        ];
        let conflicts = check_uniqueness(&candidate, &others);
        assert_eq!(conflicts.len(), 2);
    }

    #[test]
    fn no_conflict_when_guid_is_none() {
        let candidate = meta("a", None, &["https://a.com/feed"]);
        let others = vec![meta("b", None, &["https://b.com/feed"])];
        assert!(check_uniqueness(&candidate, &others).is_empty());
    }

    #[test]
    fn no_conflict_with_empty_others() {
        let candidate = meta("a", Some("guid-a"), &["https://a.com/feed"]);
        assert!(check_uniqueness(&candidate, &[]).is_empty());
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test -p sp_core uniqueness -- --nocapture`
Expected: FAIL with `not yet implemented`

**Step 3: Write the implementation**

Replace the `todo!()` body in `check_uniqueness`:

```rust
pub fn check_uniqueness(
    candidate: &PatternMeta,
    others: &[PatternMeta],
) -> Vec<UniquenessConflict> {
    let mut conflicts = Vec::new();

    if let Some(ref guid) = candidate.podcast_guid {
        for other in others {
            if other.podcast_guid.as_deref() == Some(guid.as_str()) {
                conflicts.push(UniquenessConflict {
                    field: "podcastGuid",
                    value: guid.clone(),
                    claimed_by: other.id.clone(),
                });
                break;
            }
        }
    }

    for url in &candidate.feed_urls {
        for other in others {
            if other.feed_urls.iter().any(|u| u == url) {
                conflicts.push(UniquenessConflict {
                    field: "feedUrls",
                    value: url.clone(),
                    claimed_by: other.id.clone(),
                });
                break;
            }
        }
    }

    conflicts
}
```

**Step 4: Export from services module**

In `crates/sp_core/src/services/mod.rs`, add:

```rust
pub mod uniqueness;
pub use uniqueness::{check_uniqueness, UniquenessConflict};
```

**Step 5: Run tests to verify they pass**

Run: `cargo test -p sp_core uniqueness`
Expected: all 6 tests PASS

**Step 6: Commit**

```bash
git add crates/sp_core/src/services/uniqueness.rs crates/sp_core/src/services/mod.rs
git commit -m "feat(core): add cross-pattern uniqueness validator"
```

---

### Task 2: Wire uniqueness check into sp_server create/update handlers

**Files:**
- Modify: `crates/sp_server/src/routes/config.rs`

The server needs a helper that loads all other patterns' `PatternMeta` and calls `check_uniqueness`. Insert it into both `create_pattern` and `update_pattern_meta`, after schema validation but before writing to disk.

**Step 1: Write the helper and wire into create_pattern**

At the top of `config.rs`, add to imports:

```rust
use sp_core::models::PatternMeta;
use sp_core::services::check_uniqueness;
```

Add a helper function at the bottom of the file (before the existing private functions):

```rust
/// Loads all pattern metas except `exclude_id` and checks for uniqueness conflicts.
fn check_cross_pattern_uniqueness(
    state: &SharedState,
    candidate: &PatternMeta,
    exclude_id: Option<&str>,
) -> Result<(), AppError> {
    let summaries = state.config_repo.list_patterns()?;
    let mut others = Vec::new();
    for summary in &summaries {
        if exclude_id == Some(summary.id.as_str()) {
            continue;
        }
        match state.config_repo.get_pattern_meta(&summary.id) {
            Ok(meta) => others.push(meta),
            Err(_) => continue,
        }
    }

    let conflicts = check_uniqueness(candidate, &others);
    if conflicts.is_empty() {
        return Ok(());
    }

    let messages: Vec<String> = conflicts.iter().map(|c| c.to_string()).collect();
    Err(AppError::conflict(messages.join("; ")))
}
```

In `create_pattern`, after schema validation (line 67) and before `state.config_repo.create_pattern` (line 69), add:

```rust
    // Check cross-pattern uniqueness (podcastGuid, feedUrls).
    let candidate: PatternMeta = serde_json::from_value(meta_with_version.clone())
        .map_err(|e| AppError::bad_request(format!("Invalid pattern meta: {e}")))?;
    check_cross_pattern_uniqueness(&state, &candidate, None)?;
```

**Step 2: Wire into update_pattern_meta**

In `update_pattern_meta`, after schema validation (line 191) and before `state.config_repo.save_pattern_meta` (line 193), add:

```rust
    // Check cross-pattern uniqueness (podcastGuid, feedUrls).
    let candidate: PatternMeta = serde_json::from_value(existing.clone())
        .map_err(|e| AppError::internal(format!("Pattern meta deserialization error: {e}")))?;
    check_cross_pattern_uniqueness(&state, &candidate, Some(&id))?;
```

**Step 3: Run tests to verify compilation**

Run: `cargo test -p sp_server`
Expected: PASS (existing tests still pass, no breakage)

**Step 4: Run clippy**

Run: `cargo clippy -- -W warnings`
Expected: zero warnings

**Step 5: Commit**

```bash
git add crates/sp_server/src/routes/config.rs
git commit -m "feat(server): enforce cross-pattern uniqueness on create/update"
```

---

### Task 3: Wire uniqueness check into CLI validate command

**Files:**
- Modify: `crates/sp_cli/src/cmd_validate.rs`

After the per-file schema validation walk, add a second pass that loads all pattern metas and checks for cross-pattern uniqueness conflicts.

**Step 1: Add cross-pattern validation to validate_all**

Add imports at the top of `cmd_validate.rs`:

```rust
use sp_core::models::PatternMeta;
use sp_core::services::check_uniqueness;
```

In `validate_all`, after the `config_walker::walk_config_files` call and before the summary print, add a call to a new function:

```rust
    error_count += validate_cross_pattern_uniqueness(patterns_dir)?;
```

Add the new function:

```rust
/// Loads every pattern meta.json and checks for cross-pattern uniqueness
/// conflicts (duplicate podcastGuid or feedUrls).
/// Returns the number of conflicts found.
fn validate_cross_pattern_uniqueness(patterns_dir: &Path) -> anyhow::Result<u32> {
    let mut metas: Vec<PatternMeta> = Vec::new();

    let dirs: Vec<PathBuf> = match std::fs::read_dir(patterns_dir) {
        Ok(entries) => entries
            .filter_map(|e| e.ok())
            .map(|e| e.path())
            .filter(|p| p.is_dir())
            .collect(),
        Err(_) => return Ok(0),
    };

    for dir in &dirs {
        let meta_path = dir.join("meta.json");
        if !meta_path.exists() {
            continue;
        }
        let content = std::fs::read_to_string(&meta_path)?;
        match serde_json::from_str::<PatternMeta>(&content) {
            Ok(meta) => metas.push(meta),
            Err(_) => continue, // schema validation already reported this
        }
    }

    let mut conflict_count = 0u32;
    for i in 1..metas.len() {
        let candidate = &metas[i];
        let others = &metas[..i];
        let conflicts = check_uniqueness(candidate, others);
        for conflict in &conflicts {
            println!("  FAIL: pattern \"{}\" -- {conflict}", candidate.id);
            conflict_count += 1;
        }
    }

    conflict_count
}
```

Note: The `PathBuf` import is already in scope.

**Step 2: Run tests**

Run: `cargo test -p sp_cli`
Expected: PASS

**Step 3: Run clippy**

Run: `cargo clippy -- -W warnings`
Expected: zero warnings

**Step 4: Manual smoke test**

Run: `cargo run -- validate --data-dir ../audiflow-smartplaylist`
Expected: "All files are valid." (no cross-pattern conflicts in real data)

**Step 5: Commit**

```bash
git add crates/sp_cli/src/cmd_validate.rs
git commit -m "feat(cli): check cross-pattern uniqueness in validate command"
```

---

### Task 4: Add pattern identifiers endpoint to sp_server

**Files:**
- Create: `crates/sp_server/src/routes/identifiers.rs`
- Modify: `crates/sp_server/src/routes/mod.rs`

A lightweight endpoint that returns `[{id, podcastGuid, feedUrls}]` for all patterns. The frontend fetches this once and checks locally as the user types -- no per-keystroke round-trip.

**Step 1: Create the handler**

Create `crates/sp_server/src/routes/identifiers.rs`:

```rust
use axum::extract::State;
use axum::Json;
use serde::Serialize;
use serde_json::Value;

use crate::app::{AppError, SharedState};

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PatternIdentifiers {
    id: String,
    podcast_guid: Option<String>,
    feed_urls: Vec<String>,
}

/// GET /api/configs/patterns/identifiers -- returns podcast identifiers
/// for all patterns. Used by the frontend to detect duplicates while
/// the user edits podcastGuid / feedUrls fields.
pub async fn list_pattern_identifiers(
    State(state): State<SharedState>,
) -> Result<Json<Value>, AppError> {
    let summaries = state.config_repo.list_patterns()?;
    let mut result = Vec::with_capacity(summaries.len());

    for summary in &summaries {
        match state.config_repo.get_pattern_meta(&summary.id) {
            Ok(meta) => result.push(PatternIdentifiers {
                id: meta.id,
                podcast_guid: meta.podcast_guid,
                feed_urls: meta.feed_urls,
            }),
            Err(_) => continue,
        }
    }

    let json = serde_json::to_value(result)
        .map_err(|e| AppError::internal(format!("Serialization error: {e}")))?;
    Ok(Json(json))
}
```

**Step 2: Register the route**

In `crates/sp_server/src/routes/mod.rs`, add the module:

```rust
pub mod identifiers;
```

In `create_router`, add the route **before** the `"/configs/patterns/{id}"` route (so it matches before the `{id}` wildcard):

```rust
        .route(
            "/configs/patterns/identifiers",
            get(identifiers::list_pattern_identifiers),
        )
```

Place it between the `/configs/patterns` line and the `/configs/patterns/{id}` line.

**Step 3: Run tests and clippy**

Run: `cargo test -p sp_server && cargo clippy -- -W warnings`
Expected: PASS, zero warnings

**Step 4: Commit**

```bash
git add crates/sp_server/src/routes/identifiers.rs crates/sp_server/src/routes/mod.rs
git commit -m "feat(server): add pattern identifiers endpoint for frontend duplicate checks"
```

---

### Task 5: Add frontend query hook and duplicate detection hook

**Files:**
- Modify: `packages/sp_react/src/schemas/api-schema.ts`
- Modify: `packages/sp_react/src/api/queries.ts`
- Create: `packages/sp_react/src/hooks/use-duplicate-check.ts`

**Step 1: Add the TypeScript type**

In `packages/sp_react/src/schemas/api-schema.ts`, add after the `patternMetaSchema`:

```typescript
export const patternIdentifiersSchema = z.object({
  id: z.string(),
  podcastGuid: z.string().nullish(),
  feedUrls: z.array(z.string()),
});

export type PatternIdentifiers = z.infer<typeof patternIdentifiersSchema>;
```

**Step 2: Add the query hook**

In `packages/sp_react/src/api/queries.ts`, add the import for `PatternIdentifiers` and a new hook:

Add to the import from `'../schemas/api-schema.ts'`:

```typescript
import type {
  PatternSummary,
  PatternIdentifiers,
  FeedEpisode,
  PreviewResult,
} from '../schemas/api-schema.ts';
```

Add the hook after `usePatterns()`:

```typescript
export function usePatternIdentifiers() {
  const client = useApiClient();
  return useQuery({
    queryKey: ['patternIdentifiers'],
    queryFn: () =>
      client.get<PatternIdentifiers[]>(
        '/api/configs/patterns/identifiers',
      ),
    staleTime: 60 * 1000,
  });
}
```

**Step 3: Create the duplicate detection hook**

Create `packages/sp_react/src/hooks/use-duplicate-check.ts`:

```typescript
import { useMemo } from 'react';
import { usePatternIdentifiers } from '@/api/queries.ts';

export interface DuplicateConflict {
  field: 'podcastGuid' | 'feedUrls';
  value: string;
  claimedBy: string;
}

/**
 * Checks the given podcastGuid and feedUrls against all other patterns
 * for uniqueness conflicts. Runs entirely client-side against the cached
 * identifiers list -- no per-keystroke API call.
 *
 * @param currentPatternId - The pattern being edited (excluded from checks), or null for new patterns.
 * @param podcastGuid - The current podcastGuid value from the form.
 * @param feedUrls - The current feedUrls array from the form.
 */
export function useDuplicateCheck(
  currentPatternId: string | null,
  podcastGuid: string | null | undefined,
  feedUrls: string[] | null | undefined,
): DuplicateConflict[] {
  const { data: identifiers } = usePatternIdentifiers();

  return useMemo(() => {
    if (!identifiers) return [];

    const others = currentPatternId
      ? identifiers.filter((p) => p.id !== currentPatternId)
      : identifiers;

    const conflicts: DuplicateConflict[] = [];

    if (podcastGuid) {
      const match = others.find((p) => p.podcastGuid === podcastGuid);
      if (match) {
        conflicts.push({
          field: 'podcastGuid',
          value: podcastGuid,
          claimedBy: match.id,
        });
      }
    }

    for (const url of feedUrls ?? []) {
      const match = others.find((p) => p.feedUrls.includes(url));
      if (match) {
        conflicts.push({
          field: 'feedUrls',
          value: url,
          claimedBy: match.id,
        });
      }
    }

    return conflicts;
  }, [identifiers, currentPatternId, podcastGuid, feedUrls]);
}
```

**Step 4: Run type check**

Run: `cd packages/sp_react && npx tsc -b --noEmit`
Expected: no errors

**Step 5: Commit**

```bash
git add packages/sp_react/src/schemas/api-schema.ts packages/sp_react/src/api/queries.ts packages/sp_react/src/hooks/use-duplicate-check.ts
git commit -m "feat(react): add duplicate detection hook for pattern identifiers"
```

---

### Task 6: Wire duplicate warnings into PatternSettingsCard

**Files:**
- Modify: `packages/sp_react/src/components/editor/pattern-settings.tsx`
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`

The goal: show an inline warning below the podcastGuid input and/or the feedUrls textarea when a duplicate is detected, with a link to the conflicting pattern's editor page.

**Step 1: Add i18n strings**

In `packages/sp_react/src/locales/en/editor.json`, add:

```json
  "duplicateGuid": "This GUID is already used by \"{{patternId}}\". ",
  "duplicateFeedUrl": "Feed URL \"{{url}}\" is already used by \"{{patternId}}\". ",
  "duplicateGoToPattern": "Open existing config"
```

In `packages/sp_react/src/locales/ja/editor.json`, add:

```json
  "duplicateGuid": "この GUID は既に「{{patternId}}」で使用されています。",
  "duplicateFeedUrl": "フィード URL「{{url}}」は既に「{{patternId}}」で使用されています。",
  "duplicateGoToPattern": "既存の設定を開く"
```

**Step 2: Update PatternSettingsCard**

Replace the entire `pattern-settings.tsx` with:

```tsx
import { useFormContext, useWatch } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { Link } from '@tanstack/react-router';
import { TriangleAlert } from 'lucide-react';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Textarea } from '@/components/ui/textarea.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { useDuplicateCheck } from '@/hooks/use-duplicate-check.ts';
import type { DuplicateConflict } from '@/hooks/use-duplicate-check.ts';

export function PatternSettingsCard({
  configId,
}: {
  configId: string | null;
}) {
  const { register, watch, setValue, control } =
    useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const podcastGuid = useWatch({ control, name: 'podcastGuid' });
  const feedUrls = useWatch({ control, name: 'feedUrls' });
  const conflicts = useDuplicateCheck(configId, podcastGuid, feedUrls);

  const guidConflicts = conflicts.filter((c) => c.field === 'podcastGuid');
  const feedUrlConflicts = conflicts.filter((c) => c.field === 'feedUrls');

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('patternSettings')}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <HintLabel htmlFor="config-id" hint="patternId">
              {t('configId')}
            </HintLabel>
            <Input
              id="config-id"
              {...register('id')}
              placeholder={t('placeholderPatternId')}
            />
          </div>
          <div className="space-y-1.5">
            <HintLabel htmlFor="config-displayName" hint="patternDisplayName">
              {t('patternDisplayName')}
            </HintLabel>
            <Input
              id="config-displayName"
              {...register('displayName')}
              placeholder={t('placeholderPatternDisplayName')}
            />
          </div>
        </div>
        <div className="space-y-1.5">
          <HintLabel htmlFor="config-podcastGuid" hint="podcastGuid">
            {t('podcastGuid')}
          </HintLabel>
          <Input
            id="config-podcastGuid"
            {...register('podcastGuid')}
            placeholder={t('placeholderGuid')}
          />
          {guidConflicts.map((c) => (
            <DuplicateWarning key={c.claimedBy} conflict={c} />
          ))}
        </div>
        <FeedUrlsField conflicts={feedUrlConflicts} />
        <div className="flex items-center gap-2">
          <Checkbox
            id="config-yearGroupedEpisodes"
            checked={watch('yearGroupedEpisodes') ?? false}
            onCheckedChange={(checked) =>
              setValue('yearGroupedEpisodes', !!checked, { shouldDirty: true })
            }
          />
          <HintLabel
            htmlFor="config-yearGroupedEpisodes"
            hint="yearGroupedEpisodes"
          >
            {t('yearGroupedEpisodes')}
          </HintLabel>
        </div>
      </CardContent>
    </Card>
  );
}

function FeedUrlsField({
  conflicts,
}: {
  conflicts: DuplicateConflict[];
}) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const feedUrls = watch('feedUrls') ?? [];

  return (
    <div className="space-y-1.5">
      <HintLabel htmlFor="config-feedUrls" hint="feedUrls">
        {t('feedUrlsLabel')}
      </HintLabel>
      <Textarea
        id="config-feedUrls"
        value={feedUrls.join(', ')}
        onChange={(e) => {
          const urls = e.target.value
            .split(',')
            .map((u) => u.trim())
            .filter(Boolean);
          setValue('feedUrls', urls, { shouldDirty: true });
        }}
        placeholder={t('placeholderFeedUrls')}
      />
      {conflicts.map((c) => (
        <DuplicateWarning key={`${c.claimedBy}-${c.value}`} conflict={c} />
      ))}
    </div>
  );
}

function DuplicateWarning({ conflict }: { conflict: DuplicateConflict }) {
  const { t } = useTranslation('editor');

  const message =
    conflict.field === 'podcastGuid'
      ? t('duplicateGuid', { patternId: conflict.claimedBy })
      : t('duplicateFeedUrl', {
          url: conflict.value,
          patternId: conflict.claimedBy,
        });

  return (
    <p className="flex items-center gap-1.5 text-sm text-amber-600 dark:text-amber-400">
      <TriangleAlert className="h-3.5 w-3.5 shrink-0" />
      <span>
        {message}
        <Link
          to="/editor/$id"
          params={{ id: conflict.claimedBy }}
          className="underline underline-offset-2 hover:text-amber-800 dark:hover:text-amber-200"
        >
          {t('duplicateGoToPattern')}
        </Link>
      </span>
    </p>
  );
}
```

**Step 3: Update PatternSettingsCard call site**

The `PatternSettingsCard` now requires a `configId` prop. Find where it's rendered in `editor-layout.tsx` and pass `configId`:

In `editor-layout.tsx`, the component is rendered as `<PatternSettingsCard />`. Change to:

```tsx
<PatternSettingsCard configId={configId} />
```

Where `configId` is the prop already available in `EditorLayout` (it's `configId: string | null`).

**Step 4: Run type check and lint**

Run: `cd packages/sp_react && npx tsc -b --noEmit && npx oxlint`
Expected: no errors

**Step 5: Commit**

```bash
git add packages/sp_react/src/components/editor/pattern-settings.tsx packages/sp_react/src/locales/en/editor.json packages/sp_react/src/locales/ja/editor.json
git commit -m "feat(react): show inline duplicate warnings for podcastGuid and feedUrls"
```

---

### Task 7: Invalidate identifiers cache on pattern save

**Files:**
- Modify: `packages/sp_react/src/api/queries.ts`

When a pattern is created, updated, or deleted, the identifiers cache must be invalidated so the duplicate check stays current.

**Step 1: Add invalidation to mutations**

In `useSavePatternMeta`, add to `onSuccess`:

```typescript
      void queryClient.invalidateQueries({ queryKey: ['patternIdentifiers'] });
```

In `useCreatePattern`, add to `onSuccess`:

```typescript
      void queryClient.invalidateQueries({ queryKey: ['patternIdentifiers'] });
```

In `useDeletePattern`, add to `onSuccess`:

```typescript
      void queryClient.invalidateQueries({ queryKey: ['patternIdentifiers'] });
```

**Step 2: Run type check**

Run: `cd packages/sp_react && npx tsc -b --noEmit`
Expected: no errors

**Step 3: Commit**

```bash
git add packages/sp_react/src/api/queries.ts
git commit -m "fix(react): invalidate identifiers cache on pattern mutations"
```

---

### Task 8: Run full quality checks

**Step 1: Run Rust tests and clippy**

Run: `cargo test && cargo clippy -- -W warnings`
Expected: all PASS, zero warnings

**Step 2: Run React type check and lint**

Run: `cd packages/sp_react && npx tsc -b --noEmit && npx oxlint`
Expected: no errors

**Step 3: Fix any issues found, then commit if needed**
