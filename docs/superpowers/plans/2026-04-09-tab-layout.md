# Tab Layout & Instructional Notes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the playlist editor form into 6 tabbed categories with always-visible instructional notes, add a client-side filtered episodes preview tab, and enable debounced auto-preview.

**Architecture:** Extract the monolithic `PlaylistForm` into 6 tab panel components rendered inside shadcn/ui `Tabs`. Add `SectionNote` and `InteractionNote` components backed by a new `notes` i18n namespace. Add client-side episode filtering and debounced auto-preview in `editor-layout.tsx`.

**Tech Stack:** React 19, React Hook Form, shadcn/ui Tabs, i18next, Vitest, existing `useDebounce` hook.

---

### Task 1: Add `notes` i18n namespace

**Files:**
- Create: `packages/sp_react/src/locales/en/notes.json`
- Create: `packages/sp_react/src/locales/ja/notes.json`
- Modify: `packages/sp_react/src/lib/i18n.ts`

- [ ] **Step 1: Create English notes translation file**

```json
{
  "sectionNote.basicSettings": "Identity and priority settings for this playlist. The ID must be unique within the pattern. Priority controls the order playlists claim episodes — lower numbers are processed first.",
  "sectionNote.episodeFilters": "Control which episodes from the feed are included in this playlist using regex patterns matched against episode titles and descriptions.",
  "sectionNote.episodeList": "Default settings for how episodes appear within each group or playlist. These can be overridden per group in the Groups tab.",
  "sectionNote.resolver": "Choose how episodes are classified into groups. The resolver type determines the grouping strategy, and playlist structure controls whether groups become separate playlists or stay nested under one parent.",
  "sectionNote.groups": "Define and order groups for this playlist. Groups are meaningful when the playlist structure is set to 'Grouped'. Each group can override episode list and display defaults.",
  "sectionNote.displaySettings": "Visual presentation options that control how episode lists and groups appear in the app. These can be overridden per group.",
  "interactionNote.episodeFilters.requireExclude": "When both require and exclude filters are set, require filters are applied first to select matching episodes, then exclude filters remove any matches from that set. If no require filters are set, all episodes are candidates and only exclude filters apply.",
  "interactionNote.episodeList.titleExtractorChain": "The title extractor tries each step in order. If a step's regex doesn't match, it falls through to the next step. If all steps fail, the fallback value is used.",
  "interactionNote.resolver.resolverStructure": "With 'Split' structure, each resolver group becomes a separate top-level playlist. With 'Grouped' structure, all groups are collected inside a single parent playlist. The resolver type determines what groups are created.",
  "interactionNote.resolver.numberingExtractor": "The numbering extractor is used by the Season Number resolver to extract season and episode numbers from titles. Configure the regex pattern and capture groups to match your podcast's title format.",
  "interactionNote.groups.overrides": "Group-level overrides take precedence over playlist-level defaults set in the Episode List and Display Settings tabs. Leave overrides unset to inherit the defaults.",
  "interactionNote.displaySettings.yearBindingHeaders": "Year Binding controls how groups relate to year sections. 'Show Year Headers' adds year separators within episode lists. These are independent — you can have year headers without year binding, or vice versa."
}
```

- [ ] **Step 2: Create Japanese notes translation file**

```json
{
  "sectionNote.basicSettings": "プレイリストの識別情報と優先度の設定です。IDはパターン内で一意である必要があります。優先度はエピソードの取得順序を制御します。数値が小さいほど先に処理されます。",
  "sectionNote.episodeFilters": "フィードのどのエピソードをこのプレイリストに含めるかを、タイトルや説明文に対する正規表現パターンで制御します。",
  "sectionNote.episodeList": "グループやプレイリスト内でのエピソードの表示方法のデフォルト設定です。グループタブで個別にオーバーライドできます。",
  "sectionNote.resolver": "エピソードをグループに分類する方法を選択します。リゾルバータイプがグループ化の戦略を決定し、プレイリスト構造がグループの表示方法を制御します。",
  "sectionNote.groups": "プレイリストのグループを定義・並び替えます。プレイリスト構造が「グループ」の場合に意味を持ちます。各グループでエピソードリストや表示設定のデフォルトをオーバーライドできます。",
  "sectionNote.displaySettings": "アプリ内でのエピソードリストやグループの表示オプションです。グループごとにオーバーライドできます。",
  "interactionNote.episodeFilters.requireExclude": "RequireとExcludeの両方が設定されている場合、まずRequireに一致するエピソードが選択され、その中からExcludeに一致するものが除外されます。Requireが未設定の場合、全エピソードが対象となりExcludeのみが適用されます。",
  "interactionNote.episodeList.titleExtractorChain": "タイトル抽出器は各ステップを順番に試行します。あるステップの正規表現がマッチしない場合、次のステップにフォールバックします。すべて失敗した場合、フォールバック値が使用されます。",
  "interactionNote.resolver.resolverStructure": "「スプリット」構造では、リゾルバーの各グループが独立したプレイリストになります。「グループ」構造では、すべてのグループが1つの親プレイリストの中にまとめられます。",
  "interactionNote.resolver.numberingExtractor": "ナンバリング抽出器はシーズンナンバーリゾルバーがタイトルからシーズン番号とエピソード番号を抽出するために使用します。ポッドキャストのタイトル形式に合わせて正規表現パターンとキャプチャグループを設定してください。",
  "interactionNote.groups.overrides": "グループレベルのオーバーライドは、エピソードリストタブと表示設定タブで設定したデフォルトより優先されます。オーバーライドを未設定にするとデフォルト値が継承されます。",
  "interactionNote.displaySettings.yearBindingHeaders": "年バインディングはグループと年セクションの関係を制御します。「年ヘッダー表示」はエピソードリスト内に年区切りを追加します。これらは独立した設定です。"
}
```

- [ ] **Step 3: Register the notes namespace in i18n config**

