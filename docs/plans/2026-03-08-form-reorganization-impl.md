# Form Reorganization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reorganize playlist editor form sections to clearly separate playlist-level settings from group-level overrides.

**Architecture:** Move resolverType and contentType into a new "Structure" section, rename BooleanSettings to "Display Options", strip GroupsForm down to group cards only, and add "Display Overrides" sub-heading in group cards.

**Tech Stack:** React 19, React Hook Form, i18next, Tailwind CSS, shadcn/ui

---

### Task 1: Add translation keys

**Files:**
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`

**Step 1: Add English translation keys**

Add these entries to `packages/sp_react/src/locales/en/editor.json`:

```json
"structureSettings": "Structure",
"displayOptions": "Display Options",
"displayOverrides": "Display Overrides"
```

**Step 2: Add Japanese translation keys**

Add these entries to `packages/sp_react/src/locales/ja/editor.json`:

```json
"structureSettings": "構造",
"displayOptions": "表示オプション",
"displayOverrides": "表示オーバーライド"
```

**Step 3: Commit**

```bash
git add packages/sp_react/src/locales/en/editor.json packages/sp_react/src/locales/ja/editor.json
git commit -m "feat: add translation keys for form reorganization"
```

---

### Task 2: Create StructureSettings and refactor BasicSettings in playlist-form.tsx

**Files:**
- Modify: `packages/sp_react/src/components/editor/playlist-form.tsx`

**Step 1: Remove resolverType from BasicSettings**

In the `BasicSettings` function, remove the entire `resolverType` `<div>` block (the `<div className="space-y-1.5">` containing the `<HintLabel>` with hint="resolverType" and the `<Select>` component). This is roughly lines 108-129.

**Step 2: Create StructureSettings sub-component**

Add a new `StructureSettings` function in `playlist-form.tsx` after `BasicSettings`. It contains:
- `resolverType` (moved from BasicSettings -- the Select with RESOLVER_TYPES)
- `contentType` (moved from GroupsForm -- the Select with CONTENT_TYPES)
- `nullSeasonGroupKey` (moved from GroupsForm -- the Input shown when resolverType is 'rss')

```tsx
const CONTENT_TYPES = ['episodes', 'groups'] as const;

