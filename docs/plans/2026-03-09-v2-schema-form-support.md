# V2 Schema Full Form Support

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add missing v2 schema fields to the React editor forms so all schema features are editable without switching to JSON mode.

**Architecture:** The Zod schemas already cover all v2 fields. The gap is purely in UI components: `playlist-form.tsx` (missing description filter) and `group-def-card.tsx` (missing episode sort, title extractor, year binding, and episode extractor overrides). Group-level overrides use collapsible accordion sections to keep cards compact. Existing extractor/sort components are refactored to accept generic form path prefixes for reuse at both playlist and group levels.

**Tech Stack:** React 19, React Hook Form, Zod, shadcn/ui (Accordion), TanStack, i18next, Vitest

---

## Task 1: Add description field to episode filters

**Files:**
- Modify: `packages/sp_react/src/components/editor/playlist-form.tsx` (FilterSettings function)

**Step 1: Add description input to require filter entries**

In `playlist-form.tsx`, update the `requireFields.map(...)` block. After the existing title `<Input>` and its `<RegexTester>`, add a description input:

```tsx
// Inside requireFields.map, after the title Input + RegexTester block:
<div className="flex-1 space-y-1.5">
  <HintLabel hint="filterDescription">{t('filterDescription')}</HintLabel>
  <Input
    {...register(`playlists.${index}.episodeFilters.require.${filterIndex}.description`)}
    placeholder={t('placeholderRegex')}
  />
</div>
```

The existing structure wraps title + delete button in a `flex items-center gap-2` div. Change the layout so each filter entry renders both title and description side-by-side in a grid:

Replace the require filter entry rendering (lines 150-172) with:

```tsx
<div key={field.id} className="space-y-1.5">
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
```

**Step 2: Add description input to exclude filter entries**

Apply the same pattern to the `excludeFields.map(...)` block (lines 187-212). Replace with:

```tsx
<div key={field.id} className="space-y-1.5">
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
```

**Step 3: Run build and existing tests**

Run: `cd packages/sp_react && pnpm build && pnpm test`
Expected: All pass (no schema/test changes needed - translations already exist)

**Step 4: Commit**

```
feat: add description field to episode filter UI
```

---

## Task 2: Refactor TitleExtractorForm for path-generic reuse

The existing `TitleExtractorForm` hardcodes path `playlists.${index}.titleExtractor`. Refactor to accept a generic form path so it can be reused for group-level title extractor overrides.

**Files:**
- Modify: `packages/sp_react/src/components/editor/title-extractor-form.tsx`
- Modify: `packages/sp_react/src/components/editor/extractors-form.tsx`

**Step 1: Add a `fieldPath` prop to TitleExtractorForm**

Change the interface and component to accept a generic path:

```tsx
interface TitleExtractorFormProps {
  fieldPath: string;
  idPrefix: string;
  showCategoryNote?: boolean;
  resolverType?: string;
}
```

Replace the existing `index`-based prop. The component should use `fieldPath` for all `watch()` and `setValue()` calls instead of `playlists.${index}.titleExtractor`.

Key changes:
- `watch(fieldPath)` instead of `watch(\`playlists.${index}.titleExtractor\`)`
- `setValue(fieldPath, ...)` instead of `setValue(\`playlists.${index}.titleExtractor\`, ...)`
- `idPrefix` replaces `playlistIndex` for HTML element IDs (e.g., `${idPrefix}-${stepIndex}-source`)
- `resolverType` is passed in instead of read from form context
- `showCategoryNote` controls whether the category resolver disabled note is shown (default false)

Since RHF `watch`/`setValue` accept `string` paths via `useFormContext<PatternConfig>()`, but TypeScript can't infer deeply nested paths from a string, cast to `any` for the dynamic path:

```tsx
export function TitleExtractorForm({ fieldPath, idPrefix, showCategoryNote, resolverType }: TitleExtractorFormProps) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const extractor = watch(fieldPath as any);
  // ... rest uses setValue(fieldPath as any, ...)
```

**Step 2: Update ExtractorsForm to pass new props**

In `extractors-form.tsx`, update the call:

```tsx
<TitleExtractorForm
  fieldPath={`playlists.${index}.titleExtractor`}
  idPrefix={`title-ext-${index}`}
  resolverType={watch(`playlists.${index}.resolverType`)}
  showCategoryNote
/>
```

Add the `watch` import from `useFormContext`.

**Step 3: Run tests**

