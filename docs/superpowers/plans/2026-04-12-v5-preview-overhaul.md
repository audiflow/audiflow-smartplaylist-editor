# v5 Preview Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the editor preview at the app's mobile breakpoint width and add a two-tier highlight sync system (tab-level persistent outline + field-level brief pulse) that connects form inputs to preview regions.

**Architecture:** A new `previewHighlight` slice in the editor Zustand store carries `activeRegion` (tab-level) and `activeField` (field-level, auto-clears on a timer). A `useHighlight` hook wraps the store for consumers. Form inputs declare their preview target via `data-preview-field`; preview nodes declare themselves via `data-preview-region` / `data-preview-field`. A lightweight `HighlightLayer` component observes those attributes in the preview tree and paints outlines/pulses. Preview column width is constrained to the app's mobile breakpoint via CSS.

**Tech Stack:** React 19, TypeScript, Zustand, Tailwind, Vitest + React Testing Library.

**Spec:** `docs/superpowers/specs/2026-04-12-v5-editor-form-restructure-design.md` (Preview Panel section)

**Assumes:** Plan A (form restructure) landed first. This plan references the new tabs (Organize, Display) and the `SelectorBridge` banner.

---

## File Plan

**Create:**
- `packages/sp_react/src/components/editor/preview/highlight-layer.tsx` — renders outline/pulse overlays based on store state
- `packages/sp_react/src/components/editor/preview/__tests__/highlight-layer.test.tsx`
- `packages/sp_react/src/hooks/use-preview-highlight.ts` — consumer hook for form inputs
- `packages/sp_react/src/hooks/__tests__/use-preview-highlight.test.ts`

**Modify:**
- `packages/sp_react/src/stores/editor-store.ts` — add `activePreviewRegion`, `activePreviewField`, actions
- `packages/sp_react/src/stores/__tests__/editor-store.test.ts` — new tests
- `packages/sp_react/src/components/editor/playlist-tab-content.tsx` — constrain preview width to mobile breakpoint, mount `HighlightLayer`, wire tab changes to `setActivePreviewRegion`
- `packages/sp_react/src/components/editor/playlist-form.tsx` — on tab change, set `activePreviewRegion`
- `packages/sp_react/src/components/editor/tabs/basic-settings-tab.tsx` — attach `data-preview-field` hooks on displayName input
- `packages/sp_react/src/components/editor/tabs/episode-filter-tab.tsx` — attach `data-preview-field` on require/exclude inputs
- `packages/sp_react/src/components/editor/tabs/organize-tab.tsx` — attach `data-preview-field` hooks
- `packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx` — attach `data-preview-field` hooks
- `packages/sp_react/src/components/preview/playlist-tree.tsx` — add `data-preview-region` and `data-preview-field` attrs to rendered group/episode nodes
- `packages/sp_react/src/components/preview/filtered-episodes-panel.tsx` — add `data-preview-region="filters"`
- `packages/sp_react/src/components/preview/ungrouped-episodes-panel.tsx` — add `data-preview-region="ungrouped"`

---

## Task 1: Add preview highlight state to the editor store

**Files:**
- Modify: `packages/sp_react/src/stores/editor-store.ts`
- Test: `packages/sp_react/src/stores/__tests__/editor-store.test.ts`

- [ ] **Step 1: Write failing tests**

Append to `packages/sp_react/src/stores/__tests__/editor-store.test.ts`:

```typescript
describe('editor-store — preview highlight', () => {
  beforeEach(() => useEditorStore.getState().reset());

  it('defaults activePreviewRegion and activePreviewField to null', () => {
    expect(useEditorStore.getState().activePreviewRegion).toBeNull();
    expect(useEditorStore.getState().activePreviewField).toBeNull();
  });

  it('sets and clears activePreviewRegion', () => {
    useEditorStore.getState().setActivePreviewRegion('group-list');
    expect(useEditorStore.getState().activePreviewRegion).toBe('group-list');
    useEditorStore.getState().setActivePreviewRegion(null);
    expect(useEditorStore.getState().activePreviewRegion).toBeNull();
  });

  it('sets activePreviewField and auto-clears after a delay', async () => {
    useEditorStore.getState().pulseActivePreviewField('group-sort', 50);
    expect(useEditorStore.getState().activePreviewField).toBe('group-sort');
    await new Promise((r) => setTimeout(r, 80));
    expect(useEditorStore.getState().activePreviewField).toBeNull();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd packages/sp_react && pnpm vitest run src/stores/__tests__/editor-store.test.ts
```

