# Preview yearHeaderMode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the web editor's preview render year headers matching the mobile app's behavior for `firstEpisode` and `perEpisode` yearHeaderMode.

**Architecture:** The server already resolves `yearHeaderMode` onto `SmartPlaylist` during preview. We add `yearHeaderMode` to the server's JSON serialization, update the frontend Zod schema, then implement year-header grouping in `PlaylistTree`. The frontend reads `yearHeaderMode` from the form context (reactive to editor changes) and applies client-side year-grouping over the already-available `publishedAt` data on preview episodes. `firstEpisode` mode: each group appears once under the year of its first episode. `perEpisode` mode: each group is duplicated under every year it has episodes in, with year-filtered episode counts.

**Tech Stack:** Dart (sp_server), React 19, TypeScript, Zod, Vitest, @testing-library/react

---

## Task 1: Server -- serialize yearHeaderMode in preview response

**Files:**
- Modify: `packages/sp_server/lib/src/routes/config_routes.dart:647-669` (`_serializePlaylist`)
- Test: `packages/sp_server/test/routes/config_routes_test.dart`

**Step 1: Add yearHeaderMode to `_serializePlaylist`**

In `_serializePlaylist`, add the `yearHeaderMode` field after `episodeCount`:

```dart
Map<String, dynamic> _serializePlaylist(
  SmartPlaylist playlist,
  String? resolverType,
  Map<int, SimpleEpisodeData> episodeById, {
  Map<int, String>? extractedDisplayNames,
}) {
  return {
    'id': playlist.id,
    'displayName': playlist.displayName,
    'sortKey': playlist.sortKey,
    'resolverType': resolverType,
    'episodeCount': playlist.episodeCount,
    'yearHeaderMode': playlist.yearHeaderMode.name,
    if (playlist.groups != null)
      'groups': playlist.groups!
          .map(
            (g) => _serializeGroup(
              g,
              episodeById,
              extractedDisplayNames: extractedDisplayNames,
            ),
          )
          .toList(),
  };
}
```

**Step 2: Run server tests to verify nothing breaks**

Run: `cd packages/sp_server && dart test`
Expected: All existing tests pass. The new field is additive.

**Step 3: Add a test asserting yearHeaderMode appears in preview response**

In `config_routes_test.dart`, find the existing preview test that checks basic grouping results. Add an assertion that the playlist object in the response contains `yearHeaderMode`. Use an existing test fixture that sets `yearHeaderMode` on a definition, or add one:

```dart
test('preview response includes yearHeaderMode', () async {
  final config = {
    'schemaVersion': 1,
    'feedUrls': ['https://example.com/feed.xml'],
    'playlists': [
      {
        'id': 'p1',
        'displayName': 'Test',
        'resolverType': 'rss',
        'yearHeaderMode': 'perEpisode',
      },
    ],
  };
  // Use existing feed fixture or mock
  final response = await _postPreview(config, feedUrl: testFeedUrl);
  expect(response.statusCode, 200);
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final playlists = body['playlists'] as List;
  expect(playlists, isNotEmpty);
  final playlist = playlists.first as Map<String, dynamic>;
  expect(playlist['yearHeaderMode'], 'perEpisode');
});
```

Adapt the helper to match the test file's existing patterns (look for `_postPreview` or similar).

**Step 4: Run server tests**

Run: `cd packages/sp_server && dart test`
Expected: All tests pass including the new one.

**Step 5: Commit**

```
fix: include yearHeaderMode in preview API response
```

---

## Task 2: Frontend schema -- add yearHeaderMode to previewPlaylistSchema

**Files:**
- Modify: `packages/sp_react/src/schemas/api-schema.ts:68-77`
- Test: `packages/sp_react/src/schemas/__tests__/config-schema.test.ts` (or create `api-schema.test.ts` if it exists)

**Step 1: Add yearHeaderMode to `previewPlaylistSchema`**

In `api-schema.ts`, import `yearHeaderModeSchema` from config-schema and add the field:

```typescript
import { yearHeaderModeSchema } from './config-schema.ts';

// ... existing schemas ...

export const previewPlaylistSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  sortKey: z.union([z.string(), z.number()]),
  resolverType: z.string().nullish(),
  episodeCount: z.number(),
  yearHeaderMode: yearHeaderModeSchema.default('none'),
  groups: z.array(previewGroupSchema).optional(),
  claimedByOthers: z.array(claimedEpisodeSchema).optional().default([]),
  debug: playlistDebugSchema.optional(),
});
```

Using `.default('none')` means existing preview responses without the field (backwards compat) default to `none`.

**Step 2: Run frontend tests**

Run: `cd packages/sp_react && pnpm test`
Expected: All existing tests pass. The new field has a default so existing test data is unaffected.

**Step 3: Commit**

```
feat: add yearHeaderMode to preview playlist schema
```

---

## Task 3: Frontend -- year-header grouping logic (pure function + tests)

**Files:**
- Create: `packages/sp_react/src/components/preview/year-group-utils.ts`
- Create: `packages/sp_react/src/components/preview/__tests__/year-group-utils.test.ts`

**Step 1: Write the failing tests**

Create the test file with cases for both modes:

```typescript
import { describe, it, expect } from 'vitest';
import type { PreviewGroup, PreviewEpisode } from '@/schemas/api-schema.ts';
import type { YearHeaderMode } from '@/schemas/config-schema.ts';
import { groupByYear } from '../year-group-utils.ts';

function makeEpisode(overrides: Partial<PreviewEpisode> & { id: number }): PreviewEpisode {
  return {
    title: `Episode ${overrides.id}`,
    publishedAt: null,
    seasonNumber: null,
    episodeNumber: null,
    extractedDisplayName: null,
    ...overrides,
  };
}

function makeGroup(id: string, episodes: PreviewEpisode[]): PreviewGroup {
  return {
    id,
    displayName: id,
    sortKey: 0,
    episodeCount: episodes.length,
    episodes,
  };
}

describe('groupByYear', () => {
  const ep2024a = makeEpisode({ id: 1, publishedAt: '2024-03-01T00:00:00Z' });
  const ep2024b = makeEpisode({ id: 2, publishedAt: '2024-08-15T00:00:00Z' });
  const ep2025a = makeEpisode({ id: 3, publishedAt: '2025-01-10T00:00:00Z' });
  const ep2025b = makeEpisode({ id: 4, publishedAt: '2025-06-20T00:00:00Z' });

  describe('none mode', () => {
    it('returns null', () => {
      const groups = [makeGroup('g1', [ep2024a, ep2025a])];
      expect(groupByYear(groups, 'none')).toBeNull();
    });
  });

  describe('firstEpisode mode', () => {
    it('places group under year of its first episode', () => {
      const groups = [
        makeGroup('g1', [ep2024a, ep2024b, ep2025a]),
        makeGroup('g2', [ep2025a, ep2025b]),
      ];
      const result = groupByYear(groups, 'firstEpisode')!;
      const years = result.map((y) => y.year);
      expect(years).toEqual([2025, 2024]);

      const y2024 = result.find((y) => y.year === 2024)!;
      expect(y2024.entries).toHaveLength(1);
      expect(y2024.entries[0].group.id).toBe('g1');
      expect(y2024.entries[0].episodeCount).toBe(3);

      const y2025 = result.find((y) => y.year === 2025)!;
      expect(y2025.entries).toHaveLength(1);
      expect(y2025.entries[0].group.id).toBe('g2');
    });

    it('uses year 0 for episodes without publishedAt', () => {
      const epNoDate = makeEpisode({ id: 10, publishedAt: null });
      const groups = [makeGroup('g1', [epNoDate])];
      const result = groupByYear(groups, 'firstEpisode')!;
      expect(result).toHaveLength(1);
      expect(result[0].year).toBe(0);
    });
  });

  describe('perEpisode mode', () => {
    it('duplicates group across years with filtered counts', () => {
      const groups = [
        makeGroup('g1', [ep2024a, ep2024b, ep2025a]),
      ];
      const result = groupByYear(groups, 'perEpisode')!;
      const years = result.map((y) => y.year);
      expect(years).toEqual([2025, 2024]);

      const y2024 = result.find((y) => y.year === 2024)!;
      expect(y2024.entries).toHaveLength(1);
      expect(y2024.entries[0].group.id).toBe('g1');
      expect(y2024.entries[0].episodeCount).toBe(2);

      const y2025 = result.find((y) => y.year === 2025)!;
      expect(y2025.entries).toHaveLength(1);
      expect(y2025.entries[0].group.id).toBe('g1');
      expect(y2025.entries[0].episodeCount).toBe(1);
    });

    it('handles multiple groups across overlapping years', () => {
      const groups = [
        makeGroup('g1', [ep2024a, ep2025a]),
        makeGroup('g2', [ep2025a, ep2025b]),
      ];
      const result = groupByYear(groups, 'perEpisode')!;

      const y2025 = result.find((y) => y.year === 2025)!;
      expect(y2025.entries).toHaveLength(2);

      const y2024 = result.find((y) => y.year === 2024)!;
      expect(y2024.entries).toHaveLength(1);
      expect(y2024.entries[0].group.id).toBe('g1');
    });
  });

  it('sorts years descending', () => {
    const groups = [
      makeGroup('g1', [ep2024a]),
      makeGroup('g2', [ep2025a]),
    ];
    const result = groupByYear(groups, 'firstEpisode')!;
    expect(result[0].year).toBe(2025);
    expect(result[1].year).toBe(2024);
  });
});
```

