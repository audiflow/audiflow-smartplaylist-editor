# v5 Editor Form Restructure Design

## Problem

The editor's current 5-tab form (Basic | Filters | Episode List | Organize | Display) was
designed against the v4 schema. With v5, fields were renamed and reorganized around a
clearer processing pipeline (`episodeFilters -> grouping -> selector -> groupListing/groupItem
-> episodeListing/episodeItem`), and new concepts like `selector.partitionBy` were added.
The form layout no longer maps cleanly to the mental model users form when configuring a
playlist.

Additionally, the preview area does not emulate the app's mobile rendering, and there is
no visual link between the form field the user is editing and the region of the preview
that field affects — users must mentally translate between a form field and "where this
shows up in the app".

## Goals

1. Restructure tabs so the flow matches a natural mental model: **identity → content →
   structure → presentation**.
2. Represent the v5 pipeline accurately without forcing users to learn it as a pipeline.
3. Make the bridging role of `selector` explicit rather than hidden between sections.
4. Separate playlist-level fields from per-group overrides so the two scopes never
   bleed into each other.
5. Upgrade the preview panel to mobile-width rendering with highlight sync between form
   inputs and preview regions.

## Non-goals

- Schema changes. v5 is finalized; this work consumes it.
- Pattern data migration. Patterns in the data repo are already v5.
- Changes to the pattern-level settings card (feed URLs, pattern displayName, podcast GUID).
- Changes to preview computation logic (filter/group/sort pipeline). Only rendering and
  highlight sync are in scope.

## Tab Structure

**4 tabs**, down from 5, in order:

| Order | Tab    | Schema fields                                                                                                                                                 | Purpose                                  |
|-------|--------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------|
| 1     | Basic  | `id`, `displayName`                                                                                                                                            | Identity — "What am I making?"           |
| 2     | Filters | `episodeFilters.require`, `episodeFilters.exclude`                                                                                                            | Content — "What goes in?"                |
| 3     | Organize | `grouping.by`, `grouping.numberingExtractor`, `grouping.staticClassifiers`, `grouping.discoveryHint`, `selector.partitionBy`                                 | Structure — "How is it organized?"       |
| 4     | Display | `selector.titleExtractor`, `groupListing`, `groupItem`, `episodeListing`, `episodeItem`                                                                      | Presentation — "How does it look?"       |

Changes from the current layout:

- **Episode List tab removed.** Its fields (`episodeListing.sort`, `episodeItem.titleExtractor`)
  move to the Display tab as the "Episodes" section.
- **Organize gains `selector.partitionBy`.** The partition mode is a structural decision
  (what counts as a top-level navigation entry), so it belongs in Organize.
- **Display gains a selector bridge banner** containing `selector.titleExtractor` and
  displaying the current `partitionBy` as read-only context.
- **`priority` is not shown.** It is auto-assigned from the playlist tab array order
  (reorder UI at the playlist switcher level).

### Scope separation within Organize and Display

Both Organize and Display contain fields at two scopes:

- **Playlist-only** — applies to the whole playlist. Cannot be overridden per group.
- **Scopeable (playlist default with optional per-group override)** — for
  `titleClassifier`, individual `staticClassifiers[i]` entries can override these fields.
  For other grouping types, only the playlist default is editable.

These are rendered as two visually distinct zones in each tab:

- **Blue zone** ("Playlist-level") at the top: always visible, hosts playlist-only fields.
- **Amber zone** ("Group settings") below: always visible, hosts scopeable fields.
  - When `grouping.by = titleClassifier`: a group context bar activates inside this zone,
    letting the user scope edits to "All groups (edit defaults)" or a specific group.
  - For other grouping types: the context bar is absent; the zone shows only the playlist
    defaults (same fields, no override mechanism).

Fields by zone on each tab:

**Organize — blue zone (playlist-level)**
- `grouping.by`
- `grouping.discoveryHint` (conditional: when `by = titleDiscovery`)
- `selector.partitionBy`

**Organize — amber zone (group settings)**
- Context bar (titleClassifier only): "All groups (edit defaults)" chip + one chip per `staticClassifiers[i]` + "Add group"
- When context is "All groups" (or any non-titleClassifier grouping): default `grouping.numberingExtractor`
- When context is a specific group: `staticClassifiers[i].id`, `.displayName`, `.pattern`, and an optional `numberingExtractor` override

**Display — selector bridge banner (top, yellow)**
- Read-only: current `selector.partitionBy` value ("set in Organize")
- `selector.titleExtractor` (when `partitionBy` is `seasonNumber` or `year`)

