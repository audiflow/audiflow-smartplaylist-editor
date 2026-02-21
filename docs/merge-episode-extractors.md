# Merge episodeNumberExtractor into smartPlaylistEpisodeExtractor

## Summary

`episodeNumberExtractor` has been removed. Its functionality is now covered by
`smartPlaylistEpisodeExtractor` with two new/changed fields:

- `fallbackToRss: bool` (default: `false`) -- new
- `seasonGroup: int | null` (default: `1`) -- changed from non-nullable to nullable

## Rationale

Both extractors extracted episode numbers from text. `episodeNumberExtractor`
was a simpler, episode-number-only variant, while `smartPlaylistEpisodeExtractor`
already extracted both season and episode numbers. The only unique behavior was
RSS fallback, which is now absorbed into the unified extractor.

## Schema Changes

### Removed

The `episodeNumberExtractor` field on `SmartPlaylistDefinition` no longer exists.

```json
// REMOVED -- no longer valid
"episodeNumberExtractor": {
  "pattern": "\\[(\\d+)\\]",
  "captureGroup": 1,
  "fallbackToRss": true
}
```

### Changed: `smartPlaylistEpisodeExtractor`

| Field | Before | After |
|-------|--------|-------|
| `seasonGroup` | `int` (default: 1) | `int?` (default: 1, `null` = don't extract season) |
| `fallbackToRss` | -- | `bool` (default: false) |

All other fields are unchanged.

### `seasonGroup` semantics

| JSON value | Behavior |
|------------|----------|
| Key absent | `1` -- extract season from capture group 1 (backward compatible) |
| `"seasonGroup": 2` | Extract season from capture group 2 |
| `"seasonGroup": null` | Don't extract season (episode-only mode) |

### `fallbackToRss` semantics

When `true` and the primary pattern (and fallback pattern if configured) both
fail to match, the extractor returns the episode's RSS `episodeNumber` metadata
as a fallback. This replaces the behavior from the old `episodeNumberExtractor`.

## Migration Guide

### Config JSON migration

Replace `episodeNumberExtractor` with equivalent `smartPlaylistEpisodeExtractor`:

```json
// Before
{
  "episodeNumberExtractor": {
    "pattern": "\\[\\d+-(\\d+)\\]",
    "captureGroup": 2,
    "fallbackToRss": true
  }
}

// After
{
  "smartPlaylistEpisodeExtractor": {
    "source": "title",
    "pattern": "\\[\\d+-(\\d+)\\]",
    "seasonGroup": null,
    "episodeGroup": 2,
    "fallbackToRss": true
  }
}
```

Field mapping:

| episodeNumberExtractor | smartPlaylistEpisodeExtractor |
|------------------------|-------------------------------|
| `pattern` | `pattern` |
| `captureGroup` | `episodeGroup` |
| `fallbackToRss` | `fallbackToRss` |
| -- | `source`: always `"title"` |
| -- | `seasonGroup`: set to `null` |

### Mobile app (audiflow_domain) changes

The mobile app's `SmartPlaylistEpisodeExtractor` consumer needs:

1. Add `fallbackToRss` field (bool, default false) to the model/parser.
2. Make `seasonGroup` nullable. When null, skip season extraction.
3. When `fallbackToRss` is true and no pattern matches, return
   `episode.episodeNumber` from RSS metadata.
4. Remove all `EpisodeNumberExtractor` references (model, parser, consumer).
5. Any code that previously read `definition.episodeNumberExtractor` should
   now read `definition.smartPlaylistEpisodeExtractor` instead.

### Backward compatibility

Existing configs that only use `smartPlaylistEpisodeExtractor` (without
`episodeNumberExtractor`) require no migration. The new fields have backward-
compatible defaults:

- `seasonGroup` absent in JSON -> defaults to 1 (same as before)
- `fallbackToRss` absent in JSON -> defaults to false (no behavior change)