**Step 2: Run tests to verify they fail**

Run: `cd packages/sp_react && pnpm vitest run src/components/preview/__tests__/year-group-utils.test.ts`
Expected: FAIL -- module not found.

**Step 3: Implement `groupByYear`**

Create `year-group-utils.ts`:

```typescript
import type { PreviewGroup } from '@/schemas/api-schema.ts';
import type { YearHeaderMode } from '@/schemas/config-schema.ts';

export interface YearGroupEntry {
  group: PreviewGroup;
  episodeCount: number;
}

export interface YearSection {
  year: number;
  entries: YearGroupEntry[];
}

function getEpisodeYear(publishedAt: string | null | undefined): number {
  if (!publishedAt) return 0;
  return new Date(publishedAt).getFullYear();
}

function groupByFirstEpisode(groups: PreviewGroup[]): YearSection[] {
  const byYear = new Map<number, YearGroupEntry[]>();

  for (const group of groups) {
    const year = getEpisodeYear(group.episodes[0]?.publishedAt);
    const entries = byYear.get(year) ?? [];
    entries.push({ group, episodeCount: group.episodeCount });
    byYear.set(year, entries);
  }

  return [...byYear.entries()]
    .sort((a, b) => b[0] - a[0])
    .map(([year, entries]) => ({ year, entries }));
}

function groupByPerEpisode(groups: PreviewGroup[]): YearSection[] {
  const byYear = new Map<number, YearGroupEntry[]>();

  for (const group of groups) {
    const yearCounts = new Map<number, number>();
    for (const ep of group.episodes) {
      const year = getEpisodeYear(ep.publishedAt);
      yearCounts.set(year, (yearCounts.get(year) ?? 0) + 1);
    }

    for (const [year, count] of yearCounts) {
      const entries = byYear.get(year) ?? [];
      entries.push({ group, episodeCount: count });
      byYear.set(year, entries);
    }
  }

  return [...byYear.entries()]
    .sort((a, b) => b[0] - a[0])
    .map(([year, entries]) => ({ year, entries }));
}

export function groupByYear(
  groups: PreviewGroup[],
  mode: YearHeaderMode,
): YearSection[] | null {
  if (mode === 'none') return null;
  if (mode === 'firstEpisode') return groupByFirstEpisode(groups);
  return groupByPerEpisode(groups);
}
```