function StructureSettings({
  index,
  prefix,
}: {
  index: number;
  prefix: `playlists.${number}`;
}) {
  const { register, watch, setValue, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const resolverType = watch(`${prefix}.resolverType`);

  return (
    <div className="space-y-3">
      <h4 className="text-sm font-medium">{t('structureSettings')}</h4>
      <div className="space-y-4">
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-resolverType`} hint="resolverType">
            {t('resolverType')}
          </HintLabel>
          <Select
            value={watch(`${prefix}.resolverType`) ?? ''}
            onValueChange={(val) => setValue(`${prefix}.resolverType`, val, { shouldDirty: true })}
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
          <HintLabel htmlFor={`playlist-${index}-contentType`} hint="contentType">
            {t('contentType')}
          </HintLabel>
          <Controller
            control={control}
            name={`${prefix}.contentType`}
            render={({ field }) => (
              <Select
                value={field.value ?? 'episodes'}
                onValueChange={(val) => {
                  field.onChange(val === 'episodes' ? null : val);
                }}
              >
                <SelectTrigger id={`playlist-${index}-contentType`} className="w-full">
                  <SelectValue placeholder={t('contentType_episodes')} />
                </SelectTrigger>
                <SelectContent>
                  {CONTENT_TYPES.map((type) => (
                    <SelectItem key={type} value={type}>
                      {t(`contentType_${type}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </div>

        {resolverType === 'rss' && (
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
        )}
      </div>
    </div>
  );
}
```

**Step 3: Rename BooleanSettings to DisplayOptions**

Rename the `BooleanSettings` function to `DisplayOptions`. Change the heading from no heading to:

```tsx
<h4 className="text-sm font-medium">{t('displayOptions')}</h4>
```

Wrap the existing content inside a parent div with the heading:

```tsx
function DisplayOptions({
  index,
  prefix,
}: {
  index: number;
  prefix: `playlists.${number}`;
}) {
  const { watch, setValue, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-3">
      <h4 className="text-sm font-medium">{t('displayOptions')}</h4>
      <div className="space-y-4">
        <div className="flex gap-6">
          {/* ... existing checkboxes unchanged ... */}
        </div>
        <div className="space-y-2">
          {/* ... existing yearHeaderMode selector unchanged ... */}
        </div>
      </div>
    </div>
  );
}
```

**Step 4: Update PlaylistForm render order**

Change the render order in the `PlaylistForm` return:

```tsx
return (
  <div className="space-y-4">
    <BasicSettings index={index} prefix={prefix} />
    <StructureSettings index={index} prefix={prefix} />

    <FilterSettings
      prefix={prefix}
      titleFilter={titleFilter}
      excludeFilter={excludeFilter}
      requireFilter={requireFilter}
      episodeTitles={episodeTitles}
    />

    <DisplayOptions index={index} prefix={prefix} />

    <SortForm index={index} />
    <GroupsForm index={index} />
    <ExtractorsForm index={index} />

    <RemoveButton onRemove={onRemove} />
  </div>
);
```

**Step 5: Add Controller import if not already present**

`Controller` is already imported from `react-hook-form` in the current `BooleanSettings`. Verify the import line includes `Controller`:

```tsx
import { Controller, useFormContext } from 'react-hook-form';
```

**Step 6: Verify the app compiles**

Run: `cd packages/sp_react && pnpm tsc --noEmit`
Expected: No type errors

**Step 7: Commit**

```bash
git add packages/sp_react/src/components/editor/playlist-form.tsx
git commit -m "feat: add StructureSettings section, rename BooleanSettings to DisplayOptions"
```

---

### Task 3: Strip GroupsForm down to group cards only

**Files:**
- Modify: `packages/sp_react/src/components/editor/groups-form.tsx`

**Step 1: Remove contentType, nullSeasonGroupKey, and CONTENT_TYPES from GroupsForm**

Remove:
- The `CONTENT_TYPES` constant
- The entire `contentType` `<div className="space-y-1.5">` block with the Controller/Select (roughly lines 59-88)
- The entire `nullSeasonGroupKey` conditional block (roughly lines 102-121)
- The `Controller` import (no longer needed)
- The `Select`, `SelectContent`, `SelectItem`, `SelectTrigger`, `SelectValue` imports (no longer needed)
- The `Input` import (no longer needed)
- The `register` and `watch` destructuring from `useFormContext` -- only keep `control` and `getValues` (and `watch` only if still needed for group displayNames in dialogItems)

Check: `watch` is still used at line 44 for `dialogItems` group displayName. Keep `watch` in the destructuring but remove `register`.

The resulting component should only contain:
- The `<h4>` heading
- The reorder button (when 1 < fields.length)
- The group cards list
- The "Add Group" button
- The GroupReorderDialog

**Step 2: Clean up unused imports**

Remove imports that are no longer used:
- `Controller` from react-hook-form
- `Select`, `SelectContent`, `SelectItem`, `SelectTrigger`, `SelectValue`
- `Input`

Keep:
- `useFormContext`, `useFieldArray` from react-hook-form
- `HintLabel` (check if still used -- it's not used after removing contentType/nullSeasonGroupKey labels, so remove it too)
- `GroupDefCard`, `GroupReorderDialog`
- `Button`
- `ArrowUpDown`, `Plus` from lucide-react

**Step 3: Verify the app compiles**

Run: `cd packages/sp_react && pnpm tsc --noEmit`
Expected: No type errors

**Step 4: Commit**

```bash
git add packages/sp_react/src/components/editor/groups-form.tsx
git commit -m "refactor: strip GroupsForm to group cards only"
```

---

### Task 4: Add "Display Overrides" sub-heading to GroupDefCard

**Files:**
- Modify: `packages/sp_react/src/components/editor/group-def-card.tsx`

**Step 1: Add sub-heading above checkboxes**

In `group-def-card.tsx`, add a `<h5>` heading just before the `<div className="flex gap-6">` that contains the episodeYearHeaders and showDateRange checkboxes (line 108):

```tsx
        <h5 className="text-xs font-medium text-muted-foreground">
          {t('displayOverrides')}
        </h5>

        <div className="flex gap-6">
          {/* ... existing checkboxes unchanged ... */}
        </div>
```

**Step 2: Verify the app compiles**

Run: `cd packages/sp_react && pnpm tsc --noEmit`
Expected: No type errors

**Step 3: Commit**

```bash
git add packages/sp_react/src/components/editor/group-def-card.tsx
git commit -m "feat: add Display Overrides sub-heading to group cards"
```

---

### Task 5: Visual verification and final commit

**Step 1: Run full type check**

Run: `cd packages/sp_react && pnpm tsc --noEmit`
Expected: No errors

**Step 2: Run existing tests**

Run: `cd packages/sp_react && pnpm test --run`
Expected: All tests pass

**Step 3: Run lint**

Run: `cd packages/sp_react && pnpm lint`
Expected: No errors

**Step 4: Manual verification checklist**

Start the dev server (`pnpm dev` in sp_react) and verify:
- [ ] "Basic Settings" section shows: id, displayName, priority (no resolverType)
- [ ] "Structure" section shows: resolverType, contentType, and nullSeasonGroupKey (when rss)
- [ ] "Filters" section unchanged
- [ ] "Display Options" section shows all checkboxes + yearHeaderMode
- [ ] "Sort" section unchanged
- [ ] "Groups" section shows only group cards (no contentType or nullSeasonGroupKey)
- [ ] Each group card shows "Display Overrides" sub-heading above its checkboxes
- [ ] Changing contentType in Structure section correctly toggles Sort section visibility
- [ ] Changing resolverType to 'rss' shows nullSeasonGroupKey in Structure section
