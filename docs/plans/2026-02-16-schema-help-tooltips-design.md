# Schema Help Page and Form Tooltips

## Summary

Two features: (1) regenerate the schema HTML documentation page from the old sp_web app, (2) add hover tooltips on form inputs in the editor.

## Part 1: Schema Help Page

Regenerate static HTML using the existing `scripts/generate_schema_doc.sh` pipeline:

1. Run `scripts/generate_schema_doc.sh` to produce `schema.html` + `schema.json` in `packages/sp_react/public/docs/`
2. Vite serves `public/` as static assets, so `/docs/schema.html` works out of the box
3. Add `packages/sp_react/public/docs/` to `.gitignore` (generated artifacts)
4. Add a "Schema Docs" button in `EditorHeader` that opens `/docs/schema.html` in a new tab

## Part 2: Form Tooltips

Add info-icon tooltips next to form labels throughout the editor.

### Components

- **`tooltip.tsx`**: shadcn/ui Tooltip (Radix UI primitive)
- **`HintLabel`**: Wraps `<Label>` with an optional info icon + tooltip. Falls back to plain `<Label>` when no hint is provided.

### Hint Content

A `FIELD_HINTS` record maps field keys to description strings from `SmartPlaylistSchema`:

**Pattern-level fields**: id, podcastGuid, feedUrls, yearGroupedEpisodes
**Playlist-level fields**: id, displayName, resolverType, priority, titleFilter, excludeFilter, requireFilter, episodeYearHeaders, showDateRange

### Integration

Replace `<Label>` with `<HintLabel hint={FIELD_HINTS.xxx}>` in:
- `PatternSettingsCard` (4 fields)
- `PlaylistForm` BasicSettings (4 fields), FilterSettings (3 fields), BooleanSettings (2 fields)
