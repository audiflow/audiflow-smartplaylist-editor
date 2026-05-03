# Tri-state Toggle for Thumbnail Visibility Flags

## Summary

Convert the five `showThumbnail` / `showEpisodeThumbnail` checkboxes from
binary toggles to tri-state: **unset** (indeterminate / dash icon) →
**on** → **off** → **unset**. Unset writes nothing to the JSON, which
preserves the existing "absent = use default (show)" semantics in the
mobile app.

## Motivation

The just-shipped flags have three meaningful states in the data layer
(absent / true / false), but the UI collapses absent into "on". Editors
cannot tell whether a field is intentionally `true` or merely
default-true, and they cannot easily revert an explicit value to default
once set. Tri-state surfaces the difference and makes "use the schema /
playlist default" a first-class action.

## Design

### Cycle order

Click order on each toggle is:

```
unset (indeterminate) -> true (on) -> false (off) -> unset
```

Hover tooltip on the checkbox label reads (en):
"Click to cycle: default -> on -> off". (ja: same, localized.)

### Visual

Use shadcn's default `Checkbox` `data-state="indeterminate"` rendering
(horizontal dash icon). No custom styling required.

### Shared component

Add `packages/sp_react/src/components/ui/tri-state-checkbox.tsx`
wrapping shadcn's `Checkbox`:

```tsx
type TriState = boolean | undefined;

interface TriStateCheckboxProps {
  id: string;
  value: TriState;
  onChange: (next: TriState) => void;
}

export function TriStateCheckbox({ id, value, onChange }: TriStateCheckboxProps) {
  const checked: CheckedState = value === undefined ? 'indeterminate' : value;
  return (
    <Checkbox
      id={id}
      checked={checked}
      onCheckedChange={() => onChange(cycle(value))}
    />
  );
}

function cycle(value: TriState): TriState {
  if (value === undefined) return true;
  if (value === true) return false;
  return undefined;
}
```

Each call-site swaps the existing `<Checkbox>` for `<TriStateCheckbox>`
and replaces `?? true` reads with the raw value plus an
`onChange` that calls `setValue(path, next, { shouldDirty: true })`.

### Five call sites

| File | Path the toggle controls |
|------|--------------------------|
| `pattern-settings.tsx` | `showEpisodeThumbnail` |
| `tabs/display-settings-tab.tsx` (GroupsSubsection) | `groupItem.showThumbnail` (or per-group override path when `isSpecific`) |
| `tabs/display-settings-tab.tsx` (EpisodesSubsection) | `episodeItem.showThumbnail` (or per-group override path) |
| `group-def-card.tsx` | `${prefix}.groupItem.showThumbnail` (per-group override) |

### Schema and model adjustments

`showEpisodeThumbnail` (pattern-meta) currently collapses to a concrete
`bool` on both Rust and Zod sides. To preserve the unset state through
the round-trip, change:

- `crates/sp_core/src/models/pattern_meta.rs`:
  `pub show_episode_thumbnail: bool` (with `default_true` /
  `skip_serializing_if = is_true`) becomes
  `pub show_episode_thumbnail: Option<bool>` annotated
  `#[serde(skip_serializing_if = "Option::is_none")]`. Remove the now
  unused `default_true` / `is_true` helpers if no other field uses them.
- Constructor sites in `crates/sp_core/src/services/uniqueness.rs` and
  `crates/sp_core/tests/service_tests.rs` switch
  `show_episode_thumbnail: true` to `show_episode_thumbnail: None` (the
  test-data baseline becomes "unset", matching how a fresh editor save
  would now look).
- Existing serde tests in `pattern_meta.rs` are rewritten:
  `show_episode_thumbnail_defaults_to_true_when_absent` (defaults to
  `bool true`) becomes `show_episode_thumbnail_absent_deserializes_none`;
  `show_episode_thumbnail_omitted_when_default_true` becomes
  `show_episode_thumbnail_omitted_when_none`.
- `packages/sp_react/src/schemas/config-schema.ts`:
  `showEpisodeThumbnail: z.boolean().nullish().transform((v) => v ?? true)`
  becomes `z.boolean().optional()`. The inferred TS type changes from
  `boolean` to `boolean | undefined`.
- `packages/sp_react/src/mocks/fixtures.ts`,
  `packages/sp_react/src/components/editor/editor-layout.tsx`, and
  `packages/sp_react/src/routes/editor.index.tsx`: remove the
  `showEpisodeThumbnail: true` key now that it is optional.

The four `showThumbnail` fields already use the optional shape on both
sides; no schema or model change for them.

JSON Schema files (`pattern-meta.schema.json`,
`playlist-definition.schema.json`) are unchanged. The `default: true`
keyword stays — it documents what consumers should assume when the field
is absent and does not constrain the field's optionality.

### Save path

react-hook-form retains `undefined` values in the form state, but
`JSON.stringify` (and Zod output for `z.boolean().optional()`) drops
`undefined` keys. Combined with `skip_serializing_if = "Option::is_none"`
on the Rust side, an unset toggle round-trips as an absent JSON key end
to end.

### Convention drift note

After this change, `pattern-meta.json` mixes two flag shapes:
`yearGroupedEpisodes` stays as `bool` (default false, no UI demand for
tri-state), while `showEpisodeThumbnail` becomes `Option<bool>` (default
true, tri-state UI). The asymmetry is intentional — it follows from
which flags need to surface a "default" state — and is documented here
plus in the Rust struct's doc comment so it is not later "fixed" back to
`bool`.

## Validation

- New unit test for `cycle()`: `undefined -> true -> false -> undefined`
  (and a fourth call to confirm the loop closes cleanly).
- New component test for `TriStateCheckbox`: each click advances state;
  the rendered `data-state` attribute matches the expected `unchecked`
  / `checked` / `indeterminate`.
- Rewritten `pattern_meta.rs` serde tests as listed above.
- Existing call-site tests stay green; reaching `undefined` now also
  exercises the indeterminate render path.
- Repo-wide gates pass: `cargo test`, `cargo clippy -- -W warnings`
  (zero warnings), `pnpm test --run`, `npx oxlint` (no new warnings),
  `npx tsc -b --noEmit`, `make lint`, `make test`.

## Localization

Add one new key per locale (`en` and `ja`) under `editor.json` for the
hover tooltip:

- en: `triStateHint: "Click to cycle: default -> on -> off"`
- ja: `triStateHint: "クリックで切替: デフォルト -> オン -> オフ"`

The `TriStateCheckbox` reads this key and applies it as the `title`
attribute on the underlying input (and on the wrapping label via the
existing `HintLabel` is left as-is — the hint icon already explains the
flag itself; the new tooltip explains the cycle).

## Non-goals

- Changing rendering behavior in the audiflow Flutter app (still
  consumes the same JSON; absence still means "show").
- Adding a separate "reset" affordance.
- Custom indeterminate iconography.
- Promoting `yearGroupedEpisodes` to tri-state.