In `packages/sp_react/src/lib/i18n.ts`, add imports and register:

```typescript
// After existing imports, add:
import notesEn from '@/locales/en/notes.json';
import notesJa from '@/locales/ja/notes.json';

// In resources.en, add:
notes: notesEn,

// In resources.ja, add:
notes: notesJa,
```

- [ ] **Step 4: Add note label keys to common namespace**

Add to `packages/sp_react/src/locales/en/common.json`:

```json
"noteLabel.section": "About this section",
"noteLabel.interaction": "How these interact"
```

Add to `packages/sp_react/src/locales/ja/common.json`:

```json
"noteLabel.section": "このセクションについて",
"noteLabel.interaction": "設定の組み合わせ"
```

- [ ] **Step 5: Verify i18n loads without errors**

Run: `cd packages/sp_react && npx tsc -b --noEmit`
Expected: no type errors

- [ ] **Step 6: Commit**

```bash
git add packages/sp_react/src/locales/en/notes.json packages/sp_react/src/locales/ja/notes.json packages/sp_react/src/lib/i18n.ts
git commit -m "feat(i18n): add notes namespace for section and interaction notes"
```

---

### Task 2: Create SectionNote and InteractionNote components

**Files:**
- Create: `packages/sp_react/src/components/editor/note-blocks.tsx`
- Create: `packages/sp_react/src/components/editor/__tests__/note-blocks.test.tsx`

- [ ] **Step 1: Write the test**

```tsx
import { render, screen } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { SectionNote, InteractionNote } from '../note-blocks.tsx';

vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

describe('SectionNote', () => {
  it('renders with blue styling and section label', () => {
    render(<SectionNote i18nKey="sectionNote.basicSettings" />);
    expect(screen.getByText('sectionNote.basicSettings')).toBeInTheDocument();
  });
});

describe('InteractionNote', () => {
  it('renders with amber styling and interaction label', () => {
    render(<InteractionNote i18nKey="interactionNote.episodeFilters.requireExclude" />);
    expect(screen.getByText('interactionNote.episodeFilters.requireExclude')).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/sp_react && pnpm test -- --run src/components/editor/__tests__/note-blocks.test.tsx`
Expected: FAIL — module not found

- [ ] **Step 3: Implement the components**

```tsx
import { useTranslation } from 'react-i18next';

interface NoteProps {
  i18nKey: string;
}

export function SectionNote({ i18nKey }: NoteProps) {
  const { t } = useTranslation('notes');
  const { t: tc } = useTranslation('common');

  return (
    <div className="bg-blue-950/30 border-l-[3px] border-blue-500 rounded-r-md px-4 py-3 mb-4">
      <p className="text-[11px] font-semibold uppercase text-blue-400 mb-1">
        {tc('noteLabel.section')}
      </p>
      <p className="text-sm text-muted-foreground leading-relaxed whitespace-pre-line">
        {t(i18nKey)}
      </p>
    </div>
  );
}

export function InteractionNote({ i18nKey }: NoteProps) {
  const { t } = useTranslation('notes');
  const { t: tc } = useTranslation('common');

  return (
    <div className="bg-amber-950/20 border-l-[3px] border-amber-500 rounded-r-md px-4 py-3 my-3">
      <p className="text-[11px] font-semibold uppercase text-amber-400 mb-1">
        {tc('noteLabel.interaction')}
      </p>
      <p className="text-sm text-muted-foreground leading-relaxed whitespace-pre-line">
        {t(i18nKey)}
      </p>
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/sp_react && pnpm test -- --run src/components/editor/__tests__/note-blocks.test.tsx`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/sp_react/src/components/editor/note-blocks.tsx packages/sp_react/src/components/editor/__tests__/note-blocks.test.tsx
git commit -m "feat(editor): add SectionNote and InteractionNote components"
```

---

### Task 3: Create client-side episode filter utility

**Files:**
- Create: `packages/sp_react/src/lib/episode-filter.ts`
- Create: `packages/sp_react/src/lib/__tests__/episode-filter.test.ts`

- [ ] **Step 1: Write the test**

```typescript
import { describe, it, expect } from 'vitest';
import { filterEpisodes } from '../episode-filter.ts';
import type { FeedEpisode } from '@/schemas/api-schema.ts';

function episode(id: number, title: string, description?: string): FeedEpisode {
  return { id, title, description: description ?? null };
}

