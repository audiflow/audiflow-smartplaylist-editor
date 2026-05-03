# Tri-state Toggle for Thumbnail Visibility Flags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the five thumbnail-visibility checkboxes to tri-state (unset → on → off → unset) so editors can distinguish "use default" from "explicitly on" and revert explicit values to default.

**Architecture:** Introduce a `TriStateCheckbox` wrapper around the existing shadcn `Checkbox`, paired with a small `cycle` helper. Migrate the pattern-meta `show_episode_thumbnail` field from `bool` (with default-true sugar) to `Option<bool>` so the unset state round-trips through serde and Zod. Swap each of the five existing call-sites from raw `<Checkbox>` to `<TriStateCheckbox>`. The shadcn `Checkbox` primitive itself needs a one-time edit to render a `MinusIcon` in the indeterminate state (it currently always renders `CheckIcon`).

**Tech Stack:** React 19, Radix UI Checkbox primitive, shadcn/ui, Tailwind, Zod 4, react-hook-form, Vitest, Rust serde.

---

## File map

Modify:
- `packages/sp_react/src/components/ui/checkbox.tsx` — render `MinusIcon` when `data-state="indeterminate"`.
- `packages/sp_react/src/schemas/config-schema.ts` — drop the `nullish().transform((v) => v ?? true)` on `showEpisodeThumbnail`; replace with `z.boolean().optional()`.
- `packages/sp_react/src/mocks/fixtures.ts` — remove `showEpisodeThumbnail: true` from `VALID_PATTERN_CONFIG` and `MINIMAL_PATTERN_CONFIG` (now optional).
- `packages/sp_react/src/components/editor/editor-layout.tsx` — remove `showEpisodeThumbnail: true` from `DEFAULT_CONFIG`.
- `packages/sp_react/src/routes/editor.index.tsx` — remove `showEpisodeThumbnail: true` from the inferred initial config.
- `packages/sp_react/src/components/editor/pattern-settings.tsx` — swap to `<TriStateCheckbox>` for `showEpisodeThumbnail`.
- `packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx` — swap both `showThumbnail` toggles (group-level and episode-level).
- `packages/sp_react/src/components/editor/group-def-card.tsx` — swap the `showThumbnail` per-group override.
- `packages/sp_react/src/locales/en/editor.json`, `packages/sp_react/src/locales/ja/editor.json` — add `triStateHint` key.
- `crates/sp_core/src/models/pattern_meta.rs` — change `show_episode_thumbnail: bool` → `Option<bool>`. Drop now-unused `default_true` / `is_true` helpers. Rewrite the three serde tests.
- `crates/sp_core/src/services/uniqueness.rs` — change `show_episode_thumbnail: true` → `None` in the test helper.
- `crates/sp_core/tests/service_tests.rs` — same change in the two `assemble` tests.

Create:
- `packages/sp_react/src/components/ui/tri-state-checkbox.tsx`
- `packages/sp_react/src/components/ui/__tests__/tri-state-checkbox.test.tsx`

---

## Task 1: Indeterminate visual on the shadcn `Checkbox`

**Files:**
- Modify: `packages/sp_react/src/components/ui/checkbox.tsx`

The existing primitive always renders `<CheckIcon>` inside `<Indicator>`. Radix sets `data-state="indeterminate"` on the Root when `checked === "indeterminate"`. Use `group` + `group-data-[state=*]` Tailwind variants to swap between check and dash icons.

- [ ] **Step 1: Read current `checkbox.tsx`.**

Already known: the file imports `CheckIcon` from `lucide-react`, the `<Root>` does not have `group` in its className, and the `<Indicator>` body is just `<CheckIcon className="size-3.5" />`.

- [ ] **Step 2: Edit the file.**

Replace the contents of `packages/sp_react/src/components/ui/checkbox.tsx` with:

```tsx
import * as React from "react"
import { CheckIcon, MinusIcon } from "lucide-react"
import { Checkbox as CheckboxPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

function Checkbox({
  className,
  ...props
}: React.ComponentProps<typeof CheckboxPrimitive.Root>) {
  return (
    <CheckboxPrimitive.Root
      data-slot="checkbox"
      className={cn(
        "group peer border-input dark:bg-input/30 data-[state=checked]:bg-primary data-[state=checked]:text-primary-foreground dark:data-[state=checked]:bg-primary data-[state=checked]:border-primary focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive size-4 shrink-0 rounded-[4px] border shadow-xs transition-shadow outline-none focus-visible:ring-[3px] disabled:cursor-not-allowed disabled:opacity-50",
        className
      )}
      {...props}
    >
      <CheckboxPrimitive.Indicator
        data-slot="checkbox-indicator"
        className="grid place-content-center text-current transition-none"
      >
        <CheckIcon className="size-3.5 hidden group-data-[state=checked]:block" />
        <MinusIcon className="size-3.5 hidden group-data-[state=indeterminate]:block text-muted-foreground" />
      </CheckboxPrimitive.Indicator>
    </CheckboxPrimitive.Root>
  )
}

export { Checkbox }
```

The only changes: import `MinusIcon`; add `group` to the Root className; add a second icon row in the Indicator with mutually exclusive `group-data-[state=*]:block` visibility. The `text-muted-foreground` on the dash gives a subdued (gray) appearance when unset, matching the spec's intent.

- [ ] **Step 3: Type-check.**

```bash
cd packages/sp_react && npx tsc -b --noEmit
```

Expected: pass.

- [ ] **Step 4: Run existing checkbox-using tests to confirm no regression.**

```bash
cd packages/sp_react && pnpm test -- --run
```

