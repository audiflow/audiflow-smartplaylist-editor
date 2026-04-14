# v5 Form Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the editor's playlist form from 5 tabs to 4 (Basic/Filters/Organize/Display) with scope-separated zones, add a shared group context state, and introduce a selector bridge banner on the Display tab.

**Architecture:** Tab wiring lives in `playlist-form.tsx`. Two new reusable components (`ScopeZone`, `GroupContextBar`) host the blue/amber zones introduced in the spec. A new per-playlist `activeGroupContext` slice in the Zustand editor store is shared between the Organize and Display tabs. The existing `resolver-tab.tsx` is renamed to `organize-tab.tsx` and reorganized; `episode-list-tab.tsx` is deleted and its fields merged into a rebuilt `display-settings-tab.tsx`.

**Tech Stack:** React 19, TypeScript, react-hook-form, Zustand, Radix/shadcn UI, Tailwind, react-i18next, Vitest + React Testing Library.

**Spec:** `docs/superpowers/specs/2026-04-12-v5-editor-form-restructure-design.md`

**Prereq:** `docs/superpowers/plans/2026-04-12-v5-groupdef-alignment.md` must land first. This plan assumes `GroupDef` overrides already use `groupListing` / `groupItem` / `episodeListing` / `episodeItem` (not the legacy `display` / `episodeList`).

---

## File Plan

**Create:**
- `packages/sp_react/src/components/editor/shared/scope-zone.tsx` — reusable blue/amber zone wrapper
- `packages/sp_react/src/components/editor/shared/group-context-bar.tsx` — chip selector + add/remove
- `packages/sp_react/src/components/editor/shared/selector-bridge.tsx` — yellow banner on Display
- `packages/sp_react/src/components/editor/shared/__tests__/scope-zone.test.tsx`
- `packages/sp_react/src/components/editor/shared/__tests__/group-context-bar.test.tsx`
- `packages/sp_react/src/components/editor/shared/__tests__/selector-bridge.test.tsx`
- `packages/sp_react/src/components/editor/tabs/organize-tab.tsx` — replaces resolver-tab.tsx
- `packages/sp_react/src/components/editor/tabs/__tests__/organize-tab.test.tsx`
- `packages/sp_react/src/components/editor/tabs/__tests__/display-settings-tab.test.tsx`

**Modify:**
- `packages/sp_react/src/stores/editor-store.ts` — add `activeGroupContext` per-playlist map + actions
- `packages/sp_react/src/stores/__tests__/editor-store.test.ts` — new tests for context actions
- `packages/sp_react/src/components/editor/playlist-form.tsx` — tabs 5→4, remove Episode List, rename resolver→organize
- `packages/sp_react/src/components/editor/tabs/basic-settings-tab.tsx` — confirm only id + displayName
- `packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx` — restructure into bridge + blue + amber zones (Groups/Episodes subsections)
- `packages/sp_react/src/components/editor/__tests__/playlist-form.test.tsx` — update tab assertions
- `packages/sp_react/src/locales/en/editor.json` — remove `tab.episodeList`, rename `tab.resolver`→`tab.organize`, add new keys
- `packages/sp_react/src/locales/ja/editor.json` — same, in Japanese

**Delete:**
- `packages/sp_react/src/components/editor/tabs/episode-list-tab.tsx`

---

## Task 1: Add `activeGroupContext` state to editor store

**Files:**
- Modify: `packages/sp_react/src/stores/editor-store.ts`
- Test: `packages/sp_react/src/stores/__tests__/editor-store.test.ts`

- [ ] **Step 1: Write failing tests for new store actions**

Append to `packages/sp_react/src/stores/__tests__/editor-store.test.ts`:

```typescript
import { describe, expect, it, beforeEach } from 'vitest';
import { useEditorStore } from '@/stores/editor-store.ts';

describe('editor-store — activeGroupContext', () => {
  beforeEach(() => {
    useEditorStore.getState().reset();
  });

  it('defaults to "all" for any playlist id', () => {
    expect(useEditorStore.getState().getActiveGroupContext('any-id')).toBe('all');
  });

  it('stores and retrieves context per playlist id', () => {
    useEditorStore.getState().setActiveGroupContext('playlist-1', 'group-abc');
    useEditorStore.getState().setActiveGroupContext('playlist-2', 'group-xyz');
    expect(useEditorStore.getState().getActiveGroupContext('playlist-1')).toBe('group-abc');
    expect(useEditorStore.getState().getActiveGroupContext('playlist-2')).toBe('group-xyz');
  });

  it('resets context for a specific playlist', () => {
    useEditorStore.getState().setActiveGroupContext('playlist-1', 'group-abc');
    useEditorStore.getState().resetActiveGroupContext('playlist-1');
    expect(useEditorStore.getState().getActiveGroupContext('playlist-1')).toBe('all');
  });

  it('clears all contexts on reset()', () => {
    useEditorStore.getState().setActiveGroupContext('playlist-1', 'group-abc');
    useEditorStore.getState().reset();
    expect(useEditorStore.getState().getActiveGroupContext('playlist-1')).toBe('all');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd packages/sp_react && pnpm vitest run src/stores/__tests__/editor-store.test.ts
```

Expected: FAIL with "getActiveGroupContext is not a function" (or similar).

- [ ] **Step 3: Implement store changes**

Edit `packages/sp_react/src/stores/editor-store.ts`:

```typescript
import { create } from 'zustand';
import type { PreviewResult } from '@/schemas/api-schema.ts';

export type ActiveGroupContext = 'all' | string;

interface EditorState {
  isJsonMode: boolean;
  feedUrl: string;
  isDirty: boolean;
  isSaving: boolean;
  lastSavedAt: Date | null;
  conflictDetected: boolean;
  conflictPath: string | null;
  previewData: PreviewResult | null;
  previewPending: boolean;
  activeGroupContexts: Record<string, ActiveGroupContext>;
  toggleJsonMode: () => void;
  setFeedUrl: (url: string) => void;
  setDirty: (dirty: boolean) => void;
  setSaving: (saving: boolean) => void;
  setLastSavedAt: (date: Date) => void;
  setConflict: (path: string) => void;
  clearConflict: () => void;
  setPreviewData: (data: PreviewResult | null) => void;
  setPreviewPending: (pending: boolean) => void;
  getActiveGroupContext: (playlistId: string) => ActiveGroupContext;
  setActiveGroupContext: (playlistId: string, context: ActiveGroupContext) => void;
  resetActiveGroupContext: (playlistId: string) => void;
  reset: () => void;
}

const initialState = {
  isJsonMode: false,
  feedUrl: '',
  isDirty: false,
  isSaving: false,
  lastSavedAt: null as Date | null,
  conflictDetected: false,
  conflictPath: null as string | null,
  previewData: null as PreviewResult | null,
  previewPending: false,
  activeGroupContexts: {} as Record<string, ActiveGroupContext>,
};

export const useEditorStore = create<EditorState>((set, get) => ({
  ...initialState,
  toggleJsonMode: () => set((state) => ({ isJsonMode: !state.isJsonMode })),
  setFeedUrl: (url) => set((state) => (state.feedUrl === url ? {} : { feedUrl: url })),
  setDirty: (dirty) => set((state) => (state.isDirty === dirty ? {} : { isDirty: dirty })),
  setSaving: (saving) => set((state) => (state.isSaving === saving ? {} : { isSaving: saving })),
  setLastSavedAt: (date) => set({ lastSavedAt: date, isDirty: false }),
  setConflict: (path) => set({ conflictDetected: true, conflictPath: path }),
  clearConflict: () => set({ conflictDetected: false, conflictPath: null }),
  setPreviewData: (data) => set({ previewData: data }),
  setPreviewPending: (pending) => set((state) => (state.previewPending === pending ? {} : { previewPending: pending })),
  getActiveGroupContext: (playlistId) => get().activeGroupContexts[playlistId] ?? 'all',
  setActiveGroupContext: (playlistId, context) =>
    set((state) => ({
      activeGroupContexts: { ...state.activeGroupContexts, [playlistId]: context },
    })),
  resetActiveGroupContext: (playlistId) =>
    set((state) => {
      if (state.activeGroupContexts[playlistId] === undefined) return {};
      const { [playlistId]: _removed, ...rest } = state.activeGroupContexts;
      return { activeGroupContexts: rest };
    }),
  reset: () => set(initialState),
}));
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd packages/sp_react && pnpm vitest run src/stores/__tests__/editor-store.test.ts
```