Expected: FAIL (new actions undefined).

- [ ] **Step 3: Extend the store**

Edit `packages/sp_react/src/stores/editor-store.ts`:

```typescript
// add to EditorState interface:
activePreviewRegion: string | null;
activePreviewField: string | null;
setActivePreviewRegion: (region: string | null) => void;
pulseActivePreviewField: (field: string, ttlMs?: number) => void;

// add to initialState:
activePreviewRegion: null as string | null,
activePreviewField: null as string | null,

// add inside the store factory (alongside other actions):
setActivePreviewRegion: (region) =>
  set((state) => (state.activePreviewRegion === region ? {} : { activePreviewRegion: region })),
pulseActivePreviewField: (field, ttlMs = 1000) => {
  set({ activePreviewField: field });
  setTimeout(() => {
    // only clear if still the same field (avoid racing newer pulses)
    if (get().activePreviewField === field) set({ activePreviewField: null });
  }, ttlMs);
},
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd packages/sp_react && pnpm vitest run src/stores/__tests__/editor-store.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/sp_react/src/stores/editor-store.ts packages/sp_react/src/stores/__tests__/editor-store.test.ts
git commit -m "feat(editor-store): add preview highlight state"
```

---

## Task 2: Create the `usePreviewHighlight` hook

**Files:**
- Create: `packages/sp_react/src/hooks/use-preview-highlight.ts`
- Test: `packages/sp_react/src/hooks/__tests__/use-preview-highlight.test.ts`

- [ ] **Step 1: Write the failing test**

Create `packages/sp_react/src/hooks/__tests__/use-preview-highlight.test.ts`:

```typescript
import { describe, expect, it, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { usePreviewHighlight } from '@/hooks/use-preview-highlight.ts';
import { useEditorStore } from '@/stores/editor-store.ts';

describe('usePreviewHighlight', () => {
  beforeEach(() => useEditorStore.getState().reset());

  it('returns props that call pulseActivePreviewField on focus', () => {
    const { result } = renderHook(() => usePreviewHighlight('group-sort'));
    act(() => result.current.onFocus());
    expect(useEditorStore.getState().activePreviewField).toBe('group-sort');
  });

  it('returns a data attribute for the field id', () => {
    const { result } = renderHook(() => usePreviewHighlight('episode-title'));
    expect(result.current['data-preview-field']).toBe('episode-title');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/sp_react && pnpm vitest run src/hooks/__tests__/use-preview-highlight.test.ts
```

Expected: FAIL — module missing.

- [ ] **Step 3: Implement the hook**

Create `packages/sp_react/src/hooks/use-preview-highlight.ts`:

```typescript
import { useCallback, useMemo } from 'react';
import { useEditorStore } from '@/stores/editor-store.ts';

export function usePreviewHighlight(fieldId: string) {
  const pulse = useEditorStore((s) => s.pulseActivePreviewField);
  const onFocus = useCallback(() => pulse(fieldId), [pulse, fieldId]);
  return useMemo(
    () => ({
      onFocus,
      'data-preview-field': fieldId,
    }),
    [onFocus, fieldId],
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd packages/sp_react && pnpm vitest run src/hooks/__tests__/use-preview-highlight.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/sp_react/src/hooks/use-preview-highlight.ts packages/sp_react/src/hooks/__tests__/use-preview-highlight.test.ts
git commit -m "feat(editor): add usePreviewHighlight hook"
```

---

## Task 3: Create the `HighlightLayer` component

**Files:**
- Create: `packages/sp_react/src/components/editor/preview/highlight-layer.tsx`
- Test: `packages/sp_react/src/components/editor/preview/__tests__/highlight-layer.test.tsx`