Expected: 300/300 pass (rendered icon for `checked`/`unchecked` is unchanged; only the Indicator's children grew by one mutually-exclusive node).

- [ ] **Step 5: Commit.**

```bash
git add packages/sp_react/src/components/ui/checkbox.tsx
git commit -m "feat(sp_react): render dash icon for indeterminate checkbox"
```

---

## Task 2: `cycle` helper + `TriStateCheckbox` component

**Files:**
- Create: `packages/sp_react/src/components/ui/tri-state-checkbox.tsx`
- Create: `packages/sp_react/src/components/ui/__tests__/tri-state-checkbox.test.tsx`

- [ ] **Step 1: Write the failing tests.**

Create `packages/sp_react/src/components/ui/__tests__/tri-state-checkbox.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { TriStateCheckbox, cycleTriState } from '../tri-state-checkbox';

describe('cycleTriState', () => {
  it('cycles undefined -> true -> false -> undefined', () => {
    expect(cycleTriState(undefined)).toBe(true);
    expect(cycleTriState(true)).toBe(false);
    expect(cycleTriState(false)).toBeUndefined();
  });

  it('returns to undefined after a full loop', () => {
    let v: boolean | undefined = undefined;
    v = cycleTriState(v);
    v = cycleTriState(v);
    v = cycleTriState(v);
    expect(v).toBeUndefined();
  });
});

describe('TriStateCheckbox', () => {
  it('renders data-state=indeterminate when value is undefined', () => {
    render(<TriStateCheckbox id="t" value={undefined} onChange={() => {}} />);
    expect(screen.getByRole('checkbox')).toHaveAttribute('data-state', 'indeterminate');
  });

  it('renders data-state=checked when value is true', () => {
    render(<TriStateCheckbox id="t" value={true} onChange={() => {}} />);
    expect(screen.getByRole('checkbox')).toHaveAttribute('data-state', 'checked');
  });

  it('renders data-state=unchecked when value is false', () => {
    render(<TriStateCheckbox id="t" value={false} onChange={() => {}} />);
    expect(screen.getByRole('checkbox')).toHaveAttribute('data-state', 'unchecked');
  });

  it('cycles on click: undefined -> true -> false -> undefined', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const { rerender } = render(
      <TriStateCheckbox id="t" value={undefined} onChange={onChange} />,
    );
    await user.click(screen.getByRole('checkbox'));
    expect(onChange).toHaveBeenLastCalledWith(true);

    rerender(<TriStateCheckbox id="t" value={true} onChange={onChange} />);
    await user.click(screen.getByRole('checkbox'));
    expect(onChange).toHaveBeenLastCalledWith(false);

    rerender(<TriStateCheckbox id="t" value={false} onChange={onChange} />);
    await user.click(screen.getByRole('checkbox'));
    expect(onChange).toHaveBeenLastCalledWith(undefined);
  });
});
```

- [ ] **Step 2: Run and confirm failure.**

```bash
cd packages/sp_react && pnpm test -- --run tri-state-checkbox
```

Expected: FAIL — module not found.

- [ ] **Step 3: Create the component.**

Create `packages/sp_react/src/components/ui/tri-state-checkbox.tsx`:

```tsx
import { Checkbox } from '@/components/ui/checkbox';

export type TriState = boolean | undefined;

export function cycleTriState(value: TriState): TriState {
  if (value === undefined) return true;
  if (value === true) return false;
  return undefined;
}

interface TriStateCheckboxProps {
  id: string;
  value: TriState;
  onChange: (next: TriState) => void;
  title?: string;
  'aria-label'?: string;
}

export function TriStateCheckbox({
  id,
  value,
  onChange,
  title,
  'aria-label': ariaLabel,
}: TriStateCheckboxProps) {
  const checked = value === undefined ? 'indeterminate' : value;
  return (
    <Checkbox
      id={id}
      checked={checked}
      onCheckedChange={() => onChange(cycleTriState(value))}
      title={title}
      aria-label={ariaLabel}
    />
  );
}
```

- [ ] **Step 4: Run and confirm pass.**

```bash
cd packages/sp_react && pnpm test -- --run tri-state-checkbox
```

Expected: all six cases PASS.

- [ ] **Step 5: Type + lint.**

```bash
cd packages/sp_react && npx tsc -b --noEmit && npx oxlint src/components/ui/tri-state-checkbox.tsx src/components/ui/__tests__/tri-state-checkbox.test.tsx
```

Expected: no errors.

- [ ] **Step 6: Commit.**

```bash
git add packages/sp_react/src/components/ui/tri-state-checkbox.tsx \
        packages/sp_react/src/components/ui/__tests__/tri-state-checkbox.test.tsx
git commit -m "feat(sp_react): add TriStateCheckbox + cycle helper"
```

---

## Task 3: Pattern-meta `show_episode_thumbnail` to `Option<bool>` (Rust)

**Files:**
- Modify: `crates/sp_core/src/models/pattern_meta.rs`
- Modify: `crates/sp_core/src/services/uniqueness.rs`
- Modify: `crates/sp_core/tests/service_tests.rs`

- [ ] **Step 1: Replace the existing serde tests with the new tri-state assertions.**

In `crates/sp_core/src/models/pattern_meta.rs`, replace the entire `mod tests` block at the bottom with:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn show_episode_thumbnail_absent_deserializes_none() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        assert!(meta.show_episode_thumbnail.is_none());
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
        assert_eq!(meta.show_episode_thumbnail, Some(false));
        let out = serde_json::to_value(&meta).unwrap();
        assert_eq!(out["showEpisodeThumbnail"], serde_json::json!(false));
    }

    #[test]
    fn show_episode_thumbnail_round_trips_true() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "showEpisodeThumbnail": true,
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        assert_eq!(meta.show_episode_thumbnail, Some(true));
        let out = serde_json::to_value(&meta).unwrap();
        assert_eq!(out["showEpisodeThumbnail"], serde_json::json!(true));
    }

    #[test]
    fn show_episode_thumbnail_omitted_when_none() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        let out = serde_json::to_value(&meta).unwrap();
        assert!(out.get("showEpisodeThumbnail").is_none());
    }
}
```

- [ ] **Step 2: Run and confirm failure.**

```bash
cargo test -p audiflow-smartplaylist-core --lib pattern_meta::tests
```

Expected: FAIL — type mismatch (`bool` vs `Option<bool>` / `is_none` not found on `bool`).

- [ ] **Step 3: Change the field type and drop helpers.**

Replace the contents of `crates/sp_core/src/models/pattern_meta.rs` with:

```rust
use serde::{Deserialize, Serialize};