Expected: PASS (all suites, including the new `activeGroupContext` ones).

- [ ] **Step 5: Commit**

```bash
git add packages/sp_react/src/stores/editor-store.ts packages/sp_react/src/stores/__tests__/editor-store.test.ts
git commit -m "feat(editor-store): add per-playlist activeGroupContext state"
```

---

## Task 2: Create the `ScopeZone` component

**Files:**
- Create: `packages/sp_react/src/components/editor/shared/scope-zone.tsx`
- Test: `packages/sp_react/src/components/editor/shared/__tests__/scope-zone.test.tsx`

- [ ] **Step 1: Write the failing test**

```tsx
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ScopeZone } from '@/components/editor/shared/scope-zone.tsx';

describe('ScopeZone', () => {
  it('renders the title, hint, and children', () => {
    render(
      <ScopeZone tone="playlist" title="Playlist-level" hint="Applies to entire playlist">
        <div>child content</div>
      </ScopeZone>,
    );
    expect(screen.getByText('Playlist-level')).toBeInTheDocument();
    expect(screen.getByText('Applies to entire playlist')).toBeInTheDocument();
    expect(screen.getByText('child content')).toBeInTheDocument();
  });

  it('applies distinct styling classes per tone', () => {
    const { container, rerender } = render(
      <ScopeZone tone="playlist" title="P">x</ScopeZone>,
    );
    const playlistZone = container.firstChild as HTMLElement;
    expect(playlistZone.className).toMatch(/playlist/);

    rerender(<ScopeZone tone="pergroup" title="G">y</ScopeZone>);
    const pergroupZone = container.firstChild as HTMLElement;
    expect(pergroupZone.className).toMatch(/pergroup/);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/shared/__tests__/scope-zone.test.tsx
```

Expected: FAIL with "Cannot find module '@/components/editor/shared/scope-zone.tsx'".

- [ ] **Step 3: Implement the component**

Create `packages/sp_react/src/components/editor/shared/scope-zone.tsx`:

```tsx
import type { ReactNode } from 'react';
import { cn } from '@/lib/utils.ts';

export type ScopeTone = 'playlist' | 'pergroup';

interface ScopeZoneProps {
  tone: ScopeTone;
  title: string;
  hint?: string;
  children: ReactNode;
  className?: string;
}

const TONE_CLASSES: Record<ScopeTone, string> = {
  playlist: 'scope-zone-playlist border-sky-300 bg-sky-50/50',
  pergroup: 'scope-zone-pergroup border-amber-300 bg-amber-50/50',
};

const TITLE_CLASSES: Record<ScopeTone, string> = {
  playlist: 'text-sky-700',
  pergroup: 'text-amber-800',
};

export function ScopeZone({ tone, title, hint, children, className }: ScopeZoneProps) {
  return (
    <section
      data-scope={tone}
      className={cn('rounded-lg border px-4 py-3 space-y-3', TONE_CLASSES[tone], className)}
    >
      <header className="flex items-baseline gap-3">
        <h4 className={cn('text-xs font-semibold uppercase tracking-wider', TITLE_CLASSES[tone])}>
          {title}
        </h4>
        {hint ? <span className="text-xs text-muted-foreground">{hint}</span> : null}
      </header>
      <div className="space-y-3">{children}</div>
    </section>
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/shared/__tests__/scope-zone.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/sp_react/src/components/editor/shared/scope-zone.tsx packages/sp_react/src/components/editor/shared/__tests__/scope-zone.test.tsx
git commit -m "feat(editor): add ScopeZone wrapper for playlist/pergroup zones"
```

---

## Task 3: Create `GroupContextBar` component

**Files:**
- Create: `packages/sp_react/src/components/editor/shared/group-context-bar.tsx`
- Test: `packages/sp_react/src/components/editor/shared/__tests__/group-context-bar.test.tsx`

- [ ] **Step 1: Write the failing test**

```tsx
import { describe, expect, it, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { GroupContextBar } from '@/components/editor/shared/group-context-bar.tsx';

const GROUPS = [
  { id: 'g1', displayName: 'Group 1' },
  { id: 'g2', displayName: 'Group 2' },
];

describe('GroupContextBar', () => {
  it('renders an "All groups" chip plus one chip per group', () => {
    render(
      <GroupContextBar
        groups={GROUPS}
        active="all"
        allLabel="All groups (edit defaults)"
        addLabel="+ Add group"
        onSelect={() => {}}
        onAdd={() => {}}
      />,
    );
    expect(screen.getByRole('button', { name: 'All groups (edit defaults)' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Group 1' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Group 2' })).toBeInTheDocument();
  });

  it('marks the active chip as selected', () => {
    render(
      <GroupContextBar
        groups={GROUPS}
        active="g2"
        allLabel="All groups"
        addLabel="+ Add"
        onSelect={() => {}}
        onAdd={() => {}}
      />,
    );
    const activeChip = screen.getByRole('button', { name: 'Group 2' });
    expect(activeChip).toHaveAttribute('aria-pressed', 'true');
  });

  it('calls onSelect with the chip id when clicked', () => {
    const onSelect = vi.fn();
    render(
      <GroupContextBar
        groups={GROUPS}
        active="all"
        allLabel="All groups"
        addLabel="+ Add"
        onSelect={onSelect}
        onAdd={() => {}}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: 'Group 1' }));
    expect(onSelect).toHaveBeenCalledWith('g1');
  });

  it('calls onAdd when the add chip is clicked', () => {
    const onAdd = vi.fn();
    render(
      <GroupContextBar
        groups={GROUPS}
        active="all"
        allLabel="All groups"
        addLabel="+ Add"
        onSelect={() => {}}
        onAdd={onAdd}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: '+ Add' }));
    expect(onAdd).toHaveBeenCalledTimes(1);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/shared/__tests__/group-context-bar.test.tsx
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement the component**

Create `packages/sp_react/src/components/editor/shared/group-context-bar.tsx`:

```tsx
import { cn } from '@/lib/utils.ts';

