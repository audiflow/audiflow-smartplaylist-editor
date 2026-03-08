# Form Reorganization: Separate Playlist-Level vs Group-Level Settings

## Problem

The playlist editor form mixes playlist-level settings with group-level settings, making it hard for users to understand which form fields apply to the entire seasons list vs individual groups within it.

## Approach

Reorganize form sections into logical categories with clear hierarchy. Use a "Display Overrides" sub-heading in group cards to distinguish group-level overrides from playlist-level defaults.

## Reorganized Form Structure

| # | Section | Fields | What changed |
|---|---------|--------|--------------|
| 1 | Basic Settings | id, displayName, priority | Removed resolverType |
| 2 | Structure | resolverType, contentType, nullSeasonGroupKey (rss only) | New section |
| 3 | Filters | titleFilter, excludeFilter, requireFilter | Unchanged |
| 4 | Display Options | episodeYearHeaders, showDateRange, showSortOrderToggle, showSeasonNumber, yearHeaderMode | Renamed from BooleanSettings |
| 5 | Sort | customSort rules (when contentType=groups) | Unchanged |
| 6 | Groups | group definition cards only | Removed contentType, nullSeasonGroupKey |
| 7 | Extractors | titleExtractor, episodeExtractor | Unchanged |

### Group Card Layout

- Top: id, displayName, pattern (group identity)
- "Display Overrides" sub-heading: episodeYearHeaders, showDateRange

## Component Changes

### playlist-form.tsx

- Split `BooleanSettings` into `StructureSettings` + `DisplayOptions`
- Reorder: BasicSettings, StructureSettings, FilterSettings, DisplayOptions, SortForm, GroupsForm, ExtractorsForm
- Remove `resolverType` from `BasicSettings`
- New `StructureSettings`: resolverType, contentType, nullSeasonGroupKey (rss)

### groups-form.tsx

- Remove contentType selector and nullSeasonGroupKey input (moved to StructureSettings)
- Component becomes purely about managing group definition cards

### group-def-card.tsx

- Add "Display Overrides" sub-heading above episodeYearHeaders and showDateRange checkboxes

### Translation keys

- Add: structureSettings, displayOptions, displayOverrides