describe('filterEpisodes', () => {
  const episodes: FeedEpisode[] = [
    episode(1, 'Season 1 Episode 1', 'A great start'),
    episode(2, 'Season 1 Episode 2', 'Continues'),
    episode(3, 'Bonus: Behind the scenes', 'Extra content'),
    episode(4, 'Season 2 Episode 1', 'New season'),
    episode(5, 'Preview: Coming soon', 'Teaser'),
  ];

  it('returns all episodes when no filters are set', () => {
    const result = filterEpisodes(episodes, {});
    expect(result).toHaveLength(5);
  });

  it('returns all episodes when filters are undefined', () => {
    const result = filterEpisodes(episodes, undefined);
    expect(result).toHaveLength(5);
  });

  it('applies require filter on title (OR across entries)', () => {
    const result = filterEpisodes(episodes, {
      require: [{ title: 'Season 1' }],
    });
    expect(result.map((e) => e.id)).toEqual([1, 2]);
  });

  it('applies exclude filter on title (OR across entries)', () => {
    const result = filterEpisodes(episodes, {
      exclude: [{ title: 'Bonus' }, { title: 'Preview' }],
    });
    expect(result.map((e) => e.id)).toEqual([1, 2, 4]);
  });

  it('applies require then exclude', () => {
    const result = filterEpisodes(episodes, {
      require: [{ title: 'Season' }],
      exclude: [{ title: 'Season 2' }],
    });
    expect(result.map((e) => e.id)).toEqual([1, 2]);
  });

  it('matches description field', () => {
    const result = filterEpisodes(episodes, {
      require: [{ description: 'Extra' }],
    });
    expect(result.map((e) => e.id)).toEqual([3]);
  });

  it('treats require entry with both title and description as AND', () => {
    const result = filterEpisodes(episodes, {
      require: [{ title: 'Season 1', description: 'great' }],
    });
    expect(result.map((e) => e.id)).toEqual([1]);
  });

  it('handles invalid regex gracefully', () => {
    const result = filterEpisodes(episodes, {
      require: [{ title: '[invalid' }],
    });
    expect(result).toHaveLength(0);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/sp_react && pnpm test -- --run src/lib/__tests__/episode-filter.test.ts`
Expected: FAIL — module not found

- [ ] **Step 3: Implement the filter utility**

```typescript
import type { FeedEpisode } from '@/schemas/api-schema.ts';

interface FilterEntry {
  title?: string;
  description?: string;
}

interface EpisodeFilters {
  require?: FilterEntry[];
  exclude?: FilterEntry[];
}

function matchesEntry(episode: FeedEpisode, entry: FilterEntry): boolean {
  if (entry.title) {
    try {
      const re = new RegExp(entry.title, 'i');
      if (!re.test(episode.title)) return false;
    } catch {
      return false;
    }
  }
  if (entry.description) {
    try {
      const re = new RegExp(entry.description, 'i');
      if (!re.test(episode.description ?? '')) return false;
    } catch {
      return false;
    }
  }
  return entry.title !== undefined || entry.description !== undefined;
}

function matchesAnyEntry(episode: FeedEpisode, entries: FilterEntry[]): boolean {
  return entries.some((entry) => matchesEntry(episode, entry));
}

export function filterEpisodes(
  episodes: readonly FeedEpisode[],
  filters: EpisodeFilters | undefined,
): FeedEpisode[] {
  if (!filters) return [...episodes];

  const requireEntries = filters.require?.filter(
    (e) => e.title !== undefined || e.description !== undefined,
  ) ?? [];
  const excludeEntries = filters.exclude?.filter(
    (e) => e.title !== undefined || e.description !== undefined,
  ) ?? [];

  let result = [...episodes];

  if (0 < requireEntries.length) {
    result = result.filter((ep) => matchesAnyEntry(ep, requireEntries));
  }

  if (0 < excludeEntries.length) {
    result = result.filter((ep) => !matchesAnyEntry(ep, excludeEntries));
  }

  return result;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/sp_react && pnpm test -- --run src/lib/__tests__/episode-filter.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/sp_react/src/lib/episode-filter.ts packages/sp_react/src/lib/__tests__/episode-filter.test.ts
git commit -m "feat(lib): add client-side episode filter utility"
```

---

### Task 4: Create FilteredEpisodesPanel component

**Files:**
- Create: `packages/sp_react/src/components/preview/filtered-episodes-panel.tsx`
- Create: `packages/sp_react/src/components/preview/__tests__/filtered-episodes-panel.test.tsx`

- [ ] **Step 1: Write the test**

```tsx
import { render, screen } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { FilteredEpisodesPanel } from '../filtered-episodes-panel.tsx';
import type { FeedEpisode } from '@/schemas/api-schema.ts';

vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, opts?: Record<string, unknown>) =>
      opts?.count !== undefined ? `${opts.count} episodes` : key,
  }),
}));

const episodes: FeedEpisode[] = [
  { id: 1, title: 'Episode 1' },
  { id: 2, title: 'Episode 2' },
];