export interface GroupChipData {
  id: string;
  displayName: string;
}

interface GroupContextBarProps {
  groups: readonly GroupChipData[];
  active: 'all' | string;
  allLabel: string;
  addLabel: string;
  onSelect: (id: 'all' | string) => void;
  onAdd: () => void;
}

export function GroupContextBar({
  groups,
  active,
  allLabel,
  addLabel,
  onSelect,
  onAdd,
}: GroupContextBarProps) {
  return (
    <div role="toolbar" aria-label="Group context" className="flex flex-wrap items-center gap-2">
      <Chip pressed={active === 'all'} onClick={() => onSelect('all')} variant="default-scope">
        {allLabel}
      </Chip>
      {groups.map((g) => (
        <Chip key={g.id} pressed={active === g.id} onClick={() => onSelect(g.id)}>
          {g.displayName}
        </Chip>
      ))}
      <Chip onClick={onAdd} variant="add">
        {addLabel}
      </Chip>
    </div>
  );
}

interface ChipProps {
  pressed?: boolean;
  onClick: () => void;
  variant?: 'normal' | 'default-scope' | 'add';
  children: React.ReactNode;
}

function Chip({ pressed, onClick, variant = 'normal', children }: ChipProps) {
  return (
    <button
      type="button"
      aria-pressed={pressed ? 'true' : undefined}
      onClick={onClick}
      className={cn(
        'rounded-full border px-3 py-1 text-xs transition-colors',
        variant === 'default-scope' && 'italic',
        variant === 'add' && 'border-dashed text-muted-foreground',
        pressed
          ? 'bg-amber-600 text-white border-amber-600'
          : 'bg-background hover:bg-accent',
      )}
    >
      {children}
    </button>
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/shared/__tests__/group-context-bar.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/sp_react/src/components/editor/shared/group-context-bar.tsx packages/sp_react/src/components/editor/shared/__tests__/group-context-bar.test.tsx
git commit -m "feat(editor): add GroupContextBar shared component"
```

---

## Task 4: Create `SelectorBridge` component

**Files:**
- Create: `packages/sp_react/src/components/editor/shared/selector-bridge.tsx`
- Test: `packages/sp_react/src/components/editor/shared/__tests__/selector-bridge.test.tsx`

- [ ] **Step 1: Write the failing test**

```tsx
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { SelectorBridge } from '@/components/editor/shared/selector-bridge.tsx';

describe('SelectorBridge', () => {
  it('shows the partitionBy value as read-only context', () => {
    render(
      <SelectorBridge partitionBy="seasonNumber" partitionByLabel="seasonNumber">
        <div>title-extractor-form</div>
      </SelectorBridge>,
    );
    expect(screen.getByText(/seasonNumber/)).toBeInTheDocument();
    expect(screen.getByText('title-extractor-form')).toBeInTheDocument();
  });

  it('renders a "not applicable" notice when partitionBy is undefined or "group"', () => {
    const { rerender } = render(
      <SelectorBridge partitionBy={undefined} partitionByLabel="(none)">
        <div>should-not-render</div>
      </SelectorBridge>,
    );
    expect(screen.queryByText('should-not-render')).not.toBeInTheDocument();

    rerender(
      <SelectorBridge partitionBy="group" partitionByLabel="group">
        <div>also-should-not-render</div>
      </SelectorBridge>,
    );
    expect(screen.queryByText('also-should-not-render')).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/shared/__tests__/selector-bridge.test.tsx
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement the component**

Create `packages/sp_react/src/components/editor/shared/selector-bridge.tsx`:

```tsx
import type { ReactNode } from 'react';
import { useTranslation } from 'react-i18next';

type PartitionBy = 'group' | 'seasonNumber' | 'year' | undefined;

interface SelectorBridgeProps {
  partitionBy: PartitionBy;
  partitionByLabel: string;
  children?: ReactNode;
}

export function SelectorBridge({ partitionBy, partitionByLabel, children }: SelectorBridgeProps) {
  const { t } = useTranslation('editor');
  const showTitleExtractor = partitionBy === 'seasonNumber' || partitionBy === 'year';

  return (
    <section
      data-preview-region="selector-bridge"
      className="rounded-lg border border-amber-300 bg-amber-50/50 px-4 py-3 space-y-3"
    >
      <header className="flex items-baseline gap-2">
        <h4 className="text-xs font-semibold uppercase tracking-wider text-amber-800">
          {t('bridge.selector.title')}
        </h4>
        <span className="text-xs text-muted-foreground">
          {t('bridge.selector.partitionBy', { value: partitionByLabel })}
        </span>
      </header>
      {showTitleExtractor ? children : (
        <p className="text-xs italic text-muted-foreground">
          {t('bridge.selector.notApplicable')}
        </p>
      )}
    </section>
  );
}
```

Note: the `bridge.selector.*` i18n keys are added in Task 9.

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/shared/__tests__/selector-bridge.test.tsx
```

Expected: PASS (the test mocks `useTranslation` via the existing i18n test setup, returning keys as-is).

If `useTranslation` is not already mocked globally, add a minimal mock at the top of the test file:

```tsx
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (k: string, v?: Record<string, string>) => (v ? `${k}:${JSON.stringify(v)}` : k) }),
}));
```

- [ ] **Step 5: Commit**

```bash
git add packages/sp_react/src/components/editor/shared/selector-bridge.tsx packages/sp_react/src/components/editor/shared/__tests__/selector-bridge.test.tsx
git commit -m "feat(editor): add SelectorBridge banner component"
```

---

## Task 5: Update i18n locale files

**Files:**
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`

- [ ] **Step 1: Remove the `tab.episodeList` key and rename `tab.resolver` → `tab.organize`**

In `packages/sp_react/src/locales/en/editor.json`, locate the tab keys block (around lines 168–174) and replace:

```json
  "tab.basicSettings": "Basic",
  "tab.episodeFilters": "Filters",
  "tab.episodeList": "Episode List",
  "tab.resolver": "Organize",
  "tab.groups": "Groups",
  "tab.displaySettings": "Display",
  "tab.hasErrors": "has errors"
```

with:

```json
  "tab.basicSettings": "Basic",
  "tab.episodeFilters": "Filters",
  "tab.organize": "Organize",
  "tab.displaySettings": "Display",
  "tab.hasErrors": "has errors",
  "scope.playlist": "Playlist-level",
  "scope.playlistHint": "Applies to the entire playlist",
  "scope.pergroup": "Group settings",
  "scope.pergroupHint_defaults": "Edit playlist defaults",
  "scope.pergroupHint_specific": "Editing {{group}}",
  "context.allGroups": "All groups (edit defaults)",
  "context.addGroup": "+ Add group",
  "bridge.selector.title": "Selector bridge",
  "bridge.selector.partitionBy": "Partition: {{value}} (set in Organize)",
  "bridge.selector.notApplicable": "Not applicable when partition is \"none\" or \"group\".",
  "override.badge": "Override",
  "override.inherit": "Inheriting playlist default.",
  "override.readOnly": "Set at playlist level"
```

- [ ] **Step 2: Apply the same structure to the Japanese locale**

In `packages/sp_react/src/locales/ja/editor.json`, apply the same deletions/renames with Japanese translations:

```json
  "tab.basicSettings": "基本",
  "tab.episodeFilters": "フィルター",
  "tab.organize": "構造",
  "tab.displaySettings": "表示",
  "tab.hasErrors": "エラーがあります",
  "scope.playlist": "プレイリスト全体",
  "scope.playlistHint": "プレイリスト全体に適用",
  "scope.pergroup": "グループ設定",
  "scope.pergroupHint_defaults": "既定値を編集",
  "scope.pergroupHint_specific": "{{group}} を編集中",
  "context.allGroups": "すべてのグループ（既定値）",
  "context.addGroup": "+ グループを追加",
  "bridge.selector.title": "セレクターブリッジ",
  "bridge.selector.partitionBy": "区切り: {{value}}（「構造」タブで設定）",
  "bridge.selector.notApplicable": "区切りが「なし」または「グループ」の場合は適用されません。",
  "override.badge": "上書き",
  "override.inherit": "プレイリストの既定値を継承",
  "override.readOnly": "プレイリスト全体で設定"
```

Keep the rest of the file unchanged; preserve existing keys referenced by other tabs.

- [ ] **Step 3: Verify JSON syntax**

```bash
cd packages/sp_react && node -e "JSON.parse(require('fs').readFileSync('src/locales/en/editor.json')); JSON.parse(require('fs').readFileSync('src/locales/ja/editor.json')); console.log('valid')"
```

Expected: prints `valid`.

- [ ] **Step 4: Search for remaining references to removed/renamed keys**

```bash
cd packages/sp_react && pnpm grep -rn "tab.episodeList\b" src
cd packages/sp_react && pnpm grep -rn "tab.resolver\b" src
```

Expected: matches only in files that will be updated in later tasks (playlist-form.tsx, episode-list-tab.tsx, resolver-tab.tsx test files). No matches elsewhere.

- [ ] **Step 5: Commit**

```bash
git add packages/sp_react/src/locales/en/editor.json packages/sp_react/src/locales/ja/editor.json
git commit -m "i18n(editor): rename/add keys for v5 form restructure"
```

---

## Task 6: Build the new `organize-tab.tsx`

**Files:**
- Create: `packages/sp_react/src/components/editor/tabs/organize-tab.tsx`
- Test: `packages/sp_react/src/components/editor/tabs/__tests__/organize-tab.test.tsx`

The new tab combines the grouping method selector + `selector.partitionBy` (blue zone, playlist-level) with the group context bar + per-group identity/numbering (amber zone). For non-`titleClassifier` grouping types, the amber zone shows only the default `numberingExtractor` with no context bar.

- [ ] **Step 1: Write the failing test**

Create `packages/sp_react/src/components/editor/tabs/__tests__/organize-tab.test.tsx`:

```tsx
import { describe, expect, it } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { FormProvider, useForm } from 'react-hook-form';
import type { ReactNode } from 'react';
import { OrganizeTab } from '@/components/editor/tabs/organize-tab.tsx';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';

function Wrapper({ children, defaultValues }: { children: ReactNode; defaultValues: Partial<PatternConfig> }) {
  const methods = useForm<PatternConfig>({ defaultValues: defaultValues as PatternConfig });
  return <FormProvider {...methods}>{children}</FormProvider>;
}

function baseConfig(overrides: Record<string, unknown> = {}): Partial<PatternConfig> {
  return {
    playlists: [
      {
        id: 'pl-1',
        displayName: 'PL',
        priority: 0,
        grouping: { by: 'seasonNumber' },
        ...overrides,
      } as PatternConfig['playlists'][number],
    ],
  } as Partial<PatternConfig>;
}

describe('OrganizeTab', () => {
  beforeEach(() => useEditorStore.getState().reset());

  it('renders blue zone with grouping method and partitionBy when by != titleClassifier', () => {
    render(
      <Wrapper defaultValues={baseConfig()}>
        <OrganizeTab index={0} playlistCount={1} />
      </Wrapper>,
    );
    expect(screen.getByTestId('scope-playlist')).toBeInTheDocument();
    expect(screen.getByLabelText(/How to organize episodes/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Partition/i)).toBeInTheDocument();
  });

  it('hides the group context bar when by != titleClassifier', () => {
    render(
      <Wrapper defaultValues={baseConfig()}>
        <OrganizeTab index={0} playlistCount={1} />
      </Wrapper>,
    );
    expect(screen.queryByRole('toolbar', { name: /Group context/i })).not.toBeInTheDocument();
  });

  it('shows the group context bar when by == titleClassifier', () => {
    const cfg = baseConfig({
      grouping: {
        by: 'titleClassifier',
        staticClassifiers: [
          { id: 'g1', displayName: 'Group 1' },
        ],
      },
    });
    render(
      <Wrapper defaultValues={cfg}>
        <OrganizeTab index={0} playlistCount={1} />
      </Wrapper>,
    );
    expect(screen.getByRole('toolbar', { name: /Group context/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Group 1' })).toBeInTheDocument();
  });

  it('switches the per-group section from defaults to specific-group fields when chip clicked', () => {
    const cfg = baseConfig({
      grouping: {
        by: 'titleClassifier',
        staticClassifiers: [
          { id: 'g1', displayName: 'Group 1', pattern: 'foo' },
        ],
      },
    });
    render(
      <Wrapper defaultValues={cfg}>
        <OrganizeTab index={0} playlistCount={1} />
      </Wrapper>,
    );
    fireEvent.click(screen.getByRole('button', { name: 'Group 1' }));
    expect(useEditorStore.getState().getActiveGroupContext('pl-1')).toBe('g1');
    expect(screen.getByLabelText(/Match pattern/i)).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/tabs/__tests__/organize-tab.test.tsx
```

Expected: FAIL (module not found).

- [ ] **Step 3: Implement `organize-tab.tsx`**

Create `packages/sp_react/src/components/editor/tabs/organize-tab.tsx`:

```tsx
import { useFormContext, useWatch } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, ResolverType } from '@/schemas/config-schema.ts';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { NumberingExtractorForm } from '@/components/editor/numbering-extractor-form.tsx';
import { GroupDefCard } from '@/components/editor/group-def-card.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';
import { ScopeZone } from '@/components/editor/shared/scope-zone.tsx';
import { GroupContextBar } from '@/components/editor/shared/group-context-bar.tsx';
import { useEditorStore } from '@/stores/editor-store.ts';

const RESOLVER_TYPES = ['seasonNumber', 'year', 'titleDiscovery', 'titleClassifier'] as const;
const PARTITION_OPTIONS = ['group', 'seasonNumber', 'year'] as const;

interface OrganizeTabProps {
  index: number;
  playlistCount: number;
}

export function OrganizeTab({ index }: OrganizeTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const playlistId = useWatch({ control, name: `${prefix}.id` as const });
  const grouping = watch(`${prefix}.grouping`);
  const resolverType = grouping?.by;
  const partitionBy = watch(`${prefix}.selector.partitionBy`);
  const staticClassifiers = (grouping?.staticClassifiers ?? []) as Array<{ id: string; displayName: string }>;

  const activeContext = useEditorStore((s) => s.getActiveGroupContext(playlistId ?? ''));
  const setActiveContext = useEditorStore((s) => s.setActiveGroupContext);
  const resetActiveContext = useEditorStore((s) => s.resetActiveGroupContext);

  const selectedGroupIndex = staticClassifiers.findIndex((g) => g.id === activeContext);
  const isTitleClassifier = resolverType === 'titleClassifier';

  const onGroupingByChange = (val: ResolverType) => {
    setValue(`${prefix}.grouping.by`, val, { shouldDirty: true });
    if (val !== 'titleClassifier') resetActiveContext(playlistId ?? '');
  };

  const onAddGroup = () => {
    const current = staticClassifiers;
    const newId = `group-${current.length + 1}`;
    setValue(
      `${prefix}.grouping.staticClassifiers`,
      [...current, { id: newId, displayName: `Group ${current.length + 1}` }] as never,
      { shouldDirty: true },
    );
    setActiveContext(playlistId ?? '', newId);
  };

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.resolver" />

      <ScopeZone tone="playlist" title={t('scope.playlist')} hint={t('scope.playlistHint')}>
        <div className="space-y-2">
          <HintLabel htmlFor={`playlist-${index}-resolverType`} hint="resolverType">
            {t('resolverType')}
          </HintLabel>
          <Select value={resolverType ?? ''} onValueChange={(v) => onGroupingByChange(v as ResolverType)}>
            <SelectTrigger id={`playlist-${index}-resolverType`} className="w-full">
              <SelectValue placeholder={t('selectResolver')} />
            </SelectTrigger>
            <SelectContent className="min-w-[280px]">
              {RESOLVER_TYPES.map((type) => (
                <SelectItem key={type} value={type} description={t(`resolverDesc_${type}`)}>
                  {t(`resolverLabel_${type}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <HintLabel htmlFor={`playlist-${index}-partitionBy`} hint="partitionBy">
            {t('partitionBy')}
          </HintLabel>
          <Select
            value={partitionBy ?? 'group'}
            onValueChange={(v) => setValue(`${prefix}.selector.partitionBy`, v as typeof PARTITION_OPTIONS[number], { shouldDirty: true })}
          >
            <SelectTrigger id={`playlist-${index}-partitionBy`} className="w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {PARTITION_OPTIONS.map((opt) => (
                <SelectItem key={opt} value={opt}>{t(`partitionBy_${opt}`)}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </ScopeZone>

      <ScopeZone
        tone="pergroup"
        title={t('scope.pergroup')}
        hint={
          activeContext === 'all'
            ? t('scope.pergroupHint_defaults')
            : t('scope.pergroupHint_specific', { group: staticClassifiers[selectedGroupIndex]?.displayName ?? '' })
        }
      >
        {isTitleClassifier ? (
          <GroupContextBar
            groups={staticClassifiers}
            active={activeContext}
            allLabel={t('context.allGroups')}
            addLabel={t('context.addGroup')}
            onSelect={(id) => setActiveContext(playlistId ?? '', id)}
            onAdd={onAddGroup}
          />
        ) : null}

        {activeContext === 'all' ? (
          <>
            <InteractionNote i18nKey="interactionNote.resolver.numberingExtractor" />
            <NumberingExtractorForm
              fieldPath={`${prefix}.grouping.numberingExtractor`}
              idPrefix={`ep-ext-${index}`}
            />
          </>
        ) : (
          isTitleClassifier && 0 <= selectedGroupIndex ? (
            <GroupDefCard index={index} groupIndex={selectedGroupIndex} />
          ) : null
        )}
      </ScopeZone>
    </div>
  );
}
```

> Note: `GroupDefCard` is an existing component used by `groups-form.tsx`. It renders a single group's identity + overrides. If its API needs adapting (e.g., to accept `groupIndex` instead of rendering the whole list), adjust its props at this step; search for `GroupDefCard` usages and update callers.
>
> The `partitionBy` and `partitionBy_*` i18n keys referenced above must be added alongside Task 5's keys. If they aren't yet, add them now (in both locales) and include in the same commit.
>
> Note the comparison `0 <= selectedGroupIndex` (not `selectedGroupIndex >= 0`) — the repo forbids `>` and `>=` per CLAUDE.md numeric-comparison rules.

- [ ] **Step 4: Add `partitionBy*` i18n keys if missing**

Append to `packages/sp_react/src/locales/en/editor.json`:

```json
  "partitionBy": "Partition groups by",
  "partitionBy_group": "None (each group is its own entry)",
  "partitionBy_seasonNumber": "Season number",
  "partitionBy_year": "Year"