`HighlightLayer` subscribes to `activePreviewRegion` and `activePreviewField`, queries the preview DOM subtree for matching elements by data attribute, and overlays styling via an outline ring on the region and a pulse animation on the field. The simplest implementation is to apply CSS classes imperatively via a `useEffect` that toggles classes on matched elements.

- [ ] **Step 1: Write the failing test**

Create `packages/sp_react/src/components/editor/preview/__tests__/highlight-layer.test.tsx`:

```tsx
import { describe, expect, it, beforeEach } from 'vitest';
import { render, act } from '@testing-library/react';
import { HighlightLayer } from '@/components/editor/preview/highlight-layer.tsx';
import { useEditorStore } from '@/stores/editor-store.ts';

describe('HighlightLayer', () => {
  beforeEach(() => useEditorStore.getState().reset());

  it('adds the region-highlight class when activePreviewRegion matches', () => {
    const { container } = render(
      <HighlightLayer>
        <div>
          <div data-preview-region="group-list">group list</div>
        </div>
      </HighlightLayer>,
    );
    const target = container.querySelector('[data-preview-region="group-list"]')!;
    expect(target.classList.contains('preview-region-active')).toBe(false);
    act(() => useEditorStore.getState().setActivePreviewRegion('group-list'));
    expect(target.classList.contains('preview-region-active')).toBe(true);
    act(() => useEditorStore.getState().setActivePreviewRegion(null));
    expect(target.classList.contains('preview-region-active')).toBe(false);
  });

  it('adds the field-pulse class when activePreviewField matches', () => {
    const { container } = render(
      <HighlightLayer>
        <div data-preview-field="group-sort">sort</div>
      </HighlightLayer>,
    );
    const target = container.querySelector('[data-preview-field="group-sort"]')!;
    expect(target.classList.contains('preview-field-pulse')).toBe(false);
    act(() => useEditorStore.getState().pulseActivePreviewField('group-sort', 10_000));
    expect(target.classList.contains('preview-field-pulse')).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/preview/__tests__/highlight-layer.test.tsx
```

Expected: FAIL — module missing.

- [ ] **Step 3: Implement the component**

Create `packages/sp_react/src/components/editor/preview/highlight-layer.tsx`:

```tsx
import { useEffect, useRef, type ReactNode } from 'react';
import { useEditorStore } from '@/stores/editor-store.ts';

interface HighlightLayerProps {
  children: ReactNode;
}

export function HighlightLayer({ children }: HighlightLayerProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const activeRegion = useEditorStore((s) => s.activePreviewRegion);
  const activeField = useEditorStore((s) => s.activePreviewField);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const all = root.querySelectorAll<HTMLElement>('[data-preview-region]');
    all.forEach((el) => {
      el.classList.toggle('preview-region-active', el.dataset.previewRegion === activeRegion);
    });
  }, [activeRegion]);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const all = root.querySelectorAll<HTMLElement>('[data-preview-field]');
    all.forEach((el) => {
      el.classList.toggle('preview-field-pulse', el.dataset.previewField === activeField);
    });
  }, [activeField]);

  return <div ref={rootRef}>{children}</div>;
}
```

- [ ] **Step 4: Add CSS classes**

Add to `packages/sp_react/src/index.css` (or the global stylesheet used by the editor):

```css
.preview-region-active {
  outline: 2px solid rgba(14, 165, 233, 0.35);
  outline-offset: 4px;
  border-radius: 12px;
  transition: outline-color 120ms ease-out;
}

@keyframes preview-field-pulse {
  0%   { box-shadow: 0 0 0 0 rgba(217, 119, 6, 0.6); }
  60%  { box-shadow: 0 0 0 8px rgba(217, 119, 6, 0); }
  100% { box-shadow: 0 0 0 0 rgba(217, 119, 6, 0); }
}

.preview-field-pulse {
  animation: preview-field-pulse 1s ease-out;
  border-radius: 8px;
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/preview/__tests__/highlight-layer.test.tsx
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/sp_react/src/components/editor/preview/highlight-layer.tsx packages/sp_react/src/components/editor/preview/__tests__/highlight-layer.test.tsx packages/sp_react/src/index.css
git commit -m "feat(editor): add HighlightLayer overlay for preview sync"
```

