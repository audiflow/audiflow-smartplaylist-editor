# Advanced Settings Forms Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the JSON-only advanced settings with form-based editing for Groups, Sort, and Extractors, with enriched preview data in a side-by-side layout.

**Architecture:** Extend the server preview endpoint to return enriched episode fields (`publishedAt`, `seasonNumber`, `episodeNumber`, `extractedDisplayName`). Build three new form sections (Groups, Sort, Extractors) using RHF `useFormContext` + `useFieldArray`. Restructure the per-playlist tab to a side-by-side layout (forms left, enriched preview right).

**Tech Stack:** Dart (sp_server, sp_shared), React 19 + TypeScript + TanStack + RHF + Zod + shadcn/ui (sp_react), Vitest for frontend tests, `dart test` for backend tests.

**Design doc:** `docs/plans/2026-02-20-advanced-settings-forms-design.md`

**Critical rules:**
- NEVER use `>` or `>=` operators - use `<` or `<=` instead
- No emojis in code/docs
- Hand-written JSON serialization (no code generation)
- `final class` for models
- Post-implementation: format, analyze, test, jj bookmark

---

## Task 1: Enrich preview episode serialization (server)

Extend `_serializeEpisode` to include `publishedAt`, `seasonNumber`, `episodeNumber`, and add `extractedDisplayName` computation.

**Files:**
- Modify: `packages/sp_server/lib/src/routes/config_routes.dart:474-477` (`_serializeEpisode`)
- Modify: `packages/sp_server/lib/src/routes/config_routes.dart:347-405` (`_runPreview`)
- Modify: `packages/sp_server/lib/src/routes/config_routes.dart:458-472` (`_serializeGroup`)
- Test: `packages/sp_server/test/routes/config_routes_test.dart`

### Step 1: Write failing tests for enriched episode fields

Add tests to the existing `POST /api/configs/preview` group in `config_routes_test.dart`. Insert after the existing "returns grouping results" test (around line 770).

```dart
test('includes enriched episode fields in group episodes', () async {
  final config = {
    'id': 'test-pattern',
    'feedUrls': ['https://example.com/feed'],
    'playlists': [
      {
        'id': 'seasons',
        'displayName': 'Seasons',
        'resolverType': 'rss',
      },
    ],
  };

  final response = await makePreviewRequest(config, 'https://example.com/feed');
  expect(response.statusCode, equals(200));

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final playlists = body['playlists'] as List;
  expect(playlists, isNotEmpty);

  final groups = playlists[0]['groups'] as List;
  expect(groups, isNotEmpty);

  final episodes = groups[0]['episodes'] as List;
  expect(episodes, isNotEmpty);

  final episode = episodes[0] as Map<String, dynamic>;
  // Must include enriched fields
  expect(episode, contains('publishedAt'));
  expect(episode, contains('seasonNumber'));
  expect(episode, contains('episodeNumber'));
  // id and title still present
  expect(episode, contains('id'));
  expect(episode, contains('title'));
});
```

Also add a test for `extractedDisplayName`:

```dart
test('includes extractedDisplayName when titleExtractor is set', () async {
  final config = {
    'id': 'test-pattern',
    'feedUrls': ['https://example.com/feed'],
    'playlists': [
      {
        'id': 'seasons',
        'displayName': 'Seasons',
        'resolverType': 'rss',
        'titleExtractor': {
          'source': 'title',
          'pattern': r'^S\d+E\d+\s*-?\s*(.*)',
          'group': 1,
        },
      },
    ],
  };

  final response = await makePreviewRequest(config, 'https://example.com/feed');
  expect(response.statusCode, equals(200));

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final playlists = body['playlists'] as List;
  final groups = playlists[0]['groups'] as List;
  final episodes = groups[0]['episodes'] as List;
  final episode = episodes[0] as Map<String, dynamic>;

  expect(episode, contains('extractedDisplayName'));
});
```

Note: you may need to adjust the test RSS fixture (`_sampleRss`) to have episode titles that match the extractor pattern like `S01E01 - Rome`. Check the existing fixture first and adapt accordingly.

### Step 2: Run tests to verify they fail

```bash
dart test packages/sp_server/test/routes/config_routes_test.dart --name "includes enriched"
```

Expected: FAIL - episodes only have `id` and `title`.

### Step 3: Implement enriched serialization

**3a. Update `_serializeEpisode` (line 474):**

Change from:
```dart
Map<String, dynamic>? _serializeEpisode(SimpleEpisodeData? episode) {
  if (episode == null) return null;
  return {'id': episode.id, 'title': episode.title};
}
```

To:
```dart
Map<String, dynamic>? _serializeEpisode(
  SimpleEpisodeData? episode, {
  String? extractedDisplayName,
}) {
  if (episode == null) return null;
  return {
    'id': episode.id,
    'title': episode.title,
    if (episode.publishedAt != null)
      'publishedAt': episode.publishedAt!.toIso8601String(),
    if (episode.seasonNumber != null) 'seasonNumber': episode.seasonNumber,
    if (episode.episodeNumber != null) 'episodeNumber': episode.episodeNumber,
    if (extractedDisplayName != null)
      'extractedDisplayName': extractedDisplayName,
  };
}
```

**3b. Update `_serializeGroup` (line 458) to pass through a display name map:**

```dart
Map<String, dynamic> _serializeGroup(
  SmartPlaylistGroup group,
  Map<int, SimpleEpisodeData> episodeById, {
  Map<int, String>? extractedDisplayNames,
}) {
  return {
    'id': group.id,
    'displayName': group.displayName,
    'sortKey': group.sortKey,
    'episodeCount': group.episodeCount,
    'episodes': group.episodeIds
        .map((id) => _serializeEpisode(
              episodeById[id],
              extractedDisplayName: extractedDisplayNames?[id],
            ))
        .whereType<Map<String, dynamic>>()
        .toList(),
  };
}
```