```

And to `packages/sp_react/src/locales/ja/editor.json`:

```json
  "partitionBy": "グループの区切り方",
  "partitionBy_group": "なし（各グループを独立した項目に）",
  "partitionBy_seasonNumber": "シーズン番号",
  "partitionBy_year": "年"
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/tabs/__tests__/organize-tab.test.tsx
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/sp_react/src/components/editor/tabs/organize-tab.tsx packages/sp_react/src/components/editor/tabs/__tests__/organize-tab.test.tsx packages/sp_react/src/locales/en/editor.json packages/sp_react/src/locales/ja/editor.json
git commit -m "feat(editor): add organize-tab with scope zones and group context"
```

---

## Task 7: Rebuild `display-settings-tab.tsx`

**Files:**
- Modify: `packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx`
- Test: `packages/sp_react/src/components/editor/tabs/__tests__/display-settings-tab.test.tsx`

The new Display tab has three regions in order:
1. `SelectorBridge` banner (read-only partitionBy, editable `selector.titleExtractor`)
2. Blue zone — `groupListing.sort`, `groupListing.userSortable`, `groupListing.yearBinding`, and the playlist-only `groupItem` fields (`pinToYear`, `prependSeasonNumber`, `groupItem.titleExtractor`)
3. Amber zone with Groups and Episodes subsections (`groupItem.showDateRange`, `episodeListing.*`, `episodeItem.titleExtractor`). Context bar appears only when `grouping.by = titleClassifier`.

- [ ] **Step 1: Write the failing test**

Create `packages/sp_react/src/components/editor/tabs/__tests__/display-settings-tab.test.tsx`:

```tsx
import { describe, expect, it, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { FormProvider, useForm } from 'react-hook-form';
import type { ReactNode } from 'react';
import { DisplaySettingsTab } from '@/components/editor/tabs/display-settings-tab.tsx';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';

function Wrapper({ children, defaultValues }: { children: ReactNode; defaultValues: Partial<PatternConfig> }) {
  const methods = useForm<PatternConfig>({ defaultValues: defaultValues as PatternConfig });
  return <FormProvider {...methods}>{children}</FormProvider>;
}

function cfg(overrides: Record<string, unknown> = {}): Partial<PatternConfig> {
  return {
    playlists: [
      {
        id: 'pl-1', displayName: 'PL', priority: 0,
        grouping: { by: 'seasonNumber' },
        ...overrides,
      } as PatternConfig['playlists'][number],
    ],
  } as Partial<PatternConfig>;
}

describe('DisplaySettingsTab', () => {
  beforeEach(() => useEditorStore.getState().reset());

  it('renders selector bridge, blue zone, and amber zone', () => {
    render(<Wrapper defaultValues={cfg()}><DisplaySettingsTab index={0} /></Wrapper>);
    expect(screen.getByTestId('scope-playlist')).toBeInTheDocument();
    expect(screen.getByTestId('scope-pergroup')).toBeInTheDocument();
  });

  it('hides context bar when grouping.by != titleClassifier', () => {
    render(<Wrapper defaultValues={cfg()}><DisplaySettingsTab index={0} /></Wrapper>);
    expect(screen.queryByRole('toolbar', { name: /Group context/i })).not.toBeInTheDocument();
  });

  it('shows Groups and Episodes subsections', () => {
    render(<Wrapper defaultValues={cfg()}><DisplaySettingsTab index={0} /></Wrapper>);
    expect(screen.getByText(/^Groups$/)).toBeInTheDocument();
    expect(screen.getByText(/^Episodes$/)).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/tabs/__tests__/display-settings-tab.test.tsx
```

Expected: FAIL — scope-playlist/scope-pergroup test ids missing.

- [ ] **Step 3: Implement the rewritten Display tab**

Overwrite `packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx`:

```tsx
import { useFormContext, useWatch } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, YearBinding } from '@/schemas/config-schema.ts';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';
import { ScopeZone } from '@/components/editor/shared/scope-zone.tsx';
import { GroupContextBar } from '@/components/editor/shared/group-context-bar.tsx';
import { SelectorBridge } from '@/components/editor/shared/selector-bridge.tsx';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { SortForm } from '@/components/editor/sort-form.tsx';
import { useEditorStore } from '@/stores/editor-store.ts';

const YEAR_BINDING_OPTIONS = ['none', 'pinToYear', 'splitByYear'] as const;

interface DisplaySettingsTabProps {
  index: number;
}

export function DisplaySettingsTab({ index }: DisplaySettingsTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const playlistId = useWatch({ control, name: `${prefix}.id` as const });
  const partitionBy = watch(`${prefix}.selector.partitionBy`);
  const resolverType = watch(`${prefix}.grouping.by`);
  const staticClassifiers = (watch(`${prefix}.grouping.staticClassifiers`) ?? []) as Array<{ id: string; displayName: string }>;
  const activeContext = useEditorStore((s) => s.getActiveGroupContext(playlistId ?? ''));
  const setActiveContext = useEditorStore((s) => s.setActiveGroupContext);
  const selectedIdx = staticClassifiers.findIndex((g) => g.id === activeContext);
  const isTitleClassifier = resolverType === 'titleClassifier';

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.displaySettings" />

      <SelectorBridge partitionBy={partitionBy} partitionByLabel={t(`partitionBy_${partitionBy ?? 'group'}`)}>
        <TitleExtractorForm
          fieldPath={`${prefix}.selector.titleExtractor`}
          idPrefix={`selector-title-${index}`}
        />
      </SelectorBridge>

      <ScopeZone tone="playlist" title={t('scope.playlist')} hint={t('scope.playlistHint')}>
        <div data-testid="scope-playlist" className="space-y-3">
          <SortForm
            fieldPath={`${prefix}.groupListing.sort`}
            idPrefix={`group-sort-${index}`}
          />

          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-userSortable`}
              checked={watch(`${prefix}.groupListing.userSortable`) ?? true}
              onCheckedChange={(c) => setValue(`${prefix}.groupListing.userSortable`, !!c, { shouldDirty: true })}
            />
            <HintLabel htmlFor={`playlist-${index}-userSortable`} hint="userSortable">{t('userSortable')}</HintLabel>
          </div>

          <div className="space-y-1.5">
            <HintLabel htmlFor={`playlist-${index}-yearBinding`} hint="yearBinding">
              {t('yearBinding')}
            </HintLabel>
            <Select
              value={watch(`${prefix}.groupListing.yearBinding`) ?? 'none'}
              onValueChange={(v) => setValue(
                `${prefix}.groupListing.yearBinding`,
                v === 'none' ? undefined : (v as YearBinding),
                { shouldDirty: true },
              )}
            >
              <SelectTrigger id={`playlist-${index}-yearBinding`} className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {YEAR_BINDING_OPTIONS.map((o) => (
                  <SelectItem key={o} value={o}>{t(`yearBinding_${o}`)}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-prependSeasonNumber`}
              checked={watch(`${prefix}.groupItem.prependSeasonNumber`) ?? false}
              onCheckedChange={(c) => setValue(`${prefix}.groupItem.prependSeasonNumber`, !!c, { shouldDirty: true })}
            />
            <HintLabel htmlFor={`playlist-${index}-prependSeasonNumber`} hint="prependSeasonNumber">
              {t('prependSeasonNumber')}
            </HintLabel>
          </div>

          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-pinToYear`}
              checked={watch(`${prefix}.groupItem.pinToYear`) ?? false}
              onCheckedChange={(c) => setValue(`${prefix}.groupItem.pinToYear`, !!c, { shouldDirty: true })}
            />
            <HintLabel htmlFor={`playlist-${index}-pinToYear`} hint="pinToYear">
              {t('pinToYear')}
            </HintLabel>
          </div>

          <TitleExtractorForm
            fieldPath={`${prefix}.groupItem.titleExtractor`}
            idPrefix={`group-title-${index}`}
          />
        </div>
      </ScopeZone>

      <ScopeZone
        tone="pergroup"
        title={t('scope.pergroup')}
        hint={
          activeContext === 'all'
            ? t('scope.pergroupHint_defaults')
            : t('scope.pergroupHint_specific', { group: staticClassifiers[selectedIdx]?.displayName ?? '' })
        }
      >
        <div data-testid="scope-pergroup" className="space-y-4">
          {isTitleClassifier ? (
            <GroupContextBar
              groups={staticClassifiers}
              active={activeContext}
              allLabel={t('context.allGroups')}
              addLabel={t('context.addGroup')}
              onSelect={(id) => setActiveContext(playlistId ?? '', id)}
              onAdd={() => {
                const newId = `group-${staticClassifiers.length + 1}`;
                setValue(
                  `${prefix}.grouping.staticClassifiers`,
                  [...staticClassifiers, { id: newId, displayName: `Group ${staticClassifiers.length + 1}` }] as never,
                  { shouldDirty: true },
                );
                setActiveContext(playlistId ?? '', newId);
              }}
            />
          ) : null}

          <GroupsSubsection index={index} activeContext={activeContext} selectedIdx={selectedIdx} />
          <EpisodesSubsection index={index} activeContext={activeContext} selectedIdx={selectedIdx} />
        </div>
      </ScopeZone>
    </div>
  );
}

function GroupsSubsection({ index, activeContext, selectedIdx }: { index: number; activeContext: 'all' | string; selectedIdx: number }) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}` as const;
  const isSpecific = activeContext !== 'all';
  const groupPrefix = isSpecific ? `${prefix}.grouping.staticClassifiers.${selectedIdx}` : '';

  const showDateRangeField = isSpecific
    ? `${groupPrefix}.groupItem.showDateRange` as const
    : `${prefix}.groupItem.showDateRange` as const;

  return (
    <section className="space-y-3">
      <h5 className="text-sm font-semibold">{t('subsection.groups', { defaultValue: 'Groups' })}</h5>
      <InteractionNote i18nKey="interactionNote.displaySettings.yearBindingHeaders" />
      <div className="flex items-center gap-2">
        <Checkbox
          id={`playlist-${index}-group-${activeContext}-showDateRange`}
          checked={watch(showDateRangeField as never) ?? false}
          onCheckedChange={(c) => setValue(showDateRangeField as never, !!c as never, { shouldDirty: true })}
        />
        <HintLabel htmlFor={`playlist-${index}-group-${activeContext}-showDateRange`} hint="showDateRange">
          {t('showDateRange')}
        </HintLabel>
      </div>
    </section>
  );
}

function EpisodesSubsection({ index, activeContext, selectedIdx }: { index: number; activeContext: 'all' | string; selectedIdx: number }) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}` as const;
  const isSpecific = activeContext !== 'all';
  const groupPrefix = isSpecific
    ? `${prefix}.grouping.staticClassifiers.${selectedIdx}`
    : null;

  // v5 post-alignment: GroupDef overrides mirror playlist-level block names.
  const sortPath = isSpecific ? `${groupPrefix}.episodeListing.sort` : `${prefix}.episodeListing.sort`;
  const yearHeadersPath = isSpecific ? `${groupPrefix}.episodeListing.showYearHeaders` : `${prefix}.episodeListing.showYearHeaders`;
  const titleExtractorPath = isSpecific ? `${groupPrefix}.episodeItem.titleExtractor` : `${prefix}.episodeItem.titleExtractor`;

  return (
    <section className="space-y-3">
      <h5 className="text-sm font-semibold">{t('subsection.episodes', { defaultValue: 'Episodes' })}</h5>
      <SortForm fieldPath={sortPath as never} idPrefix={`ep-sort-${index}-${activeContext}`} variant="episode" />
      <div className="flex items-center gap-2">
        <Checkbox
          id={`playlist-${index}-${activeContext}-showYearHeaders`}
          checked={watch(yearHeadersPath as never) ?? false}
          onCheckedChange={(c) => setValue(yearHeadersPath as never, !!c as never, { shouldDirty: true })}
        />
        <HintLabel htmlFor={`playlist-${index}-${activeContext}-showYearHeaders`} hint="showYearHeaders">
          {t('showYearHeaders')}
        </HintLabel>
      </div>
      <TitleExtractorForm fieldPath={titleExtractorPath as never} idPrefix={`ep-title-${index}-${activeContext}`} />
    </section>
  );
}
```

> Notes:
>
> - `SortForm` currently may only cover group sort (not episode sort). If it doesn't accept a `variant="episode"` prop, extend it (or create a sibling `EpisodeSortForm`) to render the `EpisodeSortRule` fields. Do this as a minimal inline fix during this task.
> - `TitleExtractorForm` is reused. If it currently assumes a specific `resolverType`, add an optional escape hatch so it works both at playlist level and per-group level.
> - The `subsection.groups` and `subsection.episodes` i18n keys are added in Step 4.

- [ ] **Step 4: Add i18n keys for the Groups/Episodes subsection headings**

Add to both `en/editor.json` and `ja/editor.json`:

English:
```json
  "subsection.groups": "Groups",
  "subsection.episodes": "Episodes"
```

Japanese:
```json
  "subsection.groups": "グループ",
  "subsection.episodes": "エピソード"
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/tabs/__tests__/display-settings-tab.test.tsx
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx packages/sp_react/src/components/editor/tabs/__tests__/display-settings-tab.test.tsx packages/sp_react/src/locales/en/editor.json packages/sp_react/src/locales/ja/editor.json
git commit -m "feat(editor): restructure display tab with scope zones and bridge"
```

---

## Task 8: Update `playlist-form.tsx` to wire the new 4-tab layout

**Files:**
- Modify: `packages/sp_react/src/components/editor/playlist-form.tsx`
- Modify: `packages/sp_react/src/components/editor/__tests__/playlist-form.test.tsx`

- [ ] **Step 1: Update the existing playlist-form test to reflect the new tabs**

Open `packages/sp_react/src/components/editor/__tests__/playlist-form.test.tsx`. Replace any assertions referring to `tab.episodeList` or `tab.resolver`. Add/update assertions:

```tsx
it('renders four tabs in order: basic, filters, organize, display', () => {
  // setup render ...
  const tabs = screen.getAllByRole('tab');
  expect(tabs.map((el) => el.textContent?.trim())).toEqual([
    expect.stringContaining('Basic'),
    expect.stringContaining('Filters'),
    expect.stringContaining('Organize'),
    expect.stringContaining('Display'),
  ]);
});

it('does not render an Episode List tab', () => {
  expect(screen.queryByRole('tab', { name: /Episode List/i })).not.toBeInTheDocument();
});
```

Keep other existing assertions functional. Any existing references to `tab.resolver` should become `tab.organize`.

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/__tests__/playlist-form.test.tsx
```

Expected: FAIL — old form still has 5 tabs.

- [ ] **Step 3: Update `playlist-form.tsx`**

Replace the body of `packages/sp_react/src/components/editor/playlist-form.tsx` with:

```tsx
import { useMemo } from 'react';
import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { useFeed } from '@/api/queries.ts';
import { Button } from '@/components/ui/button.tsx';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs.tsx';
import { Accordion, AccordionItem, AccordionTrigger, AccordionContent } from '@/components/ui/accordion.tsx';
import { BasicSettingsTab } from '@/components/editor/tabs/basic-settings-tab.tsx';
import { EpisodeFilterTab } from '@/components/editor/tabs/episode-filter-tab.tsx';
import { OrganizeTab } from '@/components/editor/tabs/organize-tab.tsx';
import { DisplaySettingsTab } from '@/components/editor/tabs/display-settings-tab.tsx';
import { Trash2 } from 'lucide-react';

interface PlaylistFormProps {
  index: number;
  playlistCount: number;
  onRemove: () => void;
  isNewConfig?: boolean;
}

const EMPTY_TITLES: readonly string[] = [];

function ErrorDot({ visible, label }: { visible: boolean; label: string }) {
  if (!visible) return null;
  return (
    <>
      <span className="ml-1 inline-block h-2 w-2 rounded-full bg-destructive" aria-hidden="true" />
      <span className="sr-only">{label}</span>
    </>
  );
}

export function PlaylistForm({ index, playlistCount, onRemove, isNewConfig }: PlaylistFormProps) {
  const { t } = useTranslation('editor');
  const { formState } = useFormContext<PatternConfig>();

  const feedUrl = useEditorStore((s) => s.feedUrl);
  const feedQuery = useFeed(feedUrl || null);
  const episodeTitles = useMemo(
    () => feedQuery.data?.map((ep) => ep.title) ?? EMPTY_TITLES,
    [feedQuery.data],
  );

  const errors = formState.errors.playlists?.[index];
  const hasBasicError = !!(errors?.id || errors?.displayName);
  const hasFilterError = !!errors?.episodeFilters;
  const hasOrganizeError = !!(errors?.grouping || errors?.selector?.partitionBy);
  const hasDisplayError = !!(
    errors?.selector?.titleExtractor
    || errors?.groupListing
    || errors?.groupItem
    || errors?.episodeListing
    || errors?.episodeItem
  );

  return (
    <div className="space-y-4">
      <Tabs defaultValue={isNewConfig ? 'basic' : 'organize'}>
        <TabsList className="w-full">
          <TabsTrigger value="basic">
            {t('tab.basicSettings')}
            <ErrorDot visible={hasBasicError} label={t('tab.hasErrors')} />
          </TabsTrigger>
          <TabsTrigger value="filters">
            {t('tab.episodeFilters')}
            <ErrorDot visible={hasFilterError} label={t('tab.hasErrors')} />
          </TabsTrigger>
          <TabsTrigger value="organize">
            {t('tab.organize')}
            <ErrorDot visible={hasOrganizeError} label={t('tab.hasErrors')} />
          </TabsTrigger>
          <TabsTrigger value="display">
            {t('tab.displaySettings')}
            <ErrorDot visible={hasDisplayError} label={t('tab.hasErrors')} />
          </TabsTrigger>
        </TabsList>

        <TabsContent value="basic">
          <BasicSettingsTab index={index} />
        </TabsContent>
        <TabsContent value="filters">
          <EpisodeFilterTab index={index} episodeTitles={episodeTitles} />
        </TabsContent>
        <TabsContent value="organize">
          <OrganizeTab index={index} playlistCount={playlistCount} />
        </TabsContent>
        <TabsContent value="display">
          <DisplaySettingsTab index={index} />
        </TabsContent>
      </Tabs>

      <Accordion type="single" collapsible className="mt-8">
        <AccordionItem value="danger-zone" className="border-destructive/30">
          <AccordionTrigger className="text-sm text-destructive hover:text-destructive">
            {t('dangerZone')}
          </AccordionTrigger>
          <AccordionContent>
            <div className="flex justify-end pt-2">
              <Button variant="destructive" size="sm" type="button" onClick={onRemove}>
                <Trash2 className="mr-2 h-4 w-4" />
                {t('removePlaylist')}
              </Button>
            </div>
          </AccordionContent>
        </AccordionItem>
      </Accordion>
    </div>
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd packages/sp_react && pnpm vitest run src/components/editor/__tests__/playlist-form.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/sp_react/src/components/editor/playlist-form.tsx packages/sp_react/src/components/editor/__tests__/playlist-form.test.tsx
git commit -m "feat(editor): reduce playlist form to 4 tabs and wire organize tab"
```

---

## Task 9: Delete `episode-list-tab.tsx` and `resolver-tab.tsx`

**Files:**
- Delete: `packages/sp_react/src/components/editor/tabs/episode-list-tab.tsx`
- Delete: `packages/sp_react/src/components/editor/tabs/resolver-tab.tsx`

- [ ] **Step 1: Verify no remaining imports**

```bash
cd packages/sp_react && pnpm grep -rn "episode-list-tab" src
cd packages/sp_react && pnpm grep -rn "resolver-tab" src
cd packages/sp_react && pnpm grep -rn "EpisodeListTab" src
cd packages/sp_react && pnpm grep -rn "ResolverTab" src
```

Expected: no matches (all consumers updated in Task 8).

- [ ] **Step 2: Delete the files**

```bash
cd packages/sp_react && rm src/components/editor/tabs/episode-list-tab.tsx src/components/editor/tabs/resolver-tab.tsx
```

- [ ] **Step 3: Run the full test suite to catch regressions**

```bash
cd packages/sp_react && pnpm vitest run
```

Expected: PASS (or clearly-related failures that we'll fix next).

If there are failures referencing the old resolver tab test file, remove/replace them. Move any unique tests from the old resolver test file into `organize-tab.test.tsx` if they're still relevant.

- [ ] **Step 4: Commit**

```bash
git add -A packages/sp_react/src/components/editor/tabs
git commit -m "refactor(editor): remove episode-list-tab and resolver-tab"
```

---

## Task 10: Clean `basic-settings-tab.tsx` and `playlist-tab-content.tsx`

**Files:**
- Modify: `packages/sp_react/src/components/editor/tabs/basic-settings-tab.tsx` (confirm only id + displayName, remove any `priority` handling if present)
- Modify: `packages/sp_react/src/components/editor/playlist-tab-content.tsx` (reset `activeGroupContext` when the playlist id changes, so switching playlists drops the group context)

- [ ] **Step 1: Verify `basic-settings-tab.tsx`**

Open `packages/sp_react/src/components/editor/tabs/basic-settings-tab.tsx` and confirm only `id` (read-only) and `displayName` inputs remain. If a `priority` field exists, remove it — priority is derived from array order (see data repo memory `project_priority_auto_set.md`).

- [ ] **Step 2: Add context reset on playlist switch**

In `packages/sp_react/src/components/editor/playlist-tab-content.tsx`, after the `const playlistId = useWatch(...)` line (around line 42), add:

```tsx
import { useEffect } from 'react';
// ...
const resetActiveGroupContext = useEditorStore((s) => s.resetActiveGroupContext);
useEffect(() => {
  // When this playlist component unmounts or the id changes, clear the context so
  // returning later starts at "all groups" rather than a possibly-stale group id.
  return () => {
    if (playlistId) resetActiveGroupContext(playlistId);
  };
}, [playlistId, resetActiveGroupContext]);
```

- [ ] **Step 3: Run the full test suite**

```bash
cd packages/sp_react && pnpm vitest run
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add packages/sp_react/src/components/editor/tabs/basic-settings-tab.tsx packages/sp_react/src/components/editor/playlist-tab-content.tsx
git commit -m "chore(editor): reset group context on playlist switch"
```

---

## Task 11: Integration check against a real v5 pattern

**Files:** none modified; runs the app manually.

- [ ] **Step 1: Start the dev server**

```bash
cd packages/sp_react && pnpm dev
```

- [ ] **Step 2: Load a known-working pattern**

Open the editor at a v5 pattern URL (e.g., `http://localhost:5173/editor/2e86c4b573b7`).

- [ ] **Step 3: Verify all four tabs render**

Click through Basic → Filters → Organize → Display. Confirm:
- No console errors.
- Organize shows blue zone (method + partitionBy) and amber zone (context bar + numbering extractor or group identity).
- Display shows selector bridge banner, blue zone, Groups + Episodes subsections.
- Changing `grouping.by` from `titleClassifier` to another value hides the context bar but keeps the amber zone visible.

- [ ] **Step 4: Round-trip through JSON mode**

Click "JSON Mode" → confirm the serialized object matches v5 field order. Toggle back → confirm no field values are lost.

- [ ] **Step 5: Commit (if any fixes needed)**

If the manual check surfaces issues, fix and commit with `fix(editor): ...` messages.

---

## Verification

After all tasks:

```bash
cd packages/sp_react && pnpm vitest run && pnpm tsc --noEmit && pnpm lint
```

All three must pass. Commit any last-mile fixes.