**Step 4: Run tests to verify they pass**

Run: `cd packages/sp_react && pnpm vitest run src/components/preview/__tests__/year-group-utils.test.ts`
Expected: All pass.

**Step 5: Commit**

```
feat: add year-grouping utility for preview yearHeaderMode
```

---

## Task 4: Frontend -- render year headers in PlaylistTree

**Files:**
- Modify: `packages/sp_react/src/components/preview/playlist-tree.tsx`
- Modify: `packages/sp_react/src/components/editor/playlist-tab-content.tsx`
- Modify: `packages/sp_react/src/locales/en/preview.json`
- Modify: `packages/sp_react/src/locales/ja/preview.json`

**Step 1: Add locale keys**

In `packages/sp_react/src/locales/en/preview.json`, add:

```json
"yearHeader": "{{year}}",
"yearUnknown": "Unknown Year",
"groupCount": "{{count}} groups"
```

In `packages/sp_react/src/locales/ja/preview.json`, add:

```json
"yearHeader": "{{year}}",
"yearUnknown": "年不明",
"groupCount": "{{count}} グループ"
```

**Step 2: Update PlaylistTree to accept and render yearHeaderMode**

Replace `playlist-tree.tsx` with:

```tsx
import { useTranslation } from 'react-i18next';
import type {
  PreviewPlaylist,
  PreviewGroup,
  PreviewEpisode,
} from '@/schemas/api-schema.ts';
import type { YearHeaderMode } from '@/schemas/config-schema.ts';
import {
  Accordion,
  AccordionItem,
  AccordionTrigger,
  AccordionContent,
} from '@/components/ui/accordion.tsx';
import { Badge } from '@/components/ui/badge.tsx';
import { groupByYear } from '@/components/preview/year-group-utils.ts';
import type { YearGroupEntry } from '@/components/preview/year-group-utils.ts';

interface PlaylistTreeProps {
  playlists: PreviewPlaylist[];
  showSeasonNumber?: boolean;
  yearHeaderMode?: YearHeaderMode;
}

export function PlaylistTree({
  playlists,
  showSeasonNumber = false,
  yearHeaderMode = 'none',
}: PlaylistTreeProps) {
  const { t } = useTranslation('preview');

  return (
    <div className="w-full space-y-4">
      {playlists.map((playlist) => (
        <div key={playlist.id}>
          {playlist.groups && 0 < playlist.groups.length ? (
            <YearAwareGroupList
              groups={playlist.groups}
              showSeasonNumber={showSeasonNumber}
              yearHeaderMode={yearHeaderMode}
            />
          ) : (
            <p className="text-sm text-muted-foreground py-2">{t('noGroups')}</p>
          )}
        </div>
      ))}
    </div>
  );
}

function YearAwareGroupList({
  groups,
  showSeasonNumber,
  yearHeaderMode,
}: {
  groups: PreviewGroup[];
  showSeasonNumber: boolean;
  yearHeaderMode: YearHeaderMode;
}) {
  const yearSections = groupByYear(groups, yearHeaderMode);

  if (!yearSections) {
    return <GroupList groups={groups} showSeasonNumber={showSeasonNumber} />;
  }

  return (
    <div className="space-y-4">
      {yearSections.map((section) => (
        <YearSection
          key={section.year}
          year={section.year}
          entries={section.entries}
          showSeasonNumber={showSeasonNumber}
        />
      ))}
    </div>
  );
}

function YearSection({
  year,
  entries,
  showSeasonNumber,
}: {
  year: number;
  entries: YearGroupEntry[];
  showSeasonNumber: boolean;
}) {
  const { t } = useTranslation('preview');

  return (
    <div>
      <div className="sticky top-0 z-10 bg-muted/80 backdrop-blur-sm px-2 py-1.5 -mx-2 border-b">
        <span className="text-sm font-semibold">
          {year === 0 ? t('yearUnknown') : t('yearHeader', { year })}
        </span>
      </div>
      <YearGroupEntryList entries={entries} showSeasonNumber={showSeasonNumber} />
    </div>
  );
}

function YearGroupEntryList({
  entries,
  showSeasonNumber,
}: {
  entries: YearGroupEntry[];
  showSeasonNumber: boolean;
}) {
  const { t } = useTranslation('preview');

  return (
    <Accordion type="multiple" className="ml-4">
      {entries.map((entry, idx) => (
        <AccordionItem key={`${entry.group.id}-${idx}`} value={`${entry.group.id}-${idx}`}>
          <AccordionTrigger>
            <div className="flex items-center gap-2">
              <span>{formatGroupName(entry.group, showSeasonNumber)}</span>
              <Badge variant="secondary">
                {t('episodes', { count: entry.episodeCount })}
              </Badge>
            </div>
          </AccordionTrigger>
          <AccordionContent>
            <EpisodeList episodes={entry.group.episodes} />
          </AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}

function formatGroupName(group: PreviewGroup, showSeasonNumber: boolean): string {
  if (showSeasonNumber && typeof group.sortKey === 'number' && group.id.startsWith('season_')) {
    return `S${group.sortKey} ${group.displayName}`;
  }
  return group.displayName;
}

function GroupList({ groups, showSeasonNumber }: { groups: PreviewGroup[]; showSeasonNumber: boolean }) {
  const { t } = useTranslation('preview');

  return (
    <Accordion type="multiple" className="ml-4">
      {groups.map((group) => (
        <AccordionItem key={group.id} value={group.id}>
          <AccordionTrigger>
            <div className="flex items-center gap-2">
              <span>{formatGroupName(group, showSeasonNumber)}</span>
              <Badge variant="secondary">
                {t('episodes', { count: group.episodeCount })}
              </Badge>
            </div>
          </AccordionTrigger>
          <AccordionContent>
            <EpisodeList episodes={group.episodes} />
          </AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}

function EpisodeList({ episodes }: { episodes: PreviewEpisode[] }) {
  return (
    <ul className="ml-4 space-y-0.5 text-sm text-muted-foreground">
      {episodes.map((ep) => (
        <li key={ep.id} className="flex items-center gap-2">
          <span className="truncate">{ep.title}</span>
          {ep.publishedAt && (
            <span className="text-xs text-muted-foreground/60 shrink-0">
              {new Date(ep.publishedAt).toLocaleDateString()}
            </span>
          )}
        </li>
      ))}
    </ul>
  );
}
```