describe('FilteredEpisodesPanel', () => {
  it('renders episode list with count', () => {
    render(
      <FilteredEpisodesPanel
        episodes={episodes}
        totalCount={5}
      />,
    );
    expect(screen.getByText('Episode 1')).toBeInTheDocument();
    expect(screen.getByText('Episode 2')).toBeInTheDocument();
  });

  it('shows empty message when no episodes match', () => {
    render(
      <FilteredEpisodesPanel
        episodes={[]}
        totalCount={5}
      />,
    );
    expect(screen.getByText('emptyFiltered')).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/sp_react && pnpm test -- --run src/components/preview/__tests__/filtered-episodes-panel.test.tsx`
Expected: FAIL — module not found

- [ ] **Step 3: Implement the component**

```tsx
import { useTranslation } from 'react-i18next';
import type { FeedEpisode } from '@/schemas/api-schema.ts';

interface FilteredEpisodesPanelProps {
  episodes: readonly FeedEpisode[];
  totalCount: number;
}

export function FilteredEpisodesPanel({
  episodes,
  totalCount,
}: FilteredEpisodesPanelProps) {
  const { t } = useTranslation('preview');

  if (episodes.length === 0) {
    return (
      <p className="text-sm text-muted-foreground py-4 text-center">
        {t('emptyFiltered')}
      </p>
    );
  }

  return (
    <div className="space-y-1">
      <p className="text-xs text-muted-foreground mb-2">
        {t('filteredCount', { filtered: episodes.length, total: totalCount })}
      </p>
      <ul className="space-y-1">
        {episodes.map((ep) => (
          <li
            key={ep.id}
            className="text-sm py-1.5 px-2 rounded hover:bg-muted/50"
          >
            <span className="text-foreground">{ep.title}</span>
            {ep.publishedAt && (
              <span className="text-muted-foreground ml-2 text-xs">
                {ep.publishedAt}
              </span>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

- [ ] **Step 4: Add i18n keys for filtered episodes**

Add to `packages/sp_react/src/locales/en/preview.json`:

```json
"tabFiltered": "Filtered Episodes",
"emptyFiltered": "No episodes match the current filters.",
"filteredCount": "{{filtered}} of {{total}} episodes passed filters"
```

Add to `packages/sp_react/src/locales/ja/preview.json` the corresponding Japanese translations:

```json
"tabFiltered": "フィルタ済みエピソード",
"emptyFiltered": "現在のフィルタに一致するエピソードはありません。",
"filteredCount": "{{total}}件中{{filtered}}件のエピソードがフィルタを通過"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/sp_react && pnpm test -- --run src/components/preview/__tests__/filtered-episodes-panel.test.tsx`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add packages/sp_react/src/components/preview/filtered-episodes-panel.tsx packages/sp_react/src/components/preview/__tests__/filtered-episodes-panel.test.tsx packages/sp_react/src/locales/en/preview.json packages/sp_react/src/locales/ja/preview.json
git commit -m "feat(preview): add FilteredEpisodesPanel component"
```

---

### Task 5: Refactor PlaylistForm into tabbed layout

This is the largest task. It extracts the 6 tab panels from `playlist-form.tsx` and wraps them in shadcn/ui `Tabs`.

**Files:**
- Modify: `packages/sp_react/src/components/editor/playlist-form.tsx`
- Create: `packages/sp_react/src/components/editor/tabs/basic-settings-tab.tsx`
- Create: `packages/sp_react/src/components/editor/tabs/episode-filter-tab.tsx`
- Create: `packages/sp_react/src/components/editor/tabs/episode-list-tab.tsx`
- Create: `packages/sp_react/src/components/editor/tabs/resolver-tab.tsx`
- Create: `packages/sp_react/src/components/editor/tabs/groups-tab.tsx`
- Create: `packages/sp_react/src/components/editor/tabs/display-settings-tab.tsx`
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`

- [ ] **Step 1: Add tab label i18n keys**

Add to `packages/sp_react/src/locales/en/editor.json`:

```json
"tab.basicSettings": "Basic",
"tab.episodeFilters": "Filters",
"tab.episodeList": "Episode List",
"tab.resolver": "Resolver",
"tab.groups": "Groups",
"tab.displaySettings": "Display"
```

Add corresponding Japanese keys to `packages/sp_react/src/locales/ja/editor.json`:

```json
"tab.basicSettings": "基本設定",
"tab.episodeFilters": "エピソードフィルタ",
"tab.episodeList": "エピソードリスト",
"tab.resolver": "リゾルバー",
"tab.groups": "グループ",
"tab.displaySettings": "表示設定"
```

- [ ] **Step 2: Create BasicSettingsTab**

Extract the `BasicSettings` function from `playlist-form.tsx` into `tabs/basic-settings-tab.tsx`, adding the `SectionNote`:

```tsx
import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { SectionNote } from '@/components/editor/note-blocks.tsx';

interface BasicSettingsTabProps {
  index: number;
}

export function BasicSettingsTab({ index }: BasicSettingsTabProps) {
  const prefix = `playlists.${index}` as const;
  const { register } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.basicSettings" />
      <div className="space-y-4">
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-id`} hint="playlistId">{t('playlistId')}</HintLabel>
          <Input
            id={`playlist-${index}-id`}
            {...register(`${prefix}.id`)}
            placeholder={t('placeholderPlaylistId')}
          />
        </div>
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-displayName`} hint="displayName">{t('displayName')}</HintLabel>
          <Input
            id={`playlist-${index}-displayName`}
            {...register(`${prefix}.displayName`)}
            placeholder={t('placeholderDisplayName')}
          />
        </div>
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-priority`} hint="priority">{t('priority')}</HintLabel>
          <Input
            id={`playlist-${index}-priority`}
            type="number"
            {...register(`${prefix}.priority`, {
              setValueAs: (v) =>
                v === '' || v === null || v === undefined
                  ? null
                  : Number(v),
            })}
          />
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Create EpisodeFilterTab**

Extract `FilterSettings` into `tabs/episode-filter-tab.tsx`, adding notes:

```tsx
import { useFieldArray, useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { Button } from '@/components/ui/button.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { RegexTester } from '@/components/editor/regex-tester.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';
import { Plus, Trash2 } from 'lucide-react';

interface EpisodeFilterTabProps {
  index: number;
  episodeTitles: readonly string[];
}

export function EpisodeFilterTab({ index, episodeTitles }: EpisodeFilterTabProps) {
  const { register, watch, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const { fields: requireFields, append: appendRequire, remove: removeRequire } = useFieldArray({
    control,
    name: `playlists.${index}.episodeFilters.require` as `playlists.${number}.episodeFilters.require`,
  });

  const { fields: excludeFields, append: appendExclude, remove: removeExclude } = useFieldArray({
    control,
    name: `playlists.${index}.episodeFilters.exclude` as `playlists.${number}.episodeFilters.exclude`,
  });

  return (
    <div className="space-y-3">
      <SectionNote i18nKey="sectionNote.episodeFilters" />

      <div className="rounded-lg border border-border p-4 space-y-3">
        <h5 className="text-xs font-medium text-muted-foreground">{t('requireFilters')}</h5>
        {requireFields.map((field, filterIndex) => {
          const titleValue = watch(`playlists.${index}.episodeFilters.require.${filterIndex}.title`) ?? '';
          return (
            <div key={field.id} className="rounded-lg border border-border p-3">
              <div className="flex items-start gap-2">
                <div className="flex-1 grid grid-cols-2 gap-3">
                  <div className="space-y-1.5">
                    <HintLabel hint="filterTitle">{t('filterTitle')}</HintLabel>
                    <Input
                      {...register(`playlists.${index}.episodeFilters.require.${filterIndex}.title`)}
                      placeholder={t('placeholderRegex')}
                    />
                    {titleValue && <RegexTester pattern={titleValue} variant="include" titles={episodeTitles} />}
                  </div>
                  <div className="space-y-1.5">
                    <HintLabel hint="filterDescription">{t('filterDescription')}</HintLabel>
                    <Input
                      {...register(`playlists.${index}.episodeFilters.require.${filterIndex}.description`)}
                      placeholder={t('placeholderRegex')}
                    />
                  </div>
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="mt-5"
                  onClick={() => removeRequire(filterIndex)}
                >
                  <Trash2 className="h-4 w-4" />
                  <span className="sr-only">{t('removeFilter')}</span>
                </Button>
              </div>
            </div>
          );
        })}
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => appendRequire({ title: '' })}
        >
          <Plus className="mr-2 h-4 w-4" />
          {t('addFilter')}
        </Button>
      </div>

      <InteractionNote i18nKey="interactionNote.episodeFilters.requireExclude" />

      <div className="rounded-lg border border-border p-4 space-y-3">
        <h5 className="text-xs font-medium text-muted-foreground">{t('excludeFilters')}</h5>
        {excludeFields.map((field, filterIndex) => {
          const titleValue = watch(`playlists.${index}.episodeFilters.exclude.${filterIndex}.title`) ?? '';
          return (
            <div key={field.id} className="rounded-lg border border-border p-3">
              <div className="flex items-start gap-2">
                <div className="flex-1 grid grid-cols-2 gap-3">
                  <div className="space-y-1.5">
                    <HintLabel hint="filterTitle">{t('filterTitle')}</HintLabel>
                    <Input
                      {...register(`playlists.${index}.episodeFilters.exclude.${filterIndex}.title`)}
                      placeholder={t('placeholderRegex')}
                    />
                    {titleValue && <RegexTester pattern={titleValue} variant="exclude" titles={episodeTitles} />}
                  </div>
                  <div className="space-y-1.5">
                    <HintLabel hint="filterDescription">{t('filterDescription')}</HintLabel>
                    <Input
                      {...register(`playlists.${index}.episodeFilters.exclude.${filterIndex}.description`)}
                      placeholder={t('placeholderRegex')}
                    />
                  </div>
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="mt-5"
                  onClick={() => removeExclude(filterIndex)}
                >
                  <Trash2 className="h-4 w-4" />
                  <span className="sr-only">{t('removeFilter')}</span>
                </Button>
              </div>
            </div>
          );
        })}
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => appendExclude({ title: '' })}
        >
          <Plus className="mr-2 h-4 w-4" />
          {t('addFilter')}
        </Button>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Create EpisodeListTab**

Extract `EpisodeListSettings` into `tabs/episode-list-tab.tsx`, adding notes:

```tsx
import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, EpisodeSortField, SortOrder } from '@/schemas/config-schema.ts';
import { Button } from '@/components/ui/button.tsx';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';

const EPISODE_SORT_FIELDS = ['publishedAt', 'episodeNumber', 'title'] as const;
const SORT_ORDERS = ['ascending', 'descending'] as const;

interface EpisodeListTabProps {
  index: number;
}

export function EpisodeListTab({ index }: EpisodeListTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const sort = watch(`${prefix}.episodeList.sort`);
  const isSortEnabled = sort != null;

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.episodeList" />

      <div className="rounded-lg border border-border p-4 space-y-3">
        <div className="flex items-center justify-between">
          <HintLabel hint="episodeListSort">{t('episodeListSort')}</HintLabel>
          <Button
            type="button"
            variant={isSortEnabled ? 'default' : 'outline'}
            size="sm"
            onClick={() => {
              if (isSortEnabled) {
                setValue(`${prefix}.episodeList.sort`, undefined, { shouldDirty: true });
              } else {
                setValue(
                  `${prefix}.episodeList.sort`,
                  { field: 'publishedAt', order: 'ascending' },
                  { shouldDirty: true },
                );
              }
            }}
          >
            {isSortEnabled ? t('sortEnabled') : t('sortDisabled')}
          </Button>
        </div>

        {isSortEnabled && (
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <HintLabel hint="episodeSortField">{t('episodeSortField')}</HintLabel>
              <Select
                value={sort?.field ?? 'publishedAt'}
                onValueChange={(val) =>
                  setValue(`${prefix}.episodeList.sort.field`, val as EpisodeSortField, { shouldDirty: true })
                }
              >
                <SelectTrigger className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {EPISODE_SORT_FIELDS.map((f) => (
                    <SelectItem key={f} value={f}>
                      {t(`episodeSortField_${f}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <HintLabel hint="episodeSortOrder">{t('episodeSortOrder')}</HintLabel>
              <Select
                value={sort?.order ?? 'ascending'}
                onValueChange={(val) =>
                  setValue(`${prefix}.episodeList.sort.order`, val as SortOrder, { shouldDirty: true })
                }
              >
                <SelectTrigger className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {SORT_ORDERS.map((o) => (
                    <SelectItem key={o} value={o}>
                      {t(`sortOrder_${o}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        )}
      </div>

      <InteractionNote i18nKey="interactionNote.episodeList.titleExtractorChain" />

      <TitleExtractorForm
        fieldPath={`playlists.${index}.episodeList.titleExtractor`}
        idPrefix={`ep-list-title-ext-${index}`}
      />
    </div>
  );
}
```

- [ ] **Step 5: Create ResolverTab**

Extract `StructureSettings` into `tabs/resolver-tab.tsx`, adding notes and moving `NumberingExtractorForm` here:

```tsx
import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, ResolverType, PlaylistStructure } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { NumberingExtractorForm } from '@/components/editor/numbering-extractor-form.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';

const RESOLVER_TYPES = [
  'seasonNumber',
  'year',
  'titleDiscovery',
  'titleClassifier',
] as const;

const PLAYLIST_STRUCTURES = ['split', 'grouped'] as const;

interface ResolverTabProps {
  index: number;
}

export function ResolverTab({ index }: ResolverTabProps) {
  const prefix = `playlists.${index}` as const;
  const { register, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const resolverType = watch(`${prefix}.resolverType`);

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.resolver" />

      <div className="space-y-4">
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-resolverType`} hint="resolverType">
            {t('resolverType')}
          </HintLabel>
          <Select
            value={resolverType ?? ''}
            onValueChange={(val) => setValue(`${prefix}.resolverType`, val as ResolverType, { shouldDirty: true })}
          >
            <SelectTrigger id={`playlist-${index}-resolverType`}>
              <SelectValue placeholder={t('selectResolver')} />
            </SelectTrigger>
            <SelectContent className="min-w-[280px]">
              {RESOLVER_TYPES.map((type) => (
                <SelectItem
                  key={type}
                  value={type}
                  description={t(`resolverDesc_${type}`)}
                >
                  {t(`resolverLabel_${type}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-playlistStructure`} hint="playlistStructure">
            {t('playlistStructure')}
          </HintLabel>
          <Select
            value={watch(`${prefix}.playlistStructure`) ?? 'grouped'}
            onValueChange={(val) => setValue(`${prefix}.playlistStructure`, val as PlaylistStructure, { shouldDirty: true })}
          >
            <SelectTrigger id={`playlist-${index}-playlistStructure`} className="w-full">
              <SelectValue placeholder={t('playlistStructure_grouped')} />
            </SelectTrigger>
            <SelectContent>
              {PLAYLIST_STRUCTURES.map((type) => (
                <SelectItem key={type} value={type}>
                  {t(`playlistStructure_${type}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <InteractionNote i18nKey="interactionNote.resolver.resolverStructure" />

        {resolverType === 'seasonNumber' && (
          <>
            <div className="space-y-1.5">
              <HintLabel
                htmlFor={`playlist-${index}-nullSeasonGroupKey`}
                hint="nullSeasonGroupKey"
              >
                {t('nullSeasonGroupKey')}
              </HintLabel>
              <Input
                id={`playlist-${index}-nullSeasonGroupKey`}
                type="number"
                {...register(`${prefix}.nullSeasonGroupKey`, {
                  setValueAs: (v) =>
                    v === '' || v === null || v === undefined
                      ? null
                      : Number(v),
                })}
              />
            </div>

            <InteractionNote i18nKey="interactionNote.resolver.numberingExtractor" />

            <NumberingExtractorForm
              fieldPath={`playlists.${index}.numberingExtractor`}
              idPrefix={`resolver-numbering-${index}`}
            />
          </>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 6: Create GroupsTab**

Wrap existing `GroupsForm` in a tab with notes:

```tsx
import { useTranslation } from 'react-i18next';
import { GroupsForm } from '@/components/editor/groups-form.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';

interface GroupsTabProps {
  index: number;
}

export function GroupsTab({ index }: GroupsTabProps) {
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.groups" />
      <InteractionNote i18nKey="interactionNote.groups.overrides" />
      <GroupsForm index={index} />
    </div>
  );
}
```

- [ ] **Step 7: Create DisplaySettingsTab**

Extract `DisplayOptions` into `tabs/display-settings-tab.tsx`, adding notes:

```tsx
import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, YearBinding } from '@/schemas/config-schema.ts';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';

interface DisplaySettingsTabProps {
  index: number;
}

export function DisplaySettingsTab({ index }: DisplaySettingsTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.displaySettings" />

      <div className="space-y-4">
        <div className="flex gap-6 flex-wrap">
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-showYearHeaders`}
              checked={watch(`${prefix}.episodeList.showYearHeaders`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.episodeList.showYearHeaders`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-showYearHeaders`} hint="showYearHeaders">
              {t('showYearHeaders')}
            </HintLabel>
          </div>
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-showDateRange`}
              checked={watch(`${prefix}.groupList.showDateRange`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.groupList.showDateRange`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-showDateRange`} hint="showDateRange">{t('showDateRange')}</HintLabel>
          </div>
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-userSortable`}
              checked={watch(`${prefix}.groupList.userSortable`) ?? true}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.groupList.userSortable`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-userSortable`} hint="userSortable">{t('userSortable')}</HintLabel>
          </div>
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-prependSeasonNumber`}
              checked={watch(`${prefix}.prependSeasonNumber`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.prependSeasonNumber`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-prependSeasonNumber`} hint="prependSeasonNumber">{t('prependSeasonNumber')}</HintLabel>
          </div>
        </div>

        <InteractionNote i18nKey="interactionNote.displaySettings.yearBindingHeaders" />

        <div className="space-y-2">
          <HintLabel htmlFor={`${prefix}.groupList.yearBinding`} hint="yearBinding">
            {t('yearBinding')}
          </HintLabel>
          <Select
            value={watch(`${prefix}.groupList.yearBinding`) ?? 'none'}
            onValueChange={(v) => setValue(`${prefix}.groupList.yearBinding`, v === 'none' ? undefined : v as YearBinding, { shouldDirty: true })}
          >
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="none">{t('yearBinding_none')}</SelectItem>
              <SelectItem value="pinToYear">{t('yearBinding_pinToYear')}</SelectItem>
              <SelectItem value="splitByYear">{t('yearBinding_splitByYear')}</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 8: Rewrite PlaylistForm to use Tabs**

Replace the content of `playlist-form.tsx` with the tabbed layout:

```tsx
import { useMemo } from 'react';
import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { useFeed } from '@/api/queries.ts';
import { Button } from '@/components/ui/button.tsx';
import {
  Tabs, TabsList, TabsTrigger, TabsContent,
} from '@/components/ui/tabs.tsx';
import { BasicSettingsTab } from '@/components/editor/tabs/basic-settings-tab.tsx';
import { EpisodeFilterTab } from '@/components/editor/tabs/episode-filter-tab.tsx';
import { EpisodeListTab } from '@/components/editor/tabs/episode-list-tab.tsx';
import { ResolverTab } from '@/components/editor/tabs/resolver-tab.tsx';
import { GroupsTab } from '@/components/editor/tabs/groups-tab.tsx';
import { DisplaySettingsTab } from '@/components/editor/tabs/display-settings-tab.tsx';
import { Trash2 } from 'lucide-react';

const EMPTY_TITLES: readonly string[] = [];

interface PlaylistFormProps {
  index: number;
  onRemove: () => void;
}

export function PlaylistForm({ index, onRemove }: PlaylistFormProps) {
  const { t } = useTranslation('editor');
  const { formState } = useFormContext<PatternConfig>();

  const feedUrl = useEditorStore((s) => s.feedUrl);
  const feedQuery = useFeed(feedUrl || null);
  const episodeTitles = useMemo(
    () => feedQuery.data?.map((ep) => ep.title) ?? EMPTY_TITLES,
    [feedQuery.data],
  );

  const prefix = `playlists.${index}` as const;
  const errors = formState.errors.playlists?.[index];
  const hasBasicError = !!(errors?.id || errors?.displayName || errors?.priority);
  const hasFilterError = !!errors?.episodeFilters;
  const hasEpisodeListError = !!errors?.episodeList;
  const hasResolverError = !!(errors?.resolverType || errors?.playlistStructure || errors?.nullSeasonGroupKey || errors?.numberingExtractor);
  const hasGroupsError = !!(errors?.groups || errors?.groupList);
  const hasDisplayError = !!(errors?.prependSeasonNumber || errors?.episodeList?.showYearHeaders);

  return (
    <div className="space-y-4">
      <Tabs defaultValue="basic">
        <TabsList className="flex-wrap h-auto">
          <TabsTrigger value="basic">
            {t('tab.basicSettings')}
            {hasBasicError && <span className="ml-1 h-2 w-2 rounded-full bg-destructive inline-block" />}
          </TabsTrigger>
          <TabsTrigger value="filters">
            {t('tab.episodeFilters')}
            {hasFilterError && <span className="ml-1 h-2 w-2 rounded-full bg-destructive inline-block" />}
          </TabsTrigger>
          <TabsTrigger value="episode-list">
            {t('tab.episodeList')}
            {hasEpisodeListError && <span className="ml-1 h-2 w-2 rounded-full bg-destructive inline-block" />}
          </TabsTrigger>
          <TabsTrigger value="resolver">
            {t('tab.resolver')}
            {hasResolverError && <span className="ml-1 h-2 w-2 rounded-full bg-destructive inline-block" />}
          </TabsTrigger>
          <TabsTrigger value="groups">
            {t('tab.groups')}
            {hasGroupsError && <span className="ml-1 h-2 w-2 rounded-full bg-destructive inline-block" />}
          </TabsTrigger>
          <TabsTrigger value="display">
            {t('tab.displaySettings')}
            {hasDisplayError && <span className="ml-1 h-2 w-2 rounded-full bg-destructive inline-block" />}
          </TabsTrigger>
        </TabsList>

        <TabsContent value="basic">
          <BasicSettingsTab index={index} />
        </TabsContent>
        <TabsContent value="filters">
          <EpisodeFilterTab index={index} episodeTitles={episodeTitles} />
        </TabsContent>
        <TabsContent value="episode-list">
          <EpisodeListTab index={index} />
        </TabsContent>
        <TabsContent value="resolver">
          <ResolverTab index={index} />
        </TabsContent>
        <TabsContent value="groups">
          <GroupsTab index={index} />
        </TabsContent>
        <TabsContent value="display">
          <DisplaySettingsTab index={index} />
        </TabsContent>
      </Tabs>

      <div className="flex justify-end">
        <Button variant="destructive" size="sm" type="button" onClick={onRemove}>
          <Trash2 className="mr-2 h-4 w-4" />
          {t('removePlaylist')}
        </Button>
      </div>
    </div>
  );
}
```

- [ ] **Step 9: Verify type check passes**

Run: `cd packages/sp_react && npx tsc -b --noEmit`
Expected: no errors

- [ ] **Step 10: Run existing tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: all tests pass (some may need minor import adjustments)

- [ ] **Step 11: Commit**

```bash
git add packages/sp_react/src/components/editor/tabs/ packages/sp_react/src/components/editor/playlist-form.tsx packages/sp_react/src/locales/
git commit -m "feat(editor): refactor playlist form into 6 tabbed categories with notes"
```

---

### Task 6: Add Filtered Episodes tab to preview panel and debounced auto-preview

**Files:**
- Modify: `packages/sp_react/src/components/editor/playlist-tab-content.tsx`
- Modify: `packages/sp_react/src/components/editor/editor-layout.tsx`

- [ ] **Step 1: Add Filtered Episodes tab to preview panel**

In `playlist-tab-content.tsx`, add the filtered episodes tab. Import `filterEpisodes` and `FilteredEpisodesPanel`, compute filtered episodes from feed data + form filters:

Add imports:

```typescript
import { useMemo } from 'react';
import { useEditorStore } from '@/stores/editor-store.ts';
import { useFeed } from '@/api/queries.ts';
import { filterEpisodes } from '@/lib/episode-filter.ts';
import { FilteredEpisodesPanel } from '@/components/preview/filtered-episodes-panel.tsx';
```

Add new props to `PlaylistTabContentProps`:

```typescript
interface PlaylistTabContentProps {
  index: number;
  previewPlaylist: PreviewPlaylist | null;
  ungroupedEpisodes: PreviewEpisode[];
  excludedEpisodes: PreviewEpisode[];
  globalDebug: PreviewDebug | undefined;
  playlistCount: number;
  isNewPlaylist: boolean;
  onRemove: () => void;
}
```

Inside the component, add feed-based filtering:

```typescript
const feedUrl = useEditorStore((s) => s.feedUrl);
const feedQuery = useFeed(feedUrl || null);
const episodeFilters = watch(`playlists.${index}.episodeFilters`);

const filteredEpisodes = useMemo(
  () => filterEpisodes(feedQuery.data ?? [], episodeFilters),
  [feedQuery.data, episodeFilters],
);

const defaultPreviewTab = isNewPlaylist ? 'filtered' : 'groups';
```

Add the Filtered Episodes tab as the first tab in the `TabsList`, before "groups":

```tsx
<Tabs defaultValue={defaultPreviewTab}>
  <TabsList>
    <TabsTrigger value="filtered">
      {tp('tabFiltered')}
      <Badge variant="secondary" className="ml-1.5">
        {filteredEpisodes.length}
      </Badge>
    </TabsTrigger>
    <TabsTrigger value="groups">
      {/* ... existing */}
    </TabsTrigger>
    {/* ... rest of existing tabs */}
  </TabsList>
  <TabsContent value="filtered">
    <FilteredEpisodesPanel
      episodes={filteredEpisodes}
      totalCount={feedQuery.data?.length ?? 0}
    />
  </TabsContent>
  {/* ... rest of existing tab contents */}
</Tabs>
```

Note: The Filtered Episodes tab renders even without running preview (it uses feed data directly), so move the `<Tabs>` outside the `{previewPlaylist ? (` conditional, showing the filtered tab always and other tabs only when preview data exists.

- [ ] **Step 2: Pass `isNewPlaylist` from editor-layout.tsx**

In `editor-layout.tsx`, add `isNewPlaylist` prop when rendering `PlaylistTabContent`:

```tsx
<PlaylistTabContent
  index={index}
  previewPlaylist={findPreviewPlaylist(index)}
  ungroupedEpisodes={previewMutation.data?.ungrouped ?? []}
  excludedEpisodes={previewMutation.data?.excluded ?? []}
  globalDebug={previewMutation.data?.debug}
  playlistCount={fields.length}
  isNewPlaylist={isNewConfig}
  onRemove={() => {
    remove(index);
    const lastIndex = fields.length - 2;
    if (0 <= lastIndex) {
      setActiveTab(`tab-${Math.min(index, lastIndex)}`);
    }
  }}
/>
```

- [ ] **Step 3: Add debounced auto-preview to editor-layout.tsx**

Add the debounced auto-preview effect after the existing auto-preview-on-load effect (around line 395). This watches form values, debounces, and triggers the preview mutation:

```typescript
import { useDebounce } from '@/hooks/use-debounce.ts';

// Inside EditorLayout, after the existing auto-preview effect:

// Debounced auto-preview: re-run preview when form values change.
// Uses JSON serialization of form values as the watched value.
const formValues = useWatch({ control: form.control });
const serializedValues = useMemo(
  () => JSON.stringify(formValues),
  [formValues],
);
const debouncedValues = useDebounce(serializedValues, 400);

useEffect(() => {
  if (!feedUrl || isJsonMode) return;
  // Skip the initial auto-preview (handled by hasAutoPreviewedRef)
  if (!hasAutoPreviewedRef.current) return;
  const config = form.getValues();
  previewMutationRef.current.mutate(
    { config: sanitizeConfig(config), feedUrl },
    {
      onError: (error) => {
        toast.error(t('toastPreviewError', {
          error: error instanceof Error ? error.message : 'Preview failed',
          defaultValue: 'Preview failed: {{error}}',
        }));
      },
    },
  );
}, [debouncedValues, feedUrl, isJsonMode, form, t]);
```

- [ ] **Step 4: Add one-time auto-switch from Filtered to Preview tab for new playlists**

In `playlist-tab-content.tsx`, add a ref to track the one-time auto-switch and an effect that watches for valid resolver config:

```typescript
const [activePreviewTab, setActivePreviewTab] = useState(defaultPreviewTab);
const hasAutoSwitchedRef = useRef(false);

const resolverType = watch(`playlists.${index}.resolverType`);

useEffect(() => {
  if (hasAutoSwitchedRef.current || !isNewPlaylist) return;
  if (resolverType && previewPlaylist) {
    hasAutoSwitchedRef.current = true;
    setActivePreviewTab('groups');
  }
}, [resolverType, previewPlaylist, isNewPlaylist]);
```

Update the `<Tabs>` to be controlled:

```tsx
<Tabs value={activePreviewTab} onValueChange={setActivePreviewTab}>
```

- [ ] **Step 5: Verify type check and existing tests pass**

Run: `cd packages/sp_react && npx tsc -b --noEmit && pnpm test -- --run`
Expected: no type errors, all tests pass

- [ ] **Step 6: Commit**

```bash
git add packages/sp_react/src/components/editor/playlist-tab-content.tsx packages/sp_react/src/components/editor/editor-layout.tsx
git commit -m "feat(preview): add filtered episodes tab and debounced auto-preview"
```

---

### Task 7: Final verification and cleanup

**Files:**
- All modified files from previous tasks

- [ ] **Step 1: Run full lint**

Run: `cd packages/sp_react && npx oxlint && npx tsc -b --noEmit`
Expected: no warnings or errors

- [ ] **Step 2: Run full test suite**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: all tests pass

- [ ] **Step 3: Manual smoke test**

Run: `cargo run -- serve --data-dir <path-to-data-repo>`
Open the editor in a browser and verify:
1. Tabs appear in the playlist form (Basic, Filters, Episode List, Resolver, Groups, Display)
2. Section notes appear at the top of each tab
3. Interaction notes appear between related fields
4. Switching tabs preserves form state
5. Filtered Episodes tab shows in preview panel
6. Auto-preview updates when changing form fields (with debounce)
7. New playlist starts on Filtered Episodes tab, auto-switches to Groups when resolver is configured
8. Existing playlist starts on Groups tab
9. Validation error dots appear on tabs with errors

- [ ] **Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "fix(editor): address smoke test findings"
```

- [ ] **Step 5: Run `make lint` and `make test` for full workspace validation**

Run: `make lint && make test`
Expected: all pass
