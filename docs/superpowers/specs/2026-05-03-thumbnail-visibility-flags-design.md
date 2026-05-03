# Thumbnail Visibility Flags

## Summary

Add boolean flags to control whether thumbnails render on entries within
three list contexts: the native podcast Episodes tab, the smartplaylist
group list, and the per-group episode list. Defaults preserve current
behavior (thumbnails shown).

## Motivation

Some podcasts (e.g., COTEN RADIO) want thumbnails on the native Episodes
tab and on group cards but not on episodes shown inside a group, where
the surrounding group context already conveys the artwork. Other
podcasts (e.g., Nagara Nikkei) want no thumbnails on any list entry
because the podcast artwork is uniform and adds no information per row.
There is currently no way to express either preference; the editor has
no flag to set, and the mobile app has no signal to read.

The page header always renders the artwork regardless of these flags.

## Design

### Schema additions

Add three new boolean fields, each defaulting to `true` to preserve the
current "always show thumbnails" behavior.

#### 1. `pattern-meta.schema.json`

Add `showEpisodeThumbnail: boolean` at the root of the pattern meta
object, alongside `yearGroupedEpisodes`.

- Controls thumbnails on the native podcast Episodes tab.
- Default `true`.
- Naming is qualified ("Episode") because the pattern scope has multiple
  potential thumbnail sources; `yearGroupedEpisodes` follows the same
  qualified style at this layer.

#### 2. `playlist-definition.schema.json` -- `GroupItemConfig`

Add `showThumbnail: boolean` to `GroupItemConfig`.

- Controls thumbnails on each group card in the group list.
- Default `true`.
- Sits alongside existing item-level toggles (`showDateRange`,
  `pinToYear`, `prependSeasonNumber`).

#### 3. `playlist-definition.schema.json` -- `EpisodeItemConfig`

Add `showThumbnail: boolean` to `EpisodeItemConfig`.

- Controls thumbnails on each episode row inside a group.
- Default `true`.

#### Per-group overrides

Extend the inline override objects on `GroupDef`:

- `GroupDef.groupItem.showThumbnail` (override the playlist default for
  this specific group's card)
- `GroupDef.episodeItem.showThumbnail` (override the playlist default
  for episodes inside this specific group)

Same shape and semantics as the existing override fields
(`GroupDef.groupItem.showDateRange`,
`GroupDef.episodeListing.showYearHeaders`).

### Resulting configs

COTEN RADIO:

```jsonc
// patterns/<coten>/meta.json
{ "showEpisodeThumbnail": true /* or omit */ }

// patterns/<coten>/playlists/<id>.json
{
  "groupItem":   { /* showThumbnail omitted -> true */ },
  "episodeItem": { "showThumbnail": false }
}
```

Nagara Nikkei:

```jsonc
// patterns/<nagara>/meta.json
{ "showEpisodeThumbnail": false }

// patterns/<nagara>/playlists/<id>.json
{
  "groupItem":   { "showThumbnail": false },
  "episodeItem": { "showThumbnail": false }
}
```

### Component changes

| Layer | Change |
|-------|--------|
| `crates/sp_core/assets/pattern-meta.schema.json` | Add `showEpisodeThumbnail` property (boolean, default true). |
| `crates/sp_core/assets/playlist-definition.schema.json` | Add `showThumbnail` to `GroupItemConfig`, `EpisodeItemConfig`, and the inline override objects on `GroupDef`. |
| `crates/sp_core/src/models/` (pattern meta + `playlist_definition.rs`) | Add fields with `serde` defaults so omitted JSON deserializes to `true`. |
| `packages/sp_react/src/schemas/config-schema.ts` | Add fields to `groupItemConfigSchema`, `episodeItemConfigSchema`, `groupDefSchema.groupItem`, `groupDefSchema.episodeItem`, and the pattern config schema. |
| `packages/sp_react/` editor UI | Add a thumbnail toggle to (a) the pattern meta form near `yearGroupedEpisodes`, (b) the playlist `groupItem` section near `showDateRange`, (c) the playlist `episodeItem` section, and (d) the per-group override panels. |
| `docs/schema-reference.md` | Document the three new fields. |
| Generated schema HTML | Regenerate via `make schema-doc`. |
| Sibling repo coordination (`docs/integration/`) | Note that the field is additive and defaults preserve current behavior, so existing data files remain valid. |

### Defaults and backward compatibility

- All three flags default to `true`. Existing JSON files in the data
  repo remain valid with no migration; the assembled config behaves as
  before until a flag is set to `false`.
- No `dataVersion` semantic break is required, but per the existing
  contract any change to a pattern's files bumps the pattern's
  `dataVersion` via CI.
- Out of scope: actual rendering changes in the audiflow Flutter app.
  The app will pick up the flags in a separate change. Until then the
  flag has no visible effect.

## Validation

- `cargo test` and `cargo clippy -- -W warnings` (zero warnings) pass.
- New unit tests cover serde round-trip with the field absent (defaults
  to `true`), present and `true`, and present and `false`, for both
  pattern meta and playlist definition.
- React tests cover Zod parsing of fixtures with the field absent and
  present.
- `cd packages/sp_react && pnpm test -- --run`, `npx oxlint`, and
  `npx tsc -b --noEmit` pass.
- `make lint` and `make test` pass.

## Non-goals

- Changing rendering behavior of the audiflow mobile app.
- Per-episode (not per-group) thumbnail control.
- Switching to a negative-form flag (`hideThumbnail`); positive defaults
  match the existing `show*` family.