use super::default_data_version;

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

    /// Show thumbnails on rows of the main podcast episode list.
    /// Tri-state: `None` = use schema default (true); `Some(true)` = explicit on; `Some(false)` = explicit off.
    /// Omitted from JSON when `None`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub show_episode_thumbnail: Option<bool>,

    /// Ordered list of playlist IDs.
    pub playlists: Vec<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn show_episode_thumbnail_absent_deserializes_none() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        assert!(meta.show_episode_thumbnail.is_none());
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
        assert_eq!(meta.show_episode_thumbnail, Some(false));
        let out = serde_json::to_value(&meta).unwrap();
        assert_eq!(out["showEpisodeThumbnail"], serde_json::json!(false));
    }

    #[test]
    fn show_episode_thumbnail_round_trips_true() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "showEpisodeThumbnail": true,
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        assert_eq!(meta.show_episode_thumbnail, Some(true));
        let out = serde_json::to_value(&meta).unwrap();
        assert_eq!(out["showEpisodeThumbnail"], serde_json::json!(true));
    }

    #[test]
    fn show_episode_thumbnail_omitted_when_none() {
        let json = serde_json::json!({
            "dataVersion": 1,
            "id": "abc",
            "feedUrls": ["https://example.com/rss"],
            "playlists": ["p1"]
        });
        let meta: PatternMeta = serde_json::from_value(json).unwrap();
        let out = serde_json::to_value(&meta).unwrap();
        assert!(out.get("showEpisodeThumbnail").is_none());
    }
}
```

(`default_true` and `is_true` helpers are removed; nothing else in the crate uses them. Verify with `grep -rn "default_true\|is_true" crates/sp_core/src` — should return nothing after the file is replaced.)

- [ ] **Step 4: Update constructor sites.**

`crates/sp_core/src/services/uniqueness.rs` — change the test helper that builds `PatternMeta { ... show_episode_thumbnail: true, ... }` to `show_episode_thumbnail: None`.

`crates/sp_core/tests/service_tests.rs` — change both `PatternMeta { ... show_episode_thumbnail: true, ... }` literals to `show_episode_thumbnail: None`.

Verify no other constructors:

```bash
grep -rn "show_episode_thumbnail:" /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor/crates --include="*.rs"
```

Every match should now be either the struct field declaration, a test assertion, or a constructor with `None`.

- [ ] **Step 5: Run targeted tests + full Rust gates.**

```bash
cargo test -p audiflow-smartplaylist-core --lib pattern_meta::tests
cargo test
cargo clippy --all-targets -- -W warnings
```

Expected: green, zero warnings.

- [ ] **Step 6: Commit.**

```bash
git add crates/sp_core/src/models/pattern_meta.rs \
        crates/sp_core/src/services/uniqueness.rs \
        crates/sp_core/tests/service_tests.rs