---

## Task 4: Wrap the preview column with `HighlightLayer` and constrain its width

**Files:**
- Modify: `packages/sp_react/src/components/editor/playlist-tab-content.tsx`

- [ ] **Step 1: Add HighlightLayer and width constraint**

In `packages/sp_react/src/components/editor/playlist-tab-content.tsx`, import `HighlightLayer`:

```tsx
import { HighlightLayer } from '@/components/editor/preview/highlight-layer.tsx';
```

Replace the preview column wrapper (around line 136) — the `<div className="rounded-lg border bg-muted/30 p-4 space-y-3 lg:sticky lg:top-20 lg:h-[calc(100dvh-5.5rem)] lg:overflow-y-auto">` — with:

```tsx
<HighlightLayer>
  <div
    className="rounded-lg border bg-muted/30 p-4 space-y-3 lg:sticky lg:top-20 lg:h-[calc(100dvh-5.5rem)] lg:overflow-y-auto"
    data-preview-root
  >
    <div className="mx-auto w-full max-w-[420px]">
      {/* existing Tabs... */}
    </div>
  </div>
</HighlightLayer>
```

> `max-w-[420px]` constrains preview content to roughly the app's mobile breakpoint. Confirm the app's actual mobile breakpoint width (commonly 375–430px) and adjust. Centering with `mx-auto` keeps the preview column readable on wide screens without the preview sprawling.

- [ ] **Step 2: Manually verify**

```bash
cd packages/sp_react && pnpm dev
```

Open the editor at a v5 pattern. Confirm:
- Preview column content renders in a narrow (≈420px) frame.
- No layout regressions on wide or narrow screens.

- [ ] **Step 3: Commit**

```bash
git add packages/sp_react/src/components/editor/playlist-tab-content.tsx
git commit -m "feat(editor): constrain preview width to mobile + add highlight layer"
```

---

## Task 5: Wire tab-level region highlighting

**Files:**
- Modify: `packages/sp_react/src/components/editor/playlist-form.tsx`

- [ ] **Step 1: Add tab→region mapping**

Edit `packages/sp_react/src/components/editor/playlist-form.tsx`:

```tsx
import { useEditorStore } from '@/stores/editor-store.ts';
// ...

const TAB_TO_REGION: Record<string, string | null> = {
  basic: 'playlist-header',
  filters: 'filters',
  organize: 'group-list',
  display: 'group-list',
};

export function PlaylistForm({ index, playlistCount, onRemove, isNewConfig }: PlaylistFormProps) {
  // ... existing setup ...
  const setActivePreviewRegion = useEditorStore((s) => s.setActivePreviewRegion);

  const defaultTab = isNewConfig ? 'basic' : 'organize';

  // initial region on mount
  useEffect(() => {
    setActivePreviewRegion(TAB_TO_REGION[defaultTab] ?? null);
    return () => setActivePreviewRegion(null);
  }, [setActivePreviewRegion, defaultTab]);

  return (
    <div className="space-y-4">
      <Tabs
        defaultValue={defaultTab}
        onValueChange={(v) => setActivePreviewRegion(TAB_TO_REGION[v] ?? null)}
      >
        {/* rest unchanged */}
      </Tabs>
      {/* ... */}
    </div>
  );
}
```

Add `import { useEffect } from 'react';` if not already present.

- [ ] **Step 2: Verify manually**

Start the dev server, switch between tabs, and confirm the preview region outlines shift (group list gets outlined on Organize and Display; filtered area on Filters; etc.). You may need to add matching `data-preview-region` attributes on preview nodes in Task 7 before the outlines appear visually.

- [ ] **Step 3: Commit**

```bash
git add packages/sp_react/src/components/editor/playlist-form.tsx
git commit -m "feat(editor): sync active preview region with active tab"
```

---

## Task 6: Attach `data-preview-field` to form inputs

**Files:** multiple tabs.