**Display — blue zone (playlist-level)**
- `groupListing.sort`
- `groupListing.userSortable`
- `groupListing.yearBinding`

**Display — amber zone (group settings)**
- Context bar (titleClassifier only, shared state with Organize)
- Split into two subsections inside the amber zone:
  - **Groups subsection** — `groupItem.*` and `groupListing.yearBinding`
  - **Episodes subsection** — `episodeListing.*`, `episodeItem.titleExtractor`

  > Note: per the v5 schema, not every field here is individually overridable via
  > `staticClassifiers[i]`. Overridable fields: `display.showDateRange`,
  > `display.yearBinding`, `episodeList.sort`, `episodeList.showYearHeaders`,
  > `episodeList.titleExtractor`, and `numberingExtractor`. Fields without a per-group
  > override path (`groupItem.pinToYear`, `groupItem.prependSeasonNumber`,
  > `groupItem.titleExtractor`, `groupListing.sort`, `groupListing.userSortable`) are
  > rendered as read-only/disabled when a specific group is scoped, with an inline
  > note "set at playlist level". The implementation plan decides whether these
  > fields move to the blue zone or stay in the amber zone as read-only in group
  > scope.
- When context is "All groups" (or any non-titleClassifier grouping): editing updates playlist defaults.
- When context is a specific group: editing writes to that group's `display.*` and `episodeList.*` overrides. Fields without an override show an inherit note; fields with an override show the override badge.

### Group context state

A new piece of state: the "active group context" for a given playlist.

- Stored per playlist (reset when user switches playlist tab).
- Default value: "All groups" (a sentinel).
- Persists across Organize ↔ Display tab switches within the same playlist.
- Changing `grouping.by` away from `titleClassifier` resets the context to "All groups"
  and hides the context bar (the amber zone itself remains visible, showing playlist
  defaults only).
- The context bar is the only control that changes this state. Add/remove/reorder groups
  happens via explicit actions on the context bar (not implicit via field interaction).

## Preview Panel

### Mobile-width rendering

The preview renders at the app's mobile breakpoint width, using the same component tree
the app uses for that viewport. No device chrome (no phone frame). The preview column's
CSS width constrains the render; all layout decisions come from the app's own responsive
rules.

### Two-tier highlight sync

**Tier 1 — Tab-level persistent outline.** While a tab is active, the preview region
corresponding to that tab stays outlined:

| Tab                | Outlined preview region                    |
|--------------------|--------------------------------------------|
| Basic              | Playlist header (name area)                |
| Filters            | Episode count / filtered-episodes panel    |
| Organize           | Group list structure                       |
| Display > Groups   | Group cards area (playlist-level or scoped group card) |
| Display > Episodes | Episode rows area within an expanded group |

**Tier 2 — Field-level pulse.** Focusing a form field briefly (≈1 second) pulses the
corresponding preview element. Examples:

- Focus `groupListing.sort` → pulse the group ordering
- Focus `episodeItem.titleExtractor` → pulse episode titles
- Focus a group's `displayName` → pulse that specific group card

**Selector bridge highlight.** When the user hovers or focuses the selector bridge
banner, the partition-entry area and the group-list area highlight together, showing
the bridging role.

**Per-group scope highlight.** When the group context bar has a specific group selected,
that group's card highlights in the preview (amber ring) in addition to the tab-level
outline.

### Wiring mechanism

Form inputs declare their preview target via data attributes or a hook:
`data-preview-field="groupListing.sort"`. The preview renders elements with matching
`data-preview-field` / `data-preview-region` attributes. A small event bus in the editor
store bridges focus events to highlight state.

## Interaction Rules

1. **Group context is per-playlist** and resets on playlist tab switch.
2. **Group context persists** across Organize ↔ Display switches.
3. **Amber zone always renders.** The group context bar inside it is gated on
   `grouping.by = titleClassifier`; for other grouping types the zone shows only
   playlist defaults with no override mechanism.
4. **Add/remove/reorder groups** happens through explicit controls in the context bar;
   never as a side-effect of clicking a chip.
5. **Override badge** appears next to per-group fields whose value differs from the
   playlist default.
6. **Inherit note** appears on per-group fields currently inheriting the default.
7. **Priority is read-only** and derived from playlist array position. Reordering
   playlist tabs updates priority automatically.

## Migration & Implementation Scope

### Files to change