Run: `cd packages/sp_react && pnpm test`
Expected: All existing tests pass (title-extractor-utils tests don't touch the component)

**Step 4: Commit**

```
refactor: make TitleExtractorForm path-generic for reuse
```

---

## Task 3: Refactor EpisodeExtractorForm for path-generic reuse

Same pattern as Task 2 but for `EpisodeExtractorForm`.

**Files:**
- Modify: `packages/sp_react/src/components/editor/episode-extractor-form.tsx`
- Modify: `packages/sp_react/src/components/editor/extractors-form.tsx`

**Step 1: Add `fieldPath` and `idPrefix` props**

```tsx
interface EpisodeExtractorFormProps {
  fieldPath: string;
  idPrefix: string;
}
```

Replace `index`-based prop. Change all `watch`/`setValue`/`register` calls to use `fieldPath` and `idPrefix`:

- `watch(fieldPath as any)` instead of `watch(\`playlists.${index}.episodeExtractor\`)`
- `register(\`${fieldPath}.source\` as any)` etc.
- HTML IDs use `idPrefix` (e.g., `${idPrefix}-source`)

**Step 2: Update ExtractorsForm**

```tsx
<EpisodeExtractorForm
  fieldPath={`playlists.${index}.episodeExtractor`}
  idPrefix={`ep-ext-${index}`}
/>
```

**Step 3: Run tests**

Run: `cd packages/sp_react && pnpm test`
Expected: All pass

**Step 4: Commit**

```
refactor: make EpisodeExtractorForm path-generic for reuse
```

---

## Task 4: Add group-level overrides to GroupDefCard

**Files:**
- Modify: `packages/sp_react/src/components/editor/group-def-card.tsx`
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`
- Modify: `packages/sp_react/src/locales/en/hints.json`
- Modify: `packages/sp_react/src/locales/ja/hints.json`

**Step 1: Add i18n keys**

Add to `en/editor.json`:
```json
"groupOverrides": "Group Overrides",
"groupEpisodeSort": "Episode Sort",
"groupTitleExtractor": "Title Extractor",
"groupEpisodeExtractor": "Episode Extractor",
"groupYearBinding": "Year Binding",
"episodeSortField": "Field",
"episodeSortOrder": "Order",
"episodeSortField_publishedAt": "Published Date",
"episodeSortField_episodeNumber": "Episode Number",
"episodeSortField_title": "Title"
```

Add to `ja/editor.json`:
```json
"groupOverrides": "グループオーバーライド",
"groupEpisodeSort": "エピソードソート",
"groupTitleExtractor": "タイトル抽出器",
"groupEpisodeExtractor": "エピソード抽出器",
"groupYearBinding": "年バインディング",
"episodeSortField": "フィールド",
"episodeSortOrder": "順序",
"episodeSortField_publishedAt": "公開日",
"episodeSortField_episodeNumber": "エピソード番号",
"episodeSortField_title": "タイトル"
```

Add to `en/hints.json`:
```json
"groupEpisodeSort": "Override the default episode sort order for this specific group. When unset, inherits the playlist-level episode sort.",
"groupTitleExtractor": "Override the playlist-level title extractor for this group. Extracts display names from episode data.",
"groupEpisodeExtractor": "Override the playlist-level episode extractor for this group. Extracts season/episode numbers from titles.",
"groupYearBinding": "Override the playlist-level year binding for this group. Controls how this group relates to year headers."
```

Add to `ja/hints.json`:
```json
"groupEpisodeSort": "このグループのデフォルトのエピソードソート順を上書きします。未設定の場合、プレイリストレベルのエピソードソートを継承します。",
"groupTitleExtractor": "このグループのプレイリストレベルのタイトル抽出器を上書きします。エピソードデータから表示名を抽出します。",
"groupEpisodeExtractor": "このグループのプレイリストレベルのエピソード抽出器を上書きします。タイトルからシーズン/エピソード番号を抽出します。",
"groupYearBinding": "このグループのプレイリストレベルの年バインディングを上書きします。このグループと年ヘッダーの関係を制御します。"
```

**Step 2: Add imports and override sections to GroupDefCard**

Add imports to `group-def-card.tsx`:

```tsx
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/accordion.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { EpisodeExtractorForm } from '@/components/editor/episode-extractor-form.tsx';
import type { EpisodeSortField, SortOrder, YearBinding } from '@/schemas/config-schema.ts';
```

**Step 3: Add constants**

```tsx
const EPISODE_SORT_FIELDS = ['publishedAt', 'episodeNumber', 'title'] as const;
const SORT_ORDERS = ['ascending', 'descending'] as const;
```

**Step 4: Add group overrides accordion after existing display overrides**

After the existing `<div className="flex gap-6">` block (line 144), add:

```tsx
<Accordion type="multiple" className="w-full">
  {/* Year Binding Override */}
  <AccordionItem value="yearBinding">
    <AccordionTrigger className="py-2 text-xs font-medium text-muted-foreground">
      <HintLabel hint="groupYearBinding">{t('groupYearBinding')}</HintLabel>
    </AccordionTrigger>
    <AccordionContent>
      <Select
        value={watch(`${prefix}.display.yearBinding`) ?? 'none'}
        onValueChange={(v) =>
          setValue(
            `${prefix}.display.yearBinding`,
            v === 'none' ? undefined : (v as YearBinding),
            { shouldDirty: true },
          )
        }
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
    </AccordionContent>
  </AccordionItem>

  {/* Episode Sort Override */}
  <AccordionItem value="episodeSort">
    <AccordionTrigger className="py-2 text-xs font-medium text-muted-foreground">
      <HintLabel hint="groupEpisodeSort">{t('groupEpisodeSort')}</HintLabel>
    </AccordionTrigger>
    <AccordionContent>
      <GroupEpisodeSortOverride prefix={prefix} />
    </AccordionContent>
  </AccordionItem>

  {/* Title Extractor Override */}
  <AccordionItem value="titleExtractor">
    <AccordionTrigger className="py-2 text-xs font-medium text-muted-foreground">
      <HintLabel hint="groupTitleExtractor">{t('groupTitleExtractor')}</HintLabel>
    </AccordionTrigger>
    <AccordionContent>
      <TitleExtractorForm
        fieldPath={`${prefix}.episodeList.titleExtractor`}
        idPrefix={`group-title-ext-${playlistIndex}-${groupIndex}`}
      />
    </AccordionContent>
  </AccordionItem>

  {/* Episode Extractor Override */}
  <AccordionItem value="episodeExtractor">
    <AccordionTrigger className="py-2 text-xs font-medium text-muted-foreground">
      <HintLabel hint="groupEpisodeExtractor">{t('groupEpisodeExtractor')}</HintLabel>
    </AccordionTrigger>
    <AccordionContent>
      <EpisodeExtractorForm
        fieldPath={`${prefix}.episodeExtractor`}
        idPrefix={`group-ep-ext-${playlistIndex}-${groupIndex}`}
      />
    </AccordionContent>
  </AccordionItem>
</Accordion>
```

**Step 5: Add GroupEpisodeSortOverride sub-component**

Add below GroupDefCard in the same file:

```tsx
function GroupEpisodeSortOverride({
  prefix,
}: {
  prefix: string;
}) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const sort = watch(`${prefix}.episodeList.sort` as any);
  const isEnabled = sort != null;

  return (
    <div className="space-y-3">
      <Button
        type="button"
        variant={isEnabled ? 'default' : 'outline'}
        size="sm"
        onClick={() => {
          if (isEnabled) {
            setValue(`${prefix}.episodeList.sort` as any, undefined, { shouldDirty: true });
          } else {
            setValue(
              `${prefix}.episodeList.sort` as any,
              { field: 'publishedAt', order: 'ascending' },
              { shouldDirty: true },
            );
          }
        }}
      >
        {isEnabled ? t('sortEnabled') : t('sortDisabled')}
      </Button>

      {isEnabled && (
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <HintLabel hint="episodeSortField">{t('episodeSortField')}</HintLabel>
            <Select
              value={sort?.field ?? 'publishedAt'}
              onValueChange={(val) =>
                setValue(`${prefix}.episodeList.sort.field` as any, val as EpisodeSortField, { shouldDirty: true })
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
                setValue(`${prefix}.episodeList.sort.order` as any, val as SortOrder, { shouldDirty: true })
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
  );
}
```

**Step 6: Run build and tests**

Run: `cd packages/sp_react && pnpm build && pnpm test`
Expected: All pass

**Step 7: Commit**

```
feat: add group-level override controls with accordion UI
```

---

## Task 5: Verify full round-trip with existing tests

**Files:**
- No new files

**Step 1: Run all tests across the monorepo**

Run: `cd packages/sp_react && pnpm test`
Expected: All pass

**Step 2: Run build**

Run: `cd packages/sp_react && pnpm build`
Expected: Clean build

**Step 3: Manual verification checklist**

Verify the following work correctly by reviewing the code:
- Filter entries render both title and description side-by-side
- Group cards show accordion sections for overrides
- Accordion sections are collapsed by default
- Each override section shows enable/disable or add/remove controls
- Form data round-trips correctly (Zod schema already validates all fields)
- sanitizeConfig strips empty strings recursively (already handles nested objects)

**Step 4: Final commit (if any fixes needed)**

```
fix: address issues from v2 form support verification
```