git commit -m "refactor(sp_core): make show_episode_thumbnail tri-state"
```

---

## Task 4: Zod `showEpisodeThumbnail` to optional + drop fixture defaults

**Files:**
- Modify: `packages/sp_react/src/schemas/config-schema.ts`
- Modify: `packages/sp_react/src/schemas/__tests__/config-schema.test.ts`
- Modify: `packages/sp_react/src/mocks/fixtures.ts`
- Modify: `packages/sp_react/src/components/editor/editor-layout.tsx`
- Modify: `packages/sp_react/src/routes/editor.index.tsx`

- [ ] **Step 1: Rewrite the failing tests.**

In `packages/sp_react/src/schemas/__tests__/config-schema.test.ts`, replace the two `showEpisodeThumbnail` cases inside the `describe('showThumbnail flags', ...)` block with these:

```ts
  it('parses explicit showEpisodeThumbnail values', () => {
    const onResult = patternConfigSchema.parse({
      id: 'p1',
      displayName: 'P1',
      podcastGuid: 'g',
      feedUrls: ['https://x'],
      showEpisodeThumbnail: true,
      playlists: [{
        id: 'one',
        displayName: 'One',
        priority: 0,
        grouping: { by: 'seasonNumber' },
      }],
    });
    expect(onResult.showEpisodeThumbnail).toBe(true);

    const offResult = patternConfigSchema.parse({
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
    expect(offResult.showEpisodeThumbnail).toBe(false);
  });

  it('leaves showEpisodeThumbnail undefined when absent', () => {
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
    expect(result.showEpisodeThumbnail).toBeUndefined();
  });
```

(The two earlier cases — `'parses showEpisodeThumbnail on pattern config'` and `'defaults showEpisodeThumbnail to true when absent'` — are removed; the second one's assertion is now wrong because the new behavior is "absent stays undefined".)

- [ ] **Step 2: Run and confirm failure.**

```bash
cd packages/sp_react && pnpm test -- --run config-schema
```

Expected: FAIL on `leaves showEpisodeThumbnail undefined when absent` (the existing transform forces it to true).

- [ ] **Step 3: Update Zod.**

In `packages/sp_react/src/schemas/config-schema.ts`, change the `patternConfigSchema` line:

```ts
  showEpisodeThumbnail: z.boolean().optional(),
```

(was `z.boolean().nullish().transform((v) => v ?? true)`).

- [ ] **Step 4: Drop the now-redundant defaults from fixtures and seeds.**

Search and remove:

```bash
grep -rn "showEpisodeThumbnail" /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor/packages/sp_react/src --include="*.ts" --include="*.tsx"
```

For these files, delete the `showEpisodeThumbnail: true,` line (preserve trailing-comma rules):

- `packages/sp_react/src/mocks/fixtures.ts` — two locations (`VALID_PATTERN_CONFIG`, `MINIMAL_PATTERN_CONFIG`).
- `packages/sp_react/src/components/editor/editor-layout.tsx` — `DEFAULT_CONFIG`.
- `packages/sp_react/src/routes/editor.index.tsx` — initial config object.

The Zod inferred type now allows the field to be omitted, so type-checking should still pass.

- [ ] **Step 5: Run targeted tests.**

```bash
cd packages/sp_react && pnpm test -- --run config-schema
```

Expected: PASS for the new cases.

- [ ] **Step 6: Type + lint + full tests.**

```bash
cd packages/sp_react && npx tsc -b --noEmit && npx oxlint && pnpm test -- --run
```

Expected: green; only the two pre-existing oxlint warnings in `schema-conformance.test.ts` (`createValidator`, `topProps`).

- [ ] **Step 7: Commit.**

```bash
git add packages/sp_react/src/schemas/ \
        packages/sp_react/src/mocks/fixtures.ts \
        packages/sp_react/src/components/editor/editor-layout.tsx \
        packages/sp_react/src/routes/editor.index.tsx
git commit -m "refactor(sp_react): make showEpisodeThumbnail Zod tri-state"
```

---

## Task 5: Locale tooltip key

**Files:**
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`

- [ ] **Step 1: Add `triStateHint` key.**

Read each file first to pick a position consistent with surrounding ordering.

`en/editor.json`:

```json
  "triStateHint": "Click to cycle: default -> on -> off",
```

`ja/editor.json`:

```json
  "triStateHint": "クリックで切替: デフォルト -> オン -> オフ",
```

- [ ] **Step 2: JSON validity check.**

```bash
cd /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist-editor/packages/sp_react
python3 -m json.tool src/locales/en/editor.json > /dev/null && \
python3 -m json.tool src/locales/ja/editor.json > /dev/null && \
echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit.**

```bash
git add packages/sp_react/src/locales/en/editor.json \
        packages/sp_react/src/locales/ja/editor.json
git commit -m "feat(sp_react): add triStateHint locale key"
```

---

## Task 6: Migrate `pattern-settings.tsx` to `TriStateCheckbox`

**Files:**
- Modify: `packages/sp_react/src/components/editor/pattern-settings.tsx`

- [ ] **Step 1: Replace the showEpisodeThumbnail block.**

Find the block added previously (a `<div className="flex items-center gap-2">` containing a `<Checkbox id="config-showEpisodeThumbnail" ...>` and `<HintLabel>`). Replace the `<Checkbox>` call with the tri-state version.

At the top of the file, add to the imports:

```tsx
import { TriStateCheckbox } from '@/components/ui/tri-state-checkbox.tsx';
```

In the JSX, replace the block:

```tsx
        <div className="flex items-center gap-2">
          <TriStateCheckbox
            id="config-showEpisodeThumbnail"
            value={watch('showEpisodeThumbnail')}
            onChange={(next) =>
              setValue('showEpisodeThumbnail', next, { shouldDirty: true })
            }
            title={t('triStateHint')}
          />
          <HintLabel
            htmlFor="config-showEpisodeThumbnail"
            hint="showEpisodeThumbnail"
          >
            {t('showEpisodeThumbnail')}
          </HintLabel>
        </div>
```

(The `Checkbox` import on this file may now be unused — if `pattern-settings.tsx` does not use `Checkbox` elsewhere, remove the import. Verify with `grep "Checkbox" packages/sp_react/src/components/editor/pattern-settings.tsx`.)

- [ ] **Step 2: Type check + tests.**

```bash
cd packages/sp_react && npx tsc -b --noEmit && pnpm test -- --run pattern-settings
```

Expected: green.

- [ ] **Step 3: Commit.**

```bash
git add packages/sp_react/src/components/editor/pattern-settings.tsx
git commit -m "feat(sp_react): tri-state showEpisodeThumbnail toggle"
```

---

## Task 7: Migrate `display-settings-tab.tsx` to `TriStateCheckbox`

**Files:**
- Modify: `packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx`

This file has two `showThumbnail` toggles (one in `GroupsSubsection`, one in `EpisodesSubsection`) added in the previous bundle. Both move to `TriStateCheckbox`.

- [ ] **Step 1: Add the import.**

At the top of `packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx`:

```tsx
import { TriStateCheckbox } from '@/components/ui/tri-state-checkbox.tsx';
```

- [ ] **Step 2: Replace the GroupsSubsection block.**

Find the block (a `<div className="flex items-center gap-2">` with `<Checkbox id={\`playlist-${index}-group-${activeContext}-showThumbnail\`} ...>`). Replace with:

```tsx
      <div className="flex items-center gap-2">
        <TriStateCheckbox
          id={`playlist-${index}-group-${activeContext}-showThumbnail`}
          value={watchPath<boolean>(watch, showThumbnailField)}
          onChange={(next) => setPath(setValue, showThumbnailField, next, { shouldDirty: true })}
          title={t('triStateHint')}
        />
        <HintLabel
          htmlFor={`playlist-${index}-group-${activeContext}-showThumbnail`}
          hint="showThumbnail"
        >
          {t('showThumbnail')}
        </HintLabel>
      </div>
```

`watchPath<boolean>` returns `boolean | undefined` already; we just stop appending `?? true`.

- [ ] **Step 3: Replace the EpisodesSubsection block.**

Find the analogous block (with id `\`playlist-${index}-${activeContext}-episode-showThumbnail\``). Replace with:

```tsx
      <div className="flex items-center gap-2">
        <TriStateCheckbox
          id={`playlist-${index}-${activeContext}-episode-showThumbnail`}
          value={watchPath<boolean>(watch, episodeShowThumbnailPath)}
          onChange={(next) =>
            setPath(setValue, episodeShowThumbnailPath, next, { shouldDirty: true })
          }
          title={t('triStateHint')}
        />
        <HintLabel
          htmlFor={`playlist-${index}-${activeContext}-episode-showThumbnail`}
          hint="showThumbnail"
        >
          {t('showThumbnail')}
        </HintLabel>
      </div>
```

- [ ] **Step 4: Verify other uses of plain `Checkbox` in this file are unchanged.**

Other checkboxes in this file (`userSortable`, `prependSeasonNumber`, `pinToYear`, `showDateRange`, `showYearHeaders`) remain binary — those are out of scope. Do NOT touch them.

- [ ] **Step 5: Type check + targeted tests.**

```bash
cd packages/sp_react && npx tsc -b --noEmit && pnpm test -- --run display-settings playlist-form groups-form
```

Expected: green.

- [ ] **Step 6: Commit.**

```bash
git add packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx
git commit -m "feat(sp_react): tri-state group/episode showThumbnail"
```

---

## Task 8: Migrate `group-def-card.tsx` to `TriStateCheckbox`

**Files:**
- Modify: `packages/sp_react/src/components/editor/group-def-card.tsx`

- [ ] **Step 1: Add the import.**

```tsx
import { TriStateCheckbox } from '@/components/ui/tri-state-checkbox.tsx';
```

- [ ] **Step 2: Replace the `showThumbnail` block.**

Find the block (a `<div className="flex items-center gap-2">` containing `<Checkbox id={\`group-${playlistIndex}-${groupIndex}-showThumbnail\`} ...>`). Replace with:

```tsx
          <div className="flex items-center gap-2">
            <TriStateCheckbox
              id={`group-${playlistIndex}-${groupIndex}-showThumbnail`}
              value={watch(`${prefix}.groupItem.showThumbnail`)}
              onChange={(next) =>
                setValue(`${prefix}.groupItem.showThumbnail`, next, { shouldDirty: true })
              }
              title={t('triStateHint')}
            />
            <HintLabel
              htmlFor={`group-${playlistIndex}-${groupIndex}-showThumbnail`}
              hint="showThumbnail"
            >
              {t('showThumbnail')}
            </HintLabel>
          </div>
```

The other checkboxes in the file (`showYearHeaders`, `showDateRange`) remain binary — do NOT touch them.

- [ ] **Step 3: Type check + targeted tests.**

```bash
cd packages/sp_react && npx tsc -b --noEmit && pnpm test -- --run groups-form group-def-card
```

Expected: green.

- [ ] **Step 4: Commit.**

```bash
git add packages/sp_react/src/components/editor/group-def-card.tsx
git commit -m "feat(sp_react): tri-state per-group showThumbnail override"
```

---

## Task 9: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Full Rust gates.**

```bash
cargo test
cargo clippy --all-targets -- -W warnings
```

Expected: green, zero warnings.

- [ ] **Step 2: Full React gates.**

```bash
cd packages/sp_react && pnpm test -- --run && npx oxlint && npx tsc -b --noEmit
```

Expected: green; only the two pre-existing oxlint warnings in `schema-conformance.test.ts`.

- [ ] **Step 3: Repo aggregates.**

```bash
make lint && make test
```

Expected: green.

- [ ] **Step 4: Sibling data repo still validates.**

```bash
cargo run -p audiflow-smartplaylist-editor --bin audiflow-editor -- validate --data-dir /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist
```

Expected: exit 0, all files valid.

- [ ] **Step 5: Manual UI smoke test (controller, not subagent).**

```bash
cargo run -p audiflow-smartplaylist-editor --bin audiflow-editor -- serve --data-dir /Users/tohru/Documents/src/ghq/github.com/audiflow/audiflow-smartplaylist
```

Open the editor in a browser and verify each toggle:

- Initial state on a fresh load is the dash icon (indeterminate / unset).
- One click → checked (visible check).
- Second click → unchecked (empty box).
- Third click → back to dash.
- Saving with the toggle in dash state writes JSON without the key (verify by inspecting the saved meta.json or playlists/*.json).
- Saving with explicit `false` writes `"show...": false`.
- Saving with explicit `true` writes `"show...": true`.

- [ ] **Step 6: Confirm no leftover changes.**

```bash
git status
```

Expected: clean (or only untracked unrelated files).