This task wires each relevant form input to a preview field id via `usePreviewHighlight`.

- [ ] **Step 1: Define the field id catalog**

Add a small constants module `packages/sp_react/src/components/editor/preview/preview-field-ids.ts`:

```typescript
export const PREVIEW_FIELDS = {
  playlistDisplayName: 'playlist-header',
  filtersRequire: 'filters-require',
  filtersExclude: 'filters-exclude',
  groupingBy: 'group-list',
  partitionBy: 'partition-entries',
  selectorTitleExtractor: 'partition-entries',
  groupListingSort: 'group-list-order',
  groupListingYearBinding: 'group-year-sections',
  groupItemShowDateRange: 'group-card-date-range',
  groupItemPrependSeasonNumber: 'group-card-season-prefix',
  episodeListingSort: 'episode-order',
  episodeItemTitle: 'episode-title',
} as const;

export type PreviewFieldId = (typeof PREVIEW_FIELDS)[keyof typeof PREVIEW_FIELDS];
```

Commit separately:

```bash
git add packages/sp_react/src/components/editor/preview/preview-field-ids.ts
git commit -m "feat(editor): add preview field id catalog"
```

- [ ] **Step 2: Wire `basic-settings-tab.tsx`**

Find the `displayName` input. Attach:

```tsx
import { usePreviewHighlight } from '@/hooks/use-preview-highlight.ts';
import { PREVIEW_FIELDS } from '@/components/editor/preview/preview-field-ids.ts';

// in component:
const displayNameHl = usePreviewHighlight(PREVIEW_FIELDS.playlistDisplayName);

// spread on the input:
<Input {...displayNameHl} {...register(`playlists.${index}.displayName`)} ... />
```

Commit:

```bash
git add packages/sp_react/src/components/editor/tabs/basic-settings-tab.tsx
git commit -m "feat(editor): wire preview highlight on displayName input"
```

- [ ] **Step 3: Wire `episode-filter-tab.tsx`**

For each require row input, spread `usePreviewHighlight(PREVIEW_FIELDS.filtersRequire)`. For exclude rows, `filtersExclude`. Commit.

- [ ] **Step 4: Wire `organize-tab.tsx`**

For the grouping method select, spread `usePreviewHighlight(PREVIEW_FIELDS.groupingBy)`. For the partitionBy select, `partitionBy`. If `SortForm`/`TitleExtractorForm`/`NumberingExtractorForm` accept an optional `previewFieldId` prop that internally spreads `usePreviewHighlight`, add it and pass appropriate ids. Commit.

- [ ] **Step 5: Wire `display-settings-tab.tsx`**

Using the same approach as Task 6.4, spread the appropriate preview-field ids on:
- `groupListing.sort` → `groupListingSort`
- `groupListing.yearBinding` → `groupListingYearBinding`
- `groupItem.showDateRange` → `groupItemShowDateRange`
- `groupItem.prependSeasonNumber` → `groupItemPrependSeasonNumber`
- `episodeListing.sort` → `episodeListingSort`
- `episodeItem.titleExtractor` → `episodeItemTitle`
- `selector.titleExtractor` → `selectorTitleExtractor`

Commit.

- [ ] **Step 6: Run full test suite**

```bash
cd packages/sp_react && pnpm vitest run
```

Expected: PASS. If any tests break because they check specific handler identity / focus behavior, update them to accept the new spread.

---

## Task 7: Attach `data-preview-region` and `data-preview-field` to preview nodes

**Files:**
- Modify: `packages/sp_react/src/components/preview/playlist-tree.tsx`
- Modify: `packages/sp_react/src/components/preview/filtered-episodes-panel.tsx`
- Modify: `packages/sp_react/src/components/preview/ungrouped-episodes-panel.tsx`

- [ ] **Step 1: Tag the filtered panel**

In `filtered-episodes-panel.tsx`, add `data-preview-region="filters"` to the outermost rendered container.

- [ ] **Step 2: Tag the playlist tree**