**Step 3: Update `playlist-tab-content.tsx` to pass yearHeaderMode**

Read `yearHeaderMode` from the form context and pass it to `PlaylistTree`:

```tsx
// Add to existing watch calls (around line 45):
const yearHeaderMode = watch(`playlists.${index}.yearHeaderMode`) ?? 'none';

// Update the PlaylistTree call (around line 111):
<PlaylistTree
  playlists={[previewPlaylist]}
  showSeasonNumber={showSeasonNumber}
  yearHeaderMode={yearHeaderMode}
/>
```

**Step 4: Run all frontend tests**

Run: `cd packages/sp_react && pnpm test`
Expected: All pass.

**Step 5: Run the dev server and visually verify**

Run: `cd packages/sp_react && pnpm dev`

Open a pattern with `yearHeaderMode: perEpisode` or `firstEpisode`, run preview, and verify:
- `none`: flat group list (unchanged behavior)
- `firstEpisode`: groups under year headers, each group appears once
- `perEpisode`: groups duplicated under each year they have episodes in, with year-filtered counts

**Step 6: Commit**

```
feat: render year headers in preview for yearHeaderMode
```

---

## Task 5: Verification and cleanup

**Step 1: Run full test suite**

```bash
cd packages/sp_shared && dart test && dart analyze
cd packages/sp_server && dart test && dart analyze
cd packages/sp_react && pnpm test && pnpm build
```

Expected: All pass, zero warnings.

**Step 2: Create bookmark**

```bash
jj bookmark create feat/preview-year-header-mode
```