**3c. Update `_serializePlaylist` (line 407) to forward the map:**

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
    if (playlist.groups != null)
      'groups': playlist.groups!
          .map((g) => _serializeGroup(
                g,
                episodeById,
                extractedDisplayNames: extractedDisplayNames,
              ))
          .toList(),
  };
}
```

**3d. Update `_serializePreviewResult` (line 425) to forward the map:**

```dart
Map<String, dynamic> _serializePreviewResult(
  PlaylistPreviewResult pr,
  String? resolverType,
  Map<int, SimpleEpisodeData> episodeById, {
  Map<int, String>? extractedDisplayNames,
}) {
  final base = _serializePlaylist(
    pr.playlist,
    resolverType,
    episodeById,
    extractedDisplayNames: extractedDisplayNames,
  );
  // ... rest of claimedByOthers and debug serialization unchanged
```

**3e. Compute `extractedDisplayNames` in `_runPreview` (line 347):**

Add after the `episodeById` map construction (around line 385):

```dart
// Compute extracted display names per episode using each definition's titleExtractor
final extractedDisplayNames = <String, Map<int, String>>{};
for (final definition in config.playlists) {
  final extractor = definition.titleExtractor;
  if (extractor == null) continue;
  final names = <int, String>{};
  for (final episode in enriched) {
    final name = extractor.extract(episode);
    if (name != null) {
      names[episode.id] = name;
    }
  }
  extractedDisplayNames[definition.id] = names;
}
```

Then update the `playlists` serialization to pass the per-definition map:

```dart
'playlists': result.playlistResults
    .map(
      (pr) => _serializePreviewResult(
        pr,
        result.resolverType,
        episodeById,
        extractedDisplayNames: extractedDisplayNames[pr.definitionId],
      ),
    )
    .toList(),
```

And update ungrouped serialization:
```dart
'ungrouped': result.ungroupedEpisodeIds
    .map((id) => _serializeEpisode(episodeById[id]))
    .whereType<Map<String, dynamic>>()
    .toList(),
```

### Step 4: Run tests to verify they pass

```bash
dart test packages/sp_server/test/routes/config_routes_test.dart --name "preview"
```

Expected: ALL preview tests pass (including existing ones).

### Step 5: Run full test suite

```bash
dart test packages/sp_server
```

Expected: All 208+ tests pass.

### Step 6: Format and analyze

```bash
dart format packages/sp_server/lib/src/routes/config_routes.dart packages/sp_server/test/routes/config_routes_test.dart
dart analyze packages/sp_server
```

### Step 7: Commit

```bash
jj bookmark create feat/advanced-settings-forms
```

```
feat: enrich preview episode serialization with publishedAt, seasonNumber, episodeNumber, extractedDisplayName
```

---

## Task 2: Update frontend types and PreviewEpisode schema

Update the Zod API schema and TypeScript types to match the enriched server response.

**Files:**
- Modify: `packages/sp_react/src/schemas/api-schema.ts:37-42` (PreviewEpisode schema)
- Test: `packages/sp_react/src/schemas/__tests__/api-schema.test.ts` (create)

### Step 1: Write failing test

Create `packages/sp_react/src/schemas/__tests__/api-schema.test.ts`:

```typescript
import { describe, it, expect } from 'vitest';
import { previewEpisodeSchema } from '../api-schema.ts';

describe('previewEpisodeSchema', () => {
  it('parses enriched episode with all fields', () => {
    const input = {
      id: 1,
      title: 'S01E03 - Rome',
      publishedAt: '2024-01-15T00:00:00Z',
      seasonNumber: 1,
      episodeNumber: 3,
      extractedDisplayName: 'Rome',
    };
    const result = previewEpisodeSchema.parse(input);
    expect(result.publishedAt).toBe('2024-01-15T00:00:00Z');
    expect(result.seasonNumber).toBe(1);
    expect(result.episodeNumber).toBe(3);
    expect(result.extractedDisplayName).toBe('Rome');
  });

  it('parses minimal episode without optional fields', () => {
    const input = { id: 1, title: 'Episode 1' };
    const result = previewEpisodeSchema.parse(input);
    expect(result.publishedAt).toBeUndefined();
    expect(result.extractedDisplayName).toBeUndefined();
  });
});
```

### Step 2: Run test to verify it fails

```bash
cd packages/sp_react && pnpm test -- --run --reporter verbose src/schemas/__tests__/api-schema.test.ts
```

Expected: FAIL - `previewEpisodeSchema` doesn't export or doesn't have the new fields.

### Step 3: Update the schema

In `packages/sp_react/src/schemas/api-schema.ts`, find the `previewEpisodeSchema` (around line 37) and add:

```typescript
export const previewEpisodeSchema = z.object({
  id: z.number(),
  title: z.string(),
  publishedAt: z.string().nullish(),
  seasonNumber: z.number().nullish(),
  episodeNumber: z.number().nullish(),
  extractedDisplayName: z.string().nullish(),
});
```

Make sure it's exported (add `export` if not already).

### Step 4: Run test to verify it passes

```bash
cd packages/sp_react && pnpm test -- --run --reporter verbose src/schemas/__tests__/api-schema.test.ts
```

Expected: PASS.

### Step 5: Run full frontend test suite

```bash
cd packages/sp_react && pnpm test -- --run
```

Expected: All 70+ tests pass.

### Step 6: Commit

```
feat: add enriched fields to PreviewEpisode schema (publishedAt, seasonNumber, episodeNumber, extractedDisplayName)
```

---

## Task 3: Add i18n strings for all new form fields

Add translation keys and hint texts for Groups, Sort, Extractors, and yearHeaderMode in both EN and JA.

**Files:**
- Modify: `packages/sp_react/src/locales/en/editor.json`
- Modify: `packages/sp_react/src/locales/ja/editor.json`
- Modify: `packages/sp_react/src/locales/en/hints.json`
- Modify: `packages/sp_react/src/locales/ja/hints.json`
- Modify: `packages/sp_react/src/locales/en/preview.json`
- Modify: `packages/sp_react/src/locales/ja/preview.json`

### Step 1: Add editor.json keys (EN)

Add to `packages/sp_react/src/locales/en/editor.json`:

```json
{
  "groupsSection": "Groups",
  "sortSection": "Sort",
  "extractorsSection": "Extractors",
  "contentType": "Content Type",
  "nullSeasonGroupKey": "Null Season Group Key",
  "addGroup": "Add Group",
  "removeGroup": "Remove",
  "groupId": "Group ID",
  "groupDisplayName": "Display Name",
  "groupPattern": "Pattern (regex)",
  "sortType": "Sort Type",
  "sortSimple": "Simple",
  "sortComposite": "Composite",
  "sortField": "Field",
  "sortOrder": "Order",
  "sortField_playlistNumber": "Playlist Number",
  "sortField_newestEpisodeDate": "Newest Episode Date",
  "sortField_progress": "Progress",
  "sortField_alphabetical": "Alphabetical",
  "sortOrder_ascending": "Ascending",
  "sortOrder_descending": "Descending",
  "sortConditional": "Conditional",
  "sortConditionValue": "When sortKey >",
  "addSortRule": "Add Rule",
  "removeSortRule": "Remove",
  "titleExtractor": "Title Extractor",
  "titleExtractorSource": "Source",
  "titleExtractorPattern": "Pattern (regex)",
  "titleExtractorGroup": "Capture Group",
  "titleExtractorTemplate": "Template",
  "titleExtractorFallbackValue": "Fallback Value",
  "addFallback": "Add Fallback",
  "removeFallbackStep": "Remove",
  "fallbackStep": "Fallback {{number}}",
  "episodeNumberExtractor": "Episode Number Extractor",
  "episodeNumberPattern": "Pattern (regex)",
  "episodeNumberCaptureGroup": "Capture Group",
  "episodeNumberFallbackToRss": "Fallback to RSS",
  "episodeExtractor": "Episode Extractor",
  "episodeExtractorSource": "Source",
  "episodeExtractorPattern": "Pattern (regex)",
  "episodeExtractorSeasonGroup": "Season Capture Group",
  "episodeExtractorEpisodeGroup": "Episode Capture Group",
  "episodeExtractorFallbackSeason": "Fallback Season Number",
  "episodeExtractorFallbackPattern": "Fallback Episode Pattern",
  "episodeExtractorFallbackCaptureGroup": "Fallback Capture Group",
  "yearHeaderMode": "Year Header Mode",
  "yearHeaderMode_none": "None",
  "yearHeaderMode_firstEpisode": "First Episode",
  "yearHeaderMode_perEpisode": "Per Episode",
  "source_title": "Title",
  "source_description": "Description",
  "source_seasonNumber": "Season Number",
  "source_episodeNumber": "Episode Number",
  "contentType_episodes": "Episodes",
  "contentType_groups": "Groups"
}
```

### Step 2: Add editor.json keys (JA)

Add the Japanese equivalents to `packages/sp_react/src/locales/ja/editor.json`.

### Step 3: Add hints.json keys (EN)

Add to `packages/sp_react/src/locales/en/hints.json`:

```json
{
  "contentType": "Controls the output shape. 'episodes' creates flat playlists; 'groups' creates nested group structures within each playlist.",
  "nullSeasonGroupKey": "Routes episodes with null or zero season numbers into this group key. For example, set to 999 to collect special episodes in a 'Season 999' group.",
  "groupId": "Unique identifier for this group within the playlist. Used as the internal key.",
  "groupDisplayName": "The name shown to users for this group in the app.",
  "groupPattern": "A regex matched against episode titles. Episodes matching this pattern are assigned to this group. Leave empty to create a catch-all group for unmatched episodes.",
  "customSort": "Override the default sort order for playlists. Simple mode sorts by one field; composite mode allows multi-level sort rules with conditions.",
  "sortField": "The field to sort playlists by. 'playlistNumber' uses the group key, 'newestEpisodeDate' uses the latest episode date, 'progress' uses listening progress, 'alphabetical' sorts by display name.",
  "sortOrder": "Ascending (A-Z, oldest first, lowest number first) or descending (Z-A, newest first, highest number first).",
  "sortCondition": "When enabled, this sort rule only applies to playlists whose sortKey exceeds the given threshold value.",
  "titleExtractor": "Extracts a display name from episode data for use as group/playlist titles. Supports regex capture groups, templates, and recursive fallback chains.",
  "titleExtractorSource": "The episode field to extract from: title, description, seasonNumber, or episodeNumber.",
  "titleExtractorPattern": "A regex applied to the source value. Use capture groups to extract portions of the text.",
  "titleExtractorGroup": "Which regex capture group to use (0 = full match, 1 = first group, etc.).",
  "titleExtractorTemplate": "A template string with {value} placeholder. For example, 'Season {value}' turns '1' into 'Season 1'.",
  "titleExtractorFallbackValue": "A static string returned when all extraction steps fail and the episode has no season number.",
  "episodeNumberExtractor": "Extracts episode numbers from titles using regex. Falls back to RSS metadata when the pattern doesn't match.",
  "episodeNumberPattern": "A regex with a capture group that extracts the episode number from the title.",
  "episodeNumberCaptureGroup": "Which capture group contains the episode number (default: 1).",
  "episodeNumberFallbackToRss": "When the regex doesn't match, use the episode number from RSS metadata instead.",
  "episodeExtractor": "Extracts both season and episode numbers from a single title pattern. Used for podcasts that encode both in the title (e.g., '[S2E15] Title').",
  "episodeExtractorSource": "The episode field to extract from: title or description.",
  "episodeExtractorPattern": "A regex with capture groups for both season and episode numbers.",
  "episodeExtractorSeasonGroup": "Which capture group contains the season number (default: 1).",
  "episodeExtractorEpisodeGroup": "Which capture group contains the episode number (default: 2).",
  "episodeExtractorFallbackSeason": "Season number to assign when only the fallback pattern matches (e.g., 0 for special episodes).",
  "episodeExtractorFallbackPattern": "A secondary regex tried when the primary pattern doesn't match. Used for catching special/bonus episodes.",
  "episodeExtractorFallbackCaptureGroup": "Which capture group in the fallback pattern contains the episode number (default: 1).",
  "yearHeaderMode": "Controls year header display within this playlist. 'none' disables headers, 'firstEpisode' shows the year of the first episode, 'perEpisode' shows year headers throughout."
}
```

### Step 4: Add hints.json keys (JA)

Add the Japanese equivalents to `packages/sp_react/src/locales/ja/hints.json`.

### Step 5: Add preview.json keys (EN)

Add to `packages/sp_react/src/locales/en/preview.json`:

```json
{
  "sortOrder": "Sort Order",
  "extractionResults": "Extraction Results",
  "extractedName": "Display Name",
  "season": "Season",
  "episode": "Episode"
}
```

### Step 6: Add preview.json keys (JA)

Add Japanese equivalents to `packages/sp_react/src/locales/ja/preview.json`.

### Step 7: Commit

```
feat: add i18n strings for advanced settings forms (EN + JA)
```

---

## Task 4: Add yearHeaderMode to BooleanSettings

Add a `yearHeaderMode` select field to the existing BooleanSettings section in `playlist-form.tsx`.

**Files:**
- Modify: `packages/sp_react/src/components/editor/playlist-form.tsx:188-224` (BooleanSettings)
- Test: `packages/sp_react/src/components/editor/__tests__/playlist-form.test.tsx` (create)

### Step 1: Write a focused test

Create `packages/sp_react/src/components/editor/__tests__/boolean-settings.test.tsx`:

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { FormProvider, useForm } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';

// A minimal wrapper that provides RHF context
function Wrapper({ children }: { children: React.ReactNode }) {
  const form = useForm<PatternConfig>({
    defaultValues: {
      id: 'test',
      playlists: [{
        id: 'p1',
        displayName: 'Test',
        resolverType: 'rss',
        priority: 0,
        episodeYearHeaders: false,
        showDateRange: false,
      }],
    },
  });
  return <FormProvider {...form}>{children}</FormProvider>;
}

// Import the BooleanSettings component after extracting it
// This test verifies the yearHeaderMode select exists

describe('BooleanSettings', () => {
  it('renders yearHeaderMode select', async () => {
    // Render the BooleanSettings component within the form provider
    // and verify the yearHeaderMode select is present
    // Implementation will depend on exact component extraction
  });
});
```

Note: The exact test shape depends on whether BooleanSettings is extracted as its own exported component or stays internal. Adapt as needed.

### Step 2: Implement yearHeaderMode in BooleanSettings

In `playlist-form.tsx`, find the `BooleanSettings` component (around line 188). Add after the existing checkboxes:

```tsx
// Inside BooleanSettings, after the showDateRange checkbox
<div className="space-y-2">
  <HintLabel htmlFor={`${prefix}.yearHeaderMode`} hint="yearHeaderMode">
    {t('yearHeaderMode')}
  </HintLabel>
  <Controller
    name={`${prefix}.yearHeaderMode`}
    control={control}
    render={({ field }) => (
      <Select
        value={field.value ?? 'none'}
        onValueChange={(v) => field.onChange(v === 'none' ? null : v)}
      >
        <SelectTrigger>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="none">{t('yearHeaderMode_none')}</SelectItem>
          <SelectItem value="firstEpisode">{t('yearHeaderMode_firstEpisode')}</SelectItem>
          <SelectItem value="perEpisode">{t('yearHeaderMode_perEpisode')}</SelectItem>
        </SelectContent>
      </Select>
    )}
  />
</div>
```

Add `Controller` to the react-hook-form imports at the top of the file.

### Step 3: Run tests

```bash
cd packages/sp_react && pnpm test -- --run
```

Expected: All tests pass.

### Step 4: Commit

```
feat: add yearHeaderMode select to BooleanSettings
```

---

## Task 5: Build GroupsForm component

Create the Groups form section with contentType select, nullSeasonGroupKey input, and dynamic group definition list.

**Files:**
- Create: `packages/sp_react/src/components/editor/groups-form.tsx`
- Create: `packages/sp_react/src/components/editor/group-def-card.tsx`
- Create: `packages/sp_react/src/components/editor/__tests__/groups-form.test.tsx`

### Step 1: Write failing tests

Create `packages/sp_react/src/components/editor/__tests__/groups-form.test.tsx`:

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { FormProvider, useForm } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { GroupsForm } from '../groups-form.tsx';

// Provide i18n mock or use the test i18n setup
// Provide RHF wrapper

function TestWrapper({ children, defaultValues }: {
  children: React.ReactNode;
  defaultValues?: Partial<PatternConfig['playlists'][0]>;
}) {
  const form = useForm<PatternConfig>({
    defaultValues: {
      id: 'test',
      playlists: [{
        id: 'p1',
        displayName: 'Test',
        resolverType: 'category',
        priority: 0,
        episodeYearHeaders: false,
        showDateRange: false,
        groups: defaultValues?.groups ?? [],
        contentType: defaultValues?.contentType ?? null,
        ...defaultValues,
      }],
    },
  });
  return <FormProvider {...form}>{children}</FormProvider>;
}

describe('GroupsForm', () => {
  it('renders contentType select', () => {
    render(
      <TestWrapper>
        <GroupsForm index={0} />
      </TestWrapper>,
    );
    expect(screen.getByText(/content type/i)).toBeInTheDocument();
  });

  it('renders add group button', () => {
    render(
      <TestWrapper>
        <GroupsForm index={0} />
      </TestWrapper>,
    );
    expect(screen.getByRole('button', { name: /add group/i })).toBeInTheDocument();
  });

  it('adds a group when clicking add', async () => {
    const user = userEvent.setup();
    render(
      <TestWrapper>
        <GroupsForm index={0} />
      </TestWrapper>,
    );
    await user.click(screen.getByRole('button', { name: /add group/i }));
    // Should now show group fields (id, displayName inputs)
    expect(screen.getAllByLabelText(/group id/i)).toHaveLength(1);
  });

  it('renders existing groups', () => {
    render(
      <TestWrapper defaultValues={{
        groups: [
          { id: 'g1', displayName: 'Group 1', pattern: '^S01' },
        ],
      }}>
        <GroupsForm index={0} />
      </TestWrapper>,
    );
    expect(screen.getByDisplayValue('g1')).toBeInTheDocument();
    expect(screen.getByDisplayValue('Group 1')).toBeInTheDocument();
    expect(screen.getByDisplayValue('^S01')).toBeInTheDocument();
  });

  it('shows nullSeasonGroupKey only when resolverType is rss', () => {
    render(
      <TestWrapper defaultValues={{ resolverType: 'rss' }}>
        <GroupsForm index={0} />
      </TestWrapper>,
    );
    expect(screen.getByText(/null season group key/i)).toBeInTheDocument();
  });
});
```

Note: You'll likely need to wrap with i18n provider (`I18nextProvider`) or mock `useTranslation`. Check how `regex-tester.test.tsx` handles this - it may render without i18n. If i18n is needed, set up a minimal i18n instance in the test. Adapt test setup as needed.

### Step 2: Run tests to verify they fail

```bash
cd packages/sp_react && pnpm test -- --run --reporter verbose src/components/editor/__tests__/groups-form.test.ts
```

Expected: FAIL - module `groups-form.tsx` not found.

### Step 3: Implement GroupDefCard

Create `packages/sp_react/src/components/editor/group-def-card.tsx`:

```tsx
import { useFormContext, Controller } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Card, CardContent } from '@/components/ui/card.tsx';
import { Trash2 } from 'lucide-react';