In `playlist-tree.tsx`, add attributes:
- Outer wrapper: `data-preview-region="group-list"`
- Each group card: `data-preview-field="group-list-order"` and, when it's a per-group highlight target, include `data-preview-region="group-card-<groupId>"`.
- Group card title node: `data-preview-field="group-card-season-prefix"` (so focusing `prependSeasonNumber` pulses titles)
- Episode row: `data-preview-field="episode-title"` for the title element, `data-preview-field="episode-order"` on the episode container so focusing the episode sort field pulses the list.

Keep existing behavior intact; these are added attributes only.

- [ ] **Step 3: Tag the ungrouped panel**

Add `data-preview-region="ungrouped"` to the outer wrapper.

- [ ] **Step 4: Commit**

```bash
git add packages/sp_react/src/components/preview
git commit -m "feat(preview): tag preview nodes with region/field data attrs"
```

---

## Task 8: Selector bridge highlight behavior

**Files:**
- Modify: `packages/sp_react/src/components/editor/shared/selector-bridge.tsx`

The spec states that hovering/focusing the selector bridge should highlight both the partition-entry area and the group list. Implement as a dual-field pulse on hover/focus.

- [ ] **Step 1: Update the component**

Edit `packages/sp_react/src/components/editor/shared/selector-bridge.tsx` to pulse two fields:

```tsx
import { useEditorStore } from '@/stores/editor-store.ts';
// ...
const pulse = useEditorStore((s) => s.pulseActivePreviewField);

return (
  <section
    data-preview-region="selector-bridge"
    onMouseEnter={() => {
      pulse('partition-entries', 1000);
      pulse('group-list-order', 1000);
    }}
    onFocus={() => {
      pulse('partition-entries', 1000);
      pulse('group-list-order', 1000);
    }}
    // ... rest unchanged
  >
```

Because `pulseActivePreviewField` only stores one field at a time, the current store can only highlight one field at a time. To support dual highlight, either:

- **(A)** Extend the store to support a set of fields, OR
- **(B)** Keep single-field and alternate between the two on rapid re-focus, OR
- **(C)** Treat the bridge as a region pulse that temporarily sets `activePreviewRegion = "partition-entries"` then restores the previous region.

Simplest acceptable: **(A)** store a `Set<string>`. Replace `activePreviewField: string | null` with `activePreviewFields: string[]` and update `pulseActivePreviewField` to append-then-auto-remove. Update `HighlightLayer` to toggle the class when the element's field id is in the set.

If that's too much churn, ship **(B)**: pulse one id, then the other on hover-in, and re-pulse both on a short interval while hovered. Document the choice in the commit message.

- [ ] **Step 2: Run full test suite**

```bash
cd packages/sp_react && pnpm vitest run
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add packages/sp_react/src/components/editor/shared/selector-bridge.tsx packages/sp_react/src/stores/editor-store.ts packages/sp_react/src/components/editor/preview/highlight-layer.tsx
git commit -m "feat(editor): selector bridge dual-field highlight"
```

---

## Task 9: Manual verification

- [ ] **Step 1: Start the dev server and open the editor**

```bash
cd packages/sp_react && pnpm dev
```

Navigate to a v5 pattern URL (e.g., `http://localhost:5173/editor/2e86c4b573b7`).

- [ ] **Step 2: Verify mobile-width preview**

Confirm preview column content is constrained to roughly a phone width and stays centered in its column on wide screens.

- [ ] **Step 3: Verify tab-level outlines**

Click through Basic → Filters → Organize → Display. Confirm the expected preview region is outlined in each case.

- [ ] **Step 4: Verify field-level pulses**

Focus a sort control, a title-extractor input, and a checkbox in each tab. Confirm the expected preview element pulses briefly (~1s).

- [ ] **Step 5: Verify selector bridge highlight**

Hover/focus the selector bridge banner on the Display tab. Confirm both the partition-entry area and the group list pulse.

- [ ] **Step 6: Regression check — save/reload**

Save the pattern, reload the page, and confirm the preview + highlights still work without console errors.

---

## Verification

After all tasks:

```bash
cd packages/sp_react && pnpm vitest run && pnpm tsc --noEmit && pnpm lint
```

All three must pass. Fix any last-mile regressions and commit.
