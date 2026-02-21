# Advanced Settings Form UI Design

## Goal

Replace the "Advanced fields can be edited in JSON mode" note with full form-based editing for Groups, Sort, and Extractors. Add an enriched unified preview panel showing section-specific results alongside the forms.

## Layout

Side-by-side within each playlist tab:

- **Left (scrollable):** Form sections stacked vertically
- **Right (sticky):** One shared preview panel showing Groups, Sort, and Extraction results

```
+---------------------+--------------------+
| Forms (scroll)      | Preview (sticky)   |
|                     |                    |
| +--Basic/Filters--+ | -- Groups --       |
| |                 | | Season 1: 5 eps    |
| +-----------------+ | Season 2: 3 eps    |
| +--Groups form----+ |                    |
| |                 | | -- Sort --         |
| +-----------------+ | 1. Season 2        |
| +--Sort form------+ | 2. Season 1        |
| |                 | |                    |
| +-----------------+ | -- Extraction --   |
| +--Extractors-----+ | ep1: "Rome" S1E3   |
| |                 | | ep2: "Milan" S1E4  |
| +-----------------+ |                    |
+---------------------+--------------------+
```

One "Preview" button triggers a single API call. The preview panel populates all three sections at once.

## Form Sections

### Groups Section

Fields at the top:
- `contentType`: select (episodes | groups). Placed here because it enables group mode.
- `nullSeasonGroupKey`: number input. Shown only when resolverType is rssMetadata.

Group Definitions list (useFieldArray):
- Each group is a card with a delete button
- Fields per group: `id`, `displayName`, `pattern` (regex, optional for catch-all), `episodeYearHeaders` (checkbox), `showDateRange` (checkbox)
- "Add Group" button appends a blank definition

### Sort Section

Simple/Composite toggle (radio group):

**Simple mode:** field select + order select.
- Field options: playlistNumber, newestEpisodeDate, progress, alphabetical
- Order options: ascending, descending

**Composite mode:** dynamic rule list (useFieldArray).
- Each rule is a card with: field select, order select, optional conditional checkbox
- Conditional reveals: sortKeyGreaterThan value input
- "Add Rule" button appends a blank rule

### Extractors Section

Three sub-forms under one heading.

**Title Extractor** (recursive fallback chain displayed as flat steps):
- Each step: source select (title | description | seasonNumber | episodeNumber), pattern (regex, optional), group (capture group index), template (optional)
- Steps render top-to-bottom: try step 1, if it fails try step 2, etc.
- "Add Fallback" button adds the next step
- `fallbackValue` string input at the bottom (final fallback if all steps fail)

**Episode Number Extractor:**
- `pattern`: regex input
- `captureGroup`: number input (default 1)
- `fallbackToRss`: checkbox (default true)

**Episode Extractor (Season + Episode):**
- `source`: select (title | description)
- `pattern`: regex input
- `seasonGroup`: number input (default 1)
- `episodeGroup`: number input (default 2)
- Fallback sub-section: `fallbackSeasonNumber` (optional number), `fallbackEpisodePattern` (optional regex), `fallbackEpisodeCaptureGroup` (number, default 1)

### yearHeaderMode (existing section)

Added to the existing BooleanSettings area as a select: none | firstEpisode | perEpisode.

## Preview API Extension

Extend the existing `POST /api/configs/preview` response. No new endpoints.

### Current episode shape

```json
{ "id": 123, "title": "S1E3 - Rome" }
```

### Enriched episode shape

```json
{
  "id": 123,
  "title": "S1E3 - Rome",
  "publishedAt": "2024-01-15T00:00:00Z",
  "seasonNumber": 1,
  "episodeNumber": 3,
  "extractedDisplayName": "Rome",
  "matchedPattern": "^S0?1"
}
```

New fields:
- `publishedAt` - for Sort preview (show sort keys)
- `seasonNumber` / `episodeNumber` - from enrichment, for Extraction preview
- `extractedDisplayName` - from titleExtractor, for Extraction preview
- `matchedPattern` - which group regex matched, for Groups preview

### Server changes (sp_server)

1. `_serializeEpisode` - include publishedAt, seasonNumber, episodeNumber
2. `_serializeGroup` - include matchedPattern (the regex that categorized episodes)
3. Run titleExtractor during preview and capture extractedDisplayName per episode
4. Response structure stays the same (playlists with groups + ungrouped + debug)

### Preview panel sections (sp_react)

The right-side preview panel renders three labeled sections:

1. **Groups**: Existing playlist tree (groups with episode lists), now with matchedPattern annotation per episode
2. **Sort**: Playlist/group order with sort key values (publishedAt, playlistNumber)
3. **Extraction**: Table of episode title, extracted display name, season, episode number

## Component Architecture

### New components (packages/sp_react/src/components/editor/)

| Component | Purpose |
|-----------|---------|
| `GroupsForm` | contentType select + nullSeasonGroupKey + group definition list |
| `GroupDefCard` | Single group definition card |
| `SortForm` | Simple/composite toggle + sort rules |
| `SortRuleCard` | Single composite sort rule card |
| `ExtractorsForm` | Container for all three extractor sub-forms |
| `TitleExtractorForm` | Fallback chain as flat step list |
| `TitleExtractorStep` | Single step in the fallback chain |
| `EpisodeNumberExtractorForm` | Pattern + captureGroup + fallbackToRss |
| `EpisodeExtractorForm` | Source, pattern, groups, fallback fields |

### Modified components

| Component | Change |
|-----------|--------|
| `PlaylistForm` | Add GroupsForm, SortForm, ExtractorsForm below BooleanSettings. Remove AdvancedNote. |
| `PlaylistTabContent` | Restructure to side-by-side layout (form left, preview right) |
| Preview components | Enrich to show Groups, Sort, Extraction sections with new episode fields |
| `BooleanSettings` | Add yearHeaderMode select |

### RHF integration

- All new form components use `useFormContext()` to access the parent form
- Group definitions and composite sort rules use `useFieldArray` for dynamic lists
- Title extractor fallback chain uses `useFieldArray` with conversion to/from the recursive structure
- Existing Zod schema already covers all fields - no schema changes needed

## Implementation Order

1. Server: extend preview response with enriched episode fields
2. sp_react types: update PreviewResult and related types
3. Layout: restructure PlaylistTabContent to side-by-side
4. Forms: GroupsForm, SortForm, ExtractorsForm (can be parallel)
5. Preview panel: update to show 3 sections with enriched data
6. BooleanSettings: add yearHeaderMode
7. Remove AdvancedNote component
8. i18n: add labels and hints for all new form fields (EN + JA)