interface GroupDefCardProps {
  playlistIndex: number;
  groupIndex: number;
  onRemove: () => void;
}

export function GroupDefCard({ playlistIndex, groupIndex, onRemove }: GroupDefCardProps) {
  const { register, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${playlistIndex}.groups.${groupIndex}` as const;

  return (
    <Card>
      <CardContent className="space-y-3 pt-4">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium">
            {t('groupsSection')} {groupIndex + 1}
          </span>
          <Button variant="ghost" size="icon" onClick={onRemove}>
            <Trash2 className="h-4 w-4" />
          </Button>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <HintLabel htmlFor={`${prefix}.id`} hint="groupId">
              {t('groupId')}
            </HintLabel>
            <Input {...register(`${prefix}.id`)} />
          </div>
          <div className="space-y-1">
            <HintLabel htmlFor={`${prefix}.displayName`} hint="groupDisplayName">
              {t('groupDisplayName')}
            </HintLabel>
            <Input {...register(`${prefix}.displayName`)} />
          </div>
        </div>

        <div className="space-y-1">
          <HintLabel htmlFor={`${prefix}.pattern`} hint="groupPattern">
            {t('groupPattern')}
          </HintLabel>
          <Input {...register(`${prefix}.pattern`)} placeholder="(optional)" />
        </div>

        <div className="flex gap-4">
          <Controller
            name={`${prefix}.episodeYearHeaders`}
            control={control}
            render={({ field }) => (
              <div className="flex items-center gap-2">
                <Checkbox
                  id={`${prefix}.episodeYearHeaders`}
                  checked={field.value ?? false}
                  onCheckedChange={field.onChange}
                />
                <HintLabel htmlFor={`${prefix}.episodeYearHeaders`} hint="episodeYearHeaders">
                  {t('episodeYearHeaders')}
                </HintLabel>
              </div>
            )}
          />
          <Controller
            name={`${prefix}.showDateRange`}
            control={control}
            render={({ field }) => (
              <div className="flex items-center gap-2">
                <Checkbox
                  id={`${prefix}.showDateRange`}
                  checked={field.value ?? false}
                  onCheckedChange={field.onChange}
                />
                <HintLabel htmlFor={`${prefix}.showDateRange`} hint="showDateRange">
                  {t('showDateRange')}
                </HintLabel>
              </div>
            )}
          />
        </div>
      </CardContent>
    </Card>
  );
}
```

### Step 4: Implement GroupsForm

Create `packages/sp_react/src/components/editor/groups-form.tsx`:

```tsx
import { useFormContext, useFieldArray, Controller } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { GroupDefCard } from '@/components/editor/group-def-card.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Plus } from 'lucide-react';

interface GroupsFormProps {
  index: number;
}

export function GroupsForm({ index }: GroupsFormProps) {
  const { register, control, watch } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}` as const;
  const resolverType = watch(`${prefix}.resolverType`);

  const { fields, append, remove } = useFieldArray({
    control,
    name: `${prefix}.groups`,
  });

  return (
    <div className="space-y-4">
      <h3 className="text-sm font-semibold">{t('groupsSection')}</h3>

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1">
          <HintLabel htmlFor={`${prefix}.contentType`} hint="contentType">
            {t('contentType')}
          </HintLabel>
          <Controller
            name={`${prefix}.contentType`}
            control={control}
            render={({ field }) => (
              <Select
                value={field.value ?? 'episodes'}
                onValueChange={(v) => field.onChange(v === 'episodes' ? null : v)}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="episodes">{t('contentType_episodes')}</SelectItem>
                  <SelectItem value="groups">{t('contentType_groups')}</SelectItem>
                </SelectContent>
              </Select>
            )}
          />
        </div>

        {resolverType === 'rss' && (
          <div className="space-y-1">
            <HintLabel htmlFor={`${prefix}.nullSeasonGroupKey`} hint="nullSeasonGroupKey">
              {t('nullSeasonGroupKey')}
            </HintLabel>
            <Input
              type="number"
              {...register(`${prefix}.nullSeasonGroupKey`, { valueAsNumber: true })}
            />
          </div>
        )}
      </div>

      <div className="space-y-3">
        {fields.map((field, groupIndex) => (
          <GroupDefCard
            key={field.id}
            playlistIndex={index}
            groupIndex={groupIndex}
            onRemove={() => remove(groupIndex)}
          />
        ))}
      </div>

      <Button
        type="button"
        variant="outline"
        size="sm"
        onClick={() => append({ id: '', displayName: '', pattern: '' })}
      >
        <Plus className="mr-1 h-4 w-4" />
        {t('addGroup')}
      </Button>
    </div>
  );
}
```

### Step 5: Run tests

```bash
cd packages/sp_react && pnpm test -- --run --reporter verbose src/components/editor/__tests__/groups-form.test.ts
```

Expected: PASS (adapt tests as needed for i18n setup).

### Step 6: Run full suite

```bash
cd packages/sp_react && pnpm test -- --run
```

### Step 7: Commit

```
feat: add GroupsForm and GroupDefCard components for group definitions editing
```

---

## Task 6: Build SortForm component

Create the Sort form section with simple/composite toggle and dynamic rule list.

**Files:**
- Create: `packages/sp_react/src/components/editor/sort-form.tsx`
- Create: `packages/sp_react/src/components/editor/sort-rule-card.tsx`
- Create: `packages/sp_react/src/components/editor/__tests__/sort-form.test.tsx`

### Step 1: Write failing tests

Create `packages/sp_react/src/components/editor/__tests__/sort-form.test.tsx`:

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { FormProvider, useForm } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { SortForm } from '../sort-form.tsx';

// Same RHF wrapper pattern as GroupsForm tests

describe('SortForm', () => {
  it('renders simple/composite toggle', () => {
    // ...
    expect(screen.getByText(/simple/i)).toBeInTheDocument();
    expect(screen.getByText(/composite/i)).toBeInTheDocument();
  });

  it('shows field and order selects in simple mode', () => {
    // Default is no sort (null), selecting simple shows fields
  });

  it('shows add rule button in composite mode', async () => {
    // Switch to composite, verify add rule button
  });

  it('renders existing simple sort', () => {
    // Pre-populate customSort with { type: 'simple', field: 'playlistNumber', order: 'ascending' }
    // Verify selects show correct values
  });

  it('renders existing composite sort rules', () => {
    // Pre-populate customSort with composite rules
    // Verify rule cards are rendered
  });
});
```

### Step 2: Run tests to verify failure

```bash
cd packages/sp_react && pnpm test -- --run --reporter verbose src/components/editor/__tests__/sort-form.test.ts
```

### Step 3: Implement SortRuleCard

Create `packages/sp_react/src/components/editor/sort-rule-card.tsx`:

```tsx
import { useFormContext, Controller } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Card, CardContent } from '@/components/ui/card.tsx';
import { Trash2 } from 'lucide-react';

const SORT_FIELDS = ['playlistNumber', 'newestEpisodeDate', 'progress', 'alphabetical'] as const;
const SORT_ORDERS = ['ascending', 'descending'] as const;

interface SortRuleCardProps {
  playlistIndex: number;
  ruleIndex: number;
  onRemove: () => void;
}

export function SortRuleCard({ playlistIndex, ruleIndex, onRemove }: SortRuleCardProps) {
  const { control, watch } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${playlistIndex}.customSort.rules.${ruleIndex}` as const;
  const hasCondition = watch(`${prefix}.condition`) != null;

  return (
    <Card>
      <CardContent className="space-y-3 pt-4">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium">
            Rule {ruleIndex + 1}
          </span>
          <Button variant="ghost" size="icon" onClick={onRemove}>
            <Trash2 className="h-4 w-4" />
          </Button>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <HintLabel htmlFor={`${prefix}.field`} hint="sortField">
              {t('sortField')}
            </HintLabel>
            <Controller
              name={`${prefix}.field`}
              control={control}
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {SORT_FIELDS.map((f) => (
                      <SelectItem key={f} value={f}>{t(`sortField_${f}`)}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </div>
          <div className="space-y-1">
            <HintLabel htmlFor={`${prefix}.order`} hint="sortOrder">
              {t('sortOrder')}
            </HintLabel>
            <Controller
              name={`${prefix}.order`}
              control={control}
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {SORT_ORDERS.map((o) => (
                      <SelectItem key={o} value={o}>{t(`sortOrder_${o}`)}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </div>
        </div>

        <Controller
          name={`${prefix}.condition`}
          control={control}
          render={({ field }) => (
            <div className="space-y-2">
              <div className="flex items-center gap-2">
                <Checkbox
                  checked={field.value != null}
                  onCheckedChange={(checked) => {
                    field.onChange(checked ? { type: 'sortKeyGreaterThan', value: 0 } : null);
                  }}
                />
                <HintLabel hint="sortCondition">{t('sortConditional')}</HintLabel>
              </div>
              {field.value != null && (
                <div className="ml-6 space-y-1">
                  <HintLabel>{t('sortConditionValue')}</HintLabel>
                  <Input
                    type="number"
                    value={field.value.value ?? 0}
                    onChange={(e) =>
                      field.onChange({
                        type: 'sortKeyGreaterThan',
                        value: Number(e.target.value),
                      })
                    }
                  />
                </div>
              )}
            </div>
          )}
        />
      </CardContent>
    </Card>
  );
}

export { SORT_FIELDS, SORT_ORDERS };
```

### Step 4: Implement SortForm

Create `packages/sp_react/src/components/editor/sort-form.tsx`:

The SortForm needs to handle the discriminated union between `simple` and `composite` customSort. The key challenge is switching between the two modes:

```tsx
import { useFormContext, useFieldArray, Controller } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { SortRuleCard, SORT_FIELDS, SORT_ORDERS } from '@/components/editor/sort-rule-card.tsx';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { Button } from '@/components/ui/button.tsx';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group.tsx';
import { Plus } from 'lucide-react';

interface SortFormProps {
  index: number;
}

export function SortForm({ index }: SortFormProps) {
  const { control, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}.customSort` as const;
  const sortSpec = watch(prefix);
  const sortType = sortSpec?.type ?? null;

  // For composite mode, we need useFieldArray for rules
  const { fields, append, remove } = useFieldArray({
    control,
    name: `playlists.${index}.customSort.rules` as any,
  });

  const handleTypeChange = (newType: string) => {
    if (newType === 'simple') {
      setValue(prefix, {
        type: 'simple',
        field: 'playlistNumber',
        order: 'ascending',
      });
    } else if (newType === 'composite') {
      setValue(prefix, {
        type: 'composite',
        rules: [{ field: 'playlistNumber', order: 'ascending' }],
      });
    } else {
      setValue(prefix, null);
    }
  };

  return (
    <div className="space-y-4">
      <h3 className="text-sm font-semibold">{t('sortSection')}</h3>

      <div className="space-y-1">
        <HintLabel hint="customSort">{t('sortType')}</HintLabel>
        <ToggleGroup
          type="single"
          value={sortType ?? ''}
          onValueChange={handleTypeChange}
        >
          <ToggleGroupItem value="simple">{t('sortSimple')}</ToggleGroupItem>
          <ToggleGroupItem value="composite">{t('sortComposite')}</ToggleGroupItem>
        </ToggleGroup>
      </div>

      {sortType === 'simple' && (
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1">
            <HintLabel hint="sortField">{t('sortField')}</HintLabel>
            <Controller
              name={`${prefix}.field` as any}
              control={control}
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {SORT_FIELDS.map((f) => (
                      <SelectItem key={f} value={f}>{t(`sortField_${f}`)}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </div>
          <div className="space-y-1">
            <HintLabel hint="sortOrder">{t('sortOrder')}</HintLabel>
            <Controller
              name={`${prefix}.order` as any}
              control={control}
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {SORT_ORDERS.map((o) => (
                      <SelectItem key={o} value={o}>{t(`sortOrder_${o}`)}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </div>
        </div>
      )}

      {sortType === 'composite' && (
        <div className="space-y-3">
          {fields.map((field, ruleIndex) => (
            <SortRuleCard
              key={field.id}
              playlistIndex={index}
              ruleIndex={ruleIndex}
              onRemove={() => remove(ruleIndex)}
            />
          ))}
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => append({ field: 'playlistNumber', order: 'ascending' })}
          >
            <Plus className="mr-1 h-4 w-4" />
            {t('addSortRule')}
          </Button>
        </div>
      )}
    </div>
  );
}
```

Note: The `ToggleGroup` component may or may not exist in the project's shadcn setup. If not, use a simple radio group or two `Button` components with active/inactive styling. Check `packages/sp_react/src/components/ui/` for available components.

### Step 5: Run tests

```bash
cd packages/sp_react && pnpm test -- --run
```

### Step 6: Commit

```
feat: add SortForm and SortRuleCard components for custom sort editing
```

---

## Task 7: Build ExtractorsForm component

Create the unified Extractors section with three sub-forms.

**Files:**
- Create: `packages/sp_react/src/components/editor/extractors-form.tsx`
- Create: `packages/sp_react/src/components/editor/title-extractor-form.tsx`
- Create: `packages/sp_react/src/components/editor/episode-number-extractor-form.tsx`
- Create: `packages/sp_react/src/components/editor/episode-extractor-form.tsx`
- Create: `packages/sp_react/src/components/editor/__tests__/extractors-form.test.tsx`

### Step 1: Write failing tests

Create `packages/sp_react/src/components/editor/__tests__/extractors-form.test.tsx`:

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { FormProvider, useForm } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { ExtractorsForm } from '../extractors-form.tsx';

// Same TestWrapper pattern

describe('ExtractorsForm', () => {
  it('renders all three extractor sub-headings', () => {
    // ...
    expect(screen.getByText(/title extractor/i)).toBeInTheDocument();
    expect(screen.getByText(/episode number extractor/i)).toBeInTheDocument();
    expect(screen.getByText(/episode extractor/i)).toBeInTheDocument();
  });

  it('renders title extractor source select', () => {
    // ...
  });

  it('adds fallback step when clicking add fallback', async () => {
    // ...
  });

  it('renders episode number extractor fields', () => {
    // pattern, captureGroup, fallbackToRss
  });

  it('renders episode extractor fields', () => {
    // source, pattern, seasonGroup, episodeGroup
  });
});
```

### Step 2: Implement TitleExtractorForm

Create `packages/sp_react/src/components/editor/title-extractor-form.tsx`:

The key challenge is the recursive `fallback` field. We flatten it to a list of "steps" for the UI:

```tsx
import { useCallback, useMemo } from 'react';
import { useFormContext, Controller } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, TitleExtractor } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Card, CardContent } from '@/components/ui/card.tsx';
import { Plus, Trash2 } from 'lucide-react';

const SOURCES = ['title', 'description', 'seasonNumber', 'episodeNumber'] as const;

interface TitleExtractorFormProps {
  index: number;
}

// Convert recursive structure to flat steps array
function flattenChain(extractor: TitleExtractor | null | undefined): TitleExtractor[] {
  if (!extractor) return [];
  const steps: TitleExtractor[] = [];
  let current: TitleExtractor | null | undefined = extractor;
  while (current) {
    steps.push({ ...current, fallback: undefined });
    current = current.fallback;
  }
  return steps;
}

// Convert flat steps array back to recursive structure
function nestChain(steps: TitleExtractor[], fallbackValue?: string | null): TitleExtractor | null {
  if (steps.length === 0) return null;
  let result: TitleExtractor | null = null;
  // Build from the last step backwards
  for (let i = steps.length - 1; 0 <= i; i--) {
    result = {
      ...steps[i],
      fallback: result,
      fallbackValue: i === 0 ? fallbackValue : undefined,
    };
  }
  return result;
}

export function TitleExtractorForm({ index }: TitleExtractorFormProps) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}.titleExtractor` as const;
  const extractor = watch(prefix);

  const steps = useMemo(() => flattenChain(extractor), [extractor]);
  const fallbackValue = extractor?.fallbackValue;

  const updateSteps = useCallback((newSteps: TitleExtractor[], newFallbackValue?: string | null) => {
    const nested = nestChain(newSteps, newFallbackValue ?? fallbackValue);
    setValue(prefix, nested);
  }, [setValue, prefix, fallbackValue]);

  const handleStepChange = useCallback((stepIndex: number, field: string, value: unknown) => {
    const newSteps = steps.map((s, i) =>
      i === stepIndex ? { ...s, [field]: value } : s,
    );
    updateSteps(newSteps);
  }, [steps, updateSteps]);

  const addStep = useCallback(() => {
    updateSteps([...steps, { source: 'title', group: 0 }]);
  }, [steps, updateSteps]);

  const removeStep = useCallback((stepIndex: number) => {
    updateSteps(steps.filter((_, i) => i !== stepIndex));
  }, [steps, updateSteps]);

  // If no extractor yet, show just an "Enable" button
  if (steps.length === 0) {
    return (
      <div className="space-y-2">
        <h4 className="text-sm font-medium">{t('titleExtractor')}</h4>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => updateSteps([{ source: 'title', group: 0 }])}
        >
          <Plus className="mr-1 h-4 w-4" />
          {t('titleExtractor')}
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <HintLabel hint="titleExtractor">
          <h4 className="text-sm font-medium">{t('titleExtractor')}</h4>
        </HintLabel>
        <Button
          variant="ghost"
          size="icon"
          onClick={() => setValue(prefix, null)}
        >
          <Trash2 className="h-4 w-4" />
        </Button>
      </div>

      {steps.map((step, stepIndex) => (
        <Card key={stepIndex}>
          <CardContent className="space-y-3 pt-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">
                {stepIndex === 0 ? t('titleExtractor') : t('fallbackStep', { number: stepIndex })}
              </span>
              {0 < stepIndex && (
                <Button variant="ghost" size="icon" onClick={() => removeStep(stepIndex)}>
                  <Trash2 className="h-4 w-4" />
                </Button>
              )}
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <HintLabel hint="titleExtractorSource">{t('titleExtractorSource')}</HintLabel>
                <Select
                  value={step.source}
                  onValueChange={(v) => handleStepChange(stepIndex, 'source', v)}
                >
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {SOURCES.map((s) => (
                      <SelectItem key={s} value={s}>{t(`source_${s}`)}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <HintLabel hint="titleExtractorGroup">{t('titleExtractorGroup')}</HintLabel>
                <Input
                  type="number"
                  value={step.group ?? 0}
                  onChange={(e) => handleStepChange(stepIndex, 'group', Number(e.target.value))}
                />
              </div>
            </div>

            <div className="space-y-1">
              <HintLabel hint="titleExtractorPattern">{t('titleExtractorPattern')}</HintLabel>
              <Input
                value={step.pattern ?? ''}
                onChange={(e) => handleStepChange(stepIndex, 'pattern', e.target.value || null)}
                placeholder="(optional)"
              />
            </div>

            <div className="space-y-1">
              <HintLabel hint="titleExtractorTemplate">{t('titleExtractorTemplate')}</HintLabel>
              <Input
                value={step.template ?? ''}
                onChange={(e) => handleStepChange(stepIndex, 'template', e.target.value || null)}
                placeholder="e.g. Season {value}"
              />
            </div>
          </CardContent>
        </Card>
      ))}

      <div className="flex gap-2">
        <Button type="button" variant="outline" size="sm" onClick={addStep}>
          <Plus className="mr-1 h-4 w-4" />
          {t('addFallback')}
        </Button>
      </div>

      <div className="space-y-1">
        <HintLabel hint="titleExtractorFallbackValue">{t('titleExtractorFallbackValue')}</HintLabel>
        <Input
          value={fallbackValue ?? ''}
          onChange={(e) => {
            const val = e.target.value || null;
            const nested = nestChain(steps, val);
            setValue(prefix, nested);
          }}
          placeholder="(optional)"
        />
      </div>
    </div>
  );
}

export { flattenChain, nestChain };
```

### Step 3: Implement EpisodeNumberExtractorForm

Create `packages/sp_react/src/components/editor/episode-number-extractor-form.tsx`:

```tsx
import { useFormContext, Controller } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Plus, Trash2 } from 'lucide-react';

interface EpisodeNumberExtractorFormProps {
  index: number;
}

export function EpisodeNumberExtractorForm({ index }: EpisodeNumberExtractorFormProps) {
  const { register, control, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}.episodeNumberExtractor` as const;
  const extractor = watch(prefix);

  if (!extractor) {
    return (
      <div className="space-y-2">
        <h4 className="text-sm font-medium">{t('episodeNumberExtractor')}</h4>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => setValue(prefix, { pattern: '', captureGroup: 1, fallbackToRss: true })}
        >
          <Plus className="mr-1 h-4 w-4" />
          {t('episodeNumberExtractor')}
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <HintLabel hint="episodeNumberExtractor">
          <h4 className="text-sm font-medium">{t('episodeNumberExtractor')}</h4>
        </HintLabel>
        <Button variant="ghost" size="icon" onClick={() => setValue(prefix, null)}>
          <Trash2 className="h-4 w-4" />
        </Button>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1">
          <HintLabel hint="episodeNumberPattern">{t('episodeNumberPattern')}</HintLabel>
          <Input {...register(`${prefix}.pattern`)} />
        </div>
        <div className="space-y-1">
          <HintLabel hint="episodeNumberCaptureGroup">{t('episodeNumberCaptureGroup')}</HintLabel>
          <Input type="number" {...register(`${prefix}.captureGroup`, { valueAsNumber: true })} />
        </div>
      </div>

      <Controller
        name={`${prefix}.fallbackToRss`}
        control={control}
        render={({ field }) => (
          <div className="flex items-center gap-2">
            <Checkbox
              checked={field.value ?? true}
              onCheckedChange={field.onChange}
            />
            <HintLabel hint="episodeNumberFallbackToRss">
              {t('episodeNumberFallbackToRss')}
            </HintLabel>
          </div>
        )}
      />
    </div>
  );
}
```

### Step 4: Implement EpisodeExtractorForm

Create `packages/sp_react/src/components/editor/episode-extractor-form.tsx`:

```tsx
import { useFormContext, Controller } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Plus, Trash2 } from 'lucide-react';

interface EpisodeExtractorFormProps {
  index: number;
}

export function EpisodeExtractorForm({ index }: EpisodeExtractorFormProps) {
  const { register, control, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}.smartPlaylistEpisodeExtractor` as const;
  const extractor = watch(prefix);

  if (!extractor) {
    return (
      <div className="space-y-2">
        <h4 className="text-sm font-medium">{t('episodeExtractor')}</h4>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => setValue(prefix, {
            source: 'title',
            pattern: '',
            seasonGroup: 1,
            episodeGroup: 2,
            fallbackEpisodeCaptureGroup: 1,
          })}
        >
          <Plus className="mr-1 h-4 w-4" />
          {t('episodeExtractor')}
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <HintLabel hint="episodeExtractor">
          <h4 className="text-sm font-medium">{t('episodeExtractor')}</h4>
        </HintLabel>
        <Button variant="ghost" size="icon" onClick={() => setValue(prefix, null)}>
          <Trash2 className="h-4 w-4" />
        </Button>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1">
          <HintLabel hint="episodeExtractorSource">{t('episodeExtractorSource')}</HintLabel>
          <Controller
            name={`${prefix}.source`}
            control={control}
            render={({ field }) => (
              <Select value={field.value} onValueChange={field.onChange}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="title">{t('source_title')}</SelectItem>
                  <SelectItem value="description">{t('source_description')}</SelectItem>
                </SelectContent>
              </Select>
            )}
          />
        </div>
        <div className="space-y-1">
          <HintLabel hint="episodeExtractorPattern">{t('episodeExtractorPattern')}</HintLabel>
          <Input {...register(`${prefix}.pattern`)} />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1">
          <HintLabel hint="episodeExtractorSeasonGroup">{t('episodeExtractorSeasonGroup')}</HintLabel>
          <Input type="number" {...register(`${prefix}.seasonGroup`, { valueAsNumber: true })} />
        </div>
        <div className="space-y-1">
          <HintLabel hint="episodeExtractorEpisodeGroup">{t('episodeExtractorEpisodeGroup')}</HintLabel>
          <Input type="number" {...register(`${prefix}.episodeGroup`, { valueAsNumber: true })} />
        </div>
      </div>

      <h5 className="text-xs font-medium text-muted-foreground pt-2">Fallback</h5>

      <div className="grid grid-cols-3 gap-3">
        <div className="space-y-1">
          <HintLabel hint="episodeExtractorFallbackSeason">{t('episodeExtractorFallbackSeason')}</HintLabel>
          <Input
            type="number"
            {...register(`${prefix}.fallbackSeasonNumber`, { valueAsNumber: true })}
          />
        </div>
        <div className="space-y-1">
          <HintLabel hint="episodeExtractorFallbackPattern">{t('episodeExtractorFallbackPattern')}</HintLabel>
          <Input {...register(`${prefix}.fallbackEpisodePattern`)} />
        </div>
        <div className="space-y-1">
          <HintLabel hint="episodeExtractorFallbackCaptureGroup">{t('episodeExtractorFallbackCaptureGroup')}</HintLabel>
          <Input
            type="number"
            {...register(`${prefix}.fallbackEpisodeCaptureGroup`, { valueAsNumber: true })}
          />
        </div>
      </div>
    </div>
  );
}
```

### Step 5: Implement ExtractorsForm container

Create `packages/sp_react/src/components/editor/extractors-form.tsx`:

```tsx
import { useTranslation } from 'react-i18next';
import { TitleExtractorForm } from './title-extractor-form.tsx';
import { EpisodeNumberExtractorForm } from './episode-number-extractor-form.tsx';
import { EpisodeExtractorForm } from './episode-extractor-form.tsx';

interface ExtractorsFormProps {
  index: number;
}

export function ExtractorsForm({ index }: ExtractorsFormProps) {
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-6">
      <h3 className="text-sm font-semibold">{t('extractorsSection')}</h3>
      <TitleExtractorForm index={index} />
      <EpisodeNumberExtractorForm index={index} />
      <EpisodeExtractorForm index={index} />
    </div>
  );
}
```

### Step 6: Write unit test for flattenChain/nestChain

Add to the test file:

```typescript
import { flattenChain, nestChain } from '../title-extractor-form.tsx';

describe('flattenChain / nestChain', () => {
  it('flattens a recursive chain into steps', () => {
    const chain = {
      source: 'title',
      pattern: '^(.+)',
      group: 1,
      fallback: {
        source: 'seasonNumber',
        group: 0,
        template: 'Season {value}',
      },
      fallbackValue: 'Unknown',
    };
    const steps = flattenChain(chain);
    expect(steps).toHaveLength(2);
    expect(steps[0].source).toBe('title');
    expect(steps[0].fallback).toBeUndefined();
    expect(steps[1].source).toBe('seasonNumber');
  });

  it('nests steps back into recursive structure', () => {
    const steps = [
      { source: 'title', pattern: '^(.+)', group: 1 },
      { source: 'seasonNumber', group: 0, template: 'Season {value}' },
    ];
    const nested = nestChain(steps, 'Unknown');
    expect(nested?.source).toBe('title');
    expect(nested?.fallbackValue).toBe('Unknown');
    expect(nested?.fallback?.source).toBe('seasonNumber');
    expect(nested?.fallback?.fallback).toBeNull();
  });

  it('returns null for empty steps', () => {
    expect(nestChain([])).toBeNull();
  });

  it('returns empty array for null extractor', () => {
    expect(flattenChain(null)).toEqual([]);
  });
});
```

### Step 7: Run tests

```bash
cd packages/sp_react && pnpm test -- --run
```

### Step 8: Commit

```
feat: add ExtractorsForm with TitleExtractor, EpisodeNumberExtractor, and EpisodeExtractor sub-forms
```

---

## Task 8: Wire forms into PlaylistForm and restructure layout

Integrate all new form sections into PlaylistForm, restructure PlaylistTabContent to side-by-side layout, and remove AdvancedNote.

**Files:**
- Modify: `packages/sp_react/src/components/editor/playlist-form.tsx`
- Modify: `packages/sp_react/src/components/editor/playlist-tab-content.tsx`

### Step 1: Update PlaylistForm

In `packages/sp_react/src/components/editor/playlist-form.tsx`:

1. Add imports for the new form components:
```tsx
import { GroupsForm } from '@/components/editor/groups-form.tsx';
import { SortForm } from '@/components/editor/sort-form.tsx';
import { ExtractorsForm } from '@/components/editor/extractors-form.tsx';
```

2. Replace the `<AdvancedNote />` line (around line 76 in the AccordionContent) with:
```tsx
<GroupsForm index={index} />
<SortForm index={index} />
<ExtractorsForm index={index} />
```

3. Remove the `AdvancedNote` component definition (lines 226-234) and its reference.

### Step 2: Restructure PlaylistTabContent for side-by-side

In `packages/sp_react/src/components/editor/playlist-tab-content.tsx`:

The current layout is `grid gap-6 lg:grid-cols-2` with form left and preview right. This is already side-by-side. However, the right side currently shows only the per-playlist preview tree. We need to update it to show the enriched preview with Groups, Sort, and Extraction sections.

Update the preview side to pass enriched data:

```tsx
{/* Preview side */}
<div className="space-y-4 lg:sticky lg:top-4 lg:self-start">
  {previewPlaylist ? (
    <>
      {previewPlaylist.debug && (
        <PlaylistDebugStats debug={previewPlaylist.debug} />
      )}
      <PlaylistTree playlists={[previewPlaylist]} />
      <ExtractionPreview playlist={previewPlaylist} />
      <ClaimedEpisodesSection
        episodes={previewPlaylist.claimedByOthers ?? []}
      />
    </>
  ) : (
    <p className="text-sm text-muted-foreground py-8 text-center">
      {t('tabPreviewEmpty')}
    </p>
  )}
</div>
```

Add `lg:sticky lg:top-4 lg:self-start` to the preview div to make it stick while scrolling the form.

### Step 3: Run tests

```bash
cd packages/sp_react && pnpm test -- --run
```

### Step 4: Commit

```
feat: wire GroupsForm, SortForm, ExtractorsForm into PlaylistForm; restructure layout to sticky preview
```

---

## Task 9: Enrich preview panel with section-specific display

Update the preview components to display enriched episode data: sort keys with dates, and an extraction results table.

**Files:**
- Create: `packages/sp_react/src/components/preview/extraction-preview.tsx`
- Modify: `packages/sp_react/src/components/preview/playlist-tree.tsx` (show enriched episode info)
- Create: `packages/sp_react/src/components/preview/__tests__/extraction-preview.test.tsx`

### Step 1: Write tests for ExtractionPreview

Create `packages/sp_react/src/components/preview/__tests__/extraction-preview.test.tsx`:

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ExtractionPreview } from '../extraction-preview.tsx';
import type { PreviewPlaylist } from '@/schemas/api-schema.ts';

describe('ExtractionPreview', () => {
  it('renders extraction table with enriched episode data', () => {
    const playlist: PreviewPlaylist = {
      id: 'seasons',
      displayName: 'Seasons',
      sortKey: 0,
      episodeCount: 2,
      groups: [{
        id: 'season_1',
        displayName: 'Season 1',
        sortKey: 1,
        episodeCount: 2,
        episodes: [
          {
            id: 1,
            title: 'S1E1 - Rome',
            seasonNumber: 1,
            episodeNumber: 1,
            extractedDisplayName: 'Rome',
            publishedAt: '2024-01-01T00:00:00Z',
          },
          {
            id: 2,
            title: 'S1E2 - Milan',
            seasonNumber: 1,
            episodeNumber: 2,
            extractedDisplayName: 'Milan',
            publishedAt: '2024-01-08T00:00:00Z',
          },
        ],
      }],
      claimedByOthers: [],
    };

    render(<ExtractionPreview playlist={playlist} />);

    expect(screen.getByText('Rome')).toBeInTheDocument();
    expect(screen.getByText('Milan')).toBeInTheDocument();
  });

  it('renders nothing when no episodes have extraction data', () => {
    const playlist: PreviewPlaylist = {
      id: 'seasons',
      displayName: 'Seasons',
      sortKey: 0,
      episodeCount: 1,
      groups: [{
        id: 'g1',
        displayName: 'Group 1',
        sortKey: 1,
        episodeCount: 1,
        episodes: [{ id: 1, title: 'Ep 1' }],
      }],
      claimedByOthers: [],
    };

    const { container } = render(<ExtractionPreview playlist={playlist} />);
    expect(container.firstChild).toBeNull();
  });
});
```

### Step 2: Implement ExtractionPreview

Create `packages/sp_react/src/components/preview/extraction-preview.tsx`:

```tsx
import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import type { PreviewPlaylist, PreviewEpisode } from '@/schemas/api-schema.ts';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card.tsx';

interface ExtractionPreviewProps {
  playlist: PreviewPlaylist;
}

export function ExtractionPreview({ playlist }: ExtractionPreviewProps) {
  const { t } = useTranslation('preview');

  const enrichedEpisodes = useMemo(() => {
    const episodes: PreviewEpisode[] = [];
    for (const group of playlist.groups ?? []) {
      for (const ep of group.episodes) {
        if (ep.extractedDisplayName != null || ep.seasonNumber != null || ep.episodeNumber != null) {
          episodes.push(ep);
        }
      }
    }
    return episodes;
  }, [playlist.groups]);

  if (enrichedEpisodes.length === 0) return null;

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm">{t('extractionResults')}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="pb-1 pr-2">{t('title')}</th>
                <th className="pb-1 pr-2">{t('extractedName')}</th>
                <th className="pb-1 pr-2">{t('season')}</th>
                <th className="pb-1">{t('episode')}</th>
              </tr>
            </thead>
            <tbody>
              {enrichedEpisodes.map((ep) => (
                <tr key={ep.id} className="border-b last:border-0">
                  <td className="py-1 pr-2 max-w-[200px] truncate">{ep.title}</td>
                  <td className="py-1 pr-2">{ep.extractedDisplayName ?? '-'}</td>
                  <td className="py-1 pr-2">{ep.seasonNumber ?? '-'}</td>
                  <td className="py-1">{ep.episodeNumber ?? '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>
  );
}
```

### Step 3: Update PlaylistTree to show enriched info

In `packages/sp_react/src/components/preview/playlist-tree.tsx`, update the `EpisodeList` component (around line 74) to optionally show `publishedAt`:

```tsx
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

### Step 4: Run tests

```bash
cd packages/sp_react && pnpm test -- --run
```

### Step 5: Commit

```
feat: add ExtractionPreview component and enrich episode display in playlist tree
```

---

## Task 10: Update DEFAULT_PLAYLIST and cleanup

Ensure the default playlist values include sensible defaults for the new fields, and clean up any remaining references.

**Files:**
- Modify: `packages/sp_react/src/components/editor/config-form.tsx`

### Step 1: Update DEFAULT_PLAYLIST

No new fields needed in `DEFAULT_PLAYLIST` - all new fields are nullable/optional and default to `null`/`undefined` via the Zod schema defaults. The existing `DEFAULT_PLAYLIST` remains unchanged.

Verify that `sanitizeConfig` properly handles the new nested structures by checking the existing tests:

```bash
cd packages/sp_react && pnpm test -- --run --reporter verbose src/lib/__tests__/sanitize-config.test.ts
```

If the recursive sanitization works correctly (it should - `sanitizeConfig` handles arrays and objects recursively), no changes are needed.

### Step 2: Full integration test

Run the entire test suite:

```bash
cd packages/sp_react && pnpm test -- --run
dart test packages/sp_server
dart test packages/sp_shared
```

### Step 3: Format and analyze

```bash
dart format packages/sp_server/lib/src/routes/config_routes.dart
dart analyze packages/sp_server
dart analyze packages/sp_shared
```

### Step 4: Final commit

```
chore: verify defaults and sanitization work with advanced settings forms
```

---

## Task 11: Post-implementation verification

Run the full post-implementation checklist.

### Step 1: Format all changed Dart files

```bash
dart format packages/sp_server/lib/src/routes/config_routes.dart packages/sp_server/test/routes/config_routes_test.dart
```

### Step 2: Analyze

```bash
dart analyze packages/sp_server
dart analyze packages/sp_shared
```

Must have zero errors/warnings.

### Step 3: Run all tests

```bash
dart test packages/sp_shared
dart test packages/sp_server
cd packages/sp_react && pnpm test -- --run
```

All must pass.

### Step 4: Create/move bookmark

```bash
jj bookmark move feat/advanced-settings-forms
```

---

## Dependency Graph

```
Task 1 (server enrichment)
  |
  v
Task 2 (frontend types) --> Task 9 (preview enrichment)
  |                                    |
  v                                    v
Task 3 (i18n) --> Task 4 (yearHeaderMode)
  |           --> Task 5 (GroupsForm)     --> Task 8 (wire + layout)
  |           --> Task 6 (SortForm)       --> Task 8
  |           --> Task 7 (ExtractorsForm) --> Task 8
                                                |
                                                v
                                          Task 10 (cleanup)
                                                |
                                                v
                                          Task 11 (verification)
```

Tasks 4, 5, 6, 7 can run in parallel after Task 3.
Tasks 8, 9 can run in parallel.