`packages/sp_react/src/components/editor/`
- `playlist-form.tsx` — tab definitions (5 → 4), new tab order, remove Episode List reference.
- `tabs/basic-settings-tab.tsx` — remove any `priority` field; confirm read-only ID and editable displayName.
- `tabs/episode-filter-tab.tsx` — reposition only; no structural change.
- `tabs/resolver-tab.tsx` → rename to `organize-tab.tsx`; introduce blue/amber scope zones; add `selector.partitionBy` block; integrate group context bar; keep conditional sections driven by `grouping.by`.
- `tabs/episode-list-tab.tsx` — **delete**; merge its fields into the Display tab's Episodes section.
- `tabs/display-settings-tab.tsx` — rebuild with: selector bridge banner (top), blue zone (groupListing), amber zone (Groups + Episodes subsections, scoped by context bar).

New shared components under `components/editor/shared/`:
- `group-context-bar.tsx` — renders chips, owns add/remove/reorder actions.
- `scope-zone.tsx` — the colored wrapper for blue/amber zones; handles collapse and scope labeling.
- `selector-bridge.tsx` — yellow banner with read-only partitionBy + editable titleExtractor.

### State changes

- Add `activeGroupContext` state per playlist to the Zustand editor store (or equivalent).
  Default: `"all"`. Valid values: `"all" | <staticClassifier id>`.
- Reset on playlist tab switch and on `grouping.by` change to non-titleClassifier.
- Expose a `setActiveGroupContext(playlistId, context)` action.

Preview highlight state:
- `activePreviewRegion: string | null` (tab-level outline)
- `activePreviewField: string | null` (field-level pulse, auto-clears on a timer)
- Actions to set/clear both.

### i18n (`locales/{en,ja}/editor.json`)

Remove:
- `tab.episodeList`

Add:
- `tab.organize` (replaces `tab.resolver`)
- `scope.playlist`, `scope.pergroup`
- `context.allGroups`, `context.addGroup`
- `bridge.selector.title`, `bridge.selector.partitionBy`
- `override.badge`, `override.inherit`

Keep others as-is; update any references to the removed Episode List tab.

### Preview changes

`packages/sp_react/src/components/editor/preview/*`
- Constrain preview render width to the app's mobile breakpoint.
- Add `data-preview-region` / `data-preview-field` attributes to relevant nodes.
- Subscribe to highlight state; render outlines and pulses.

## Testing Approach

### Component tests (Vitest + RTL)

- Tab order and labels render for both locales.
- Switching `grouping.by` shows/hides the amber zone correctly in Organize and Display.
- Group context bar chips reflect `staticClassifiers` state and persist selection across
  Organize ↔ Display.
- Selecting "All groups" writes to playlist defaults; selecting a group writes to
  `staticClassifiers[i]`.
- Override badges render when a per-group value differs from the default.
- Selector bridge banner renders the current `partitionBy` value and hides unused fields.
- Changing `grouping.by` from `titleClassifier` to another value resets the group context
  and clears the amber zone.

### Integration tests

- Load a v5 pattern; switch through all four tabs without console errors.
- Edit a field with a group scoped: output writes to `staticClassifiers[i].*` path, not
  playlist defaults.
- Edit a field with "All groups": output writes to playlist-level path.
- Form UI → JSON mode round-trip produces byte-equivalent output to the original.

### Visual / preview tests

- Preview renders at mobile breakpoint width (verify CSS).
- Tab change updates `activePreviewRegion` and outlines the expected region.
- Field focus pulses the expected element.
- Selector bridge hover/focus highlights both partition and group list areas.

### Regression

- Existing patterns (e.g., Coten Radio レギュラー/ショート/その他) load, render, and save
  without validation errors or canonical-order drift.
- Saved files preserve v5 canonical field order (identity → pipeline).

## Open Questions

None blocking. Deferred items that may warrant follow-up design:

- Progressive disclosure / collapsible Display sections (Option C from brainstorm).
- Drag-and-drop reorder UX for static classifiers (currently spec says explicit controls
  in the context bar; full interaction design for reorder is deferred).
- Shared highlight protocol for hover-based previewing (e.g., hovering a chip highlights
  the corresponding group card without needing to focus a field).

## References

- v5 schema: `packages/sp_core/assets/schema/playlist-definition.schema.json`
- Previous layout spec: `docs/superpowers/specs/2026-04-09-tab-layout-design.md`
- Data repo memory: `project_v5_schema_design.md` (pipeline-ordered fields, selector.partitionBy)
