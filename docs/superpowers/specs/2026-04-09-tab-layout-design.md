# Tab Layout & Instructional Notes Design

## Problem

The editor form has many inputs in a single scrolling page, making it hard for new
users to understand the roles and effects of each section. Existing tooltips on
individual fields are insufficient for users unfamiliar with the schema, particularly
around how field combinations interact.

## Goals

1. Visually categorize form fields into logical groups using tabs
2. Add always-visible notes (section overviews + inline interaction notes) so users
   understand both individual fields and how they combine
3. Support open-source users with no prior schema knowledge

## Tab Structure

6 horizontal tabs within the playlist form area. The existing form|preview split
layout is preserved — tabs replace the single scrolling form on the left side.

| Order | Tab Name | Fields | Accordions |
|-------|----------|--------|------------|
| 1 | 基本設定 | Playlist ID, Display Name, Priority | None |
| 2 | エピソードフィルタ | Require Filters, Exclude Filters | None |
| 3 | エピソードリスト | Episode Sort, Title Extractor | None |
| 4 | リゾルバー | Resolver Type, Playlist Structure, Numbering Extractor (conditional), Null Season Group Key (conditional) | Conditional sections use accordion |
| 5 | グループ | Group Sort, Group definition cards with override accordions | Existing accordion overrides preserved |
| 6 | 表示設定 | Show Year Headers, Show Date Range, User Sortable, Prepend Season Number, Year Binding | None |

### Tab order rationale

- Identity first (基本設定)
- Which episodes to include (エピソードフィルタ)
- How to display/sort episodes by default (エピソードリスト)
- How to classify episodes into groups (リゾルバー)
- Group definitions, informed by resolver choice (グループ)
- Visual presentation tweaks last, fine-tuning after structure is set (表示設定)

### Key grouping decisions

- **エピソードリスト is independent** of resolver type. It contains defaults (sort,
  title extractor) that can be overridden per group.
- **グループ and conditional fields in リゾルバー** relate to specific resolver types.
- **表示設定** is last because it's fine-tuning after the structural decisions are made.

## Notes & Instructions System

Two types of always-visible notes, integrated via the existing i18next infrastructure.

### Note types

1. **Section Overview (blue, left-bordered)** — one per tab, at the top. Explains
   what the category is for and the general concept.
2. **Interaction Note (amber, left-bordered)** — zero or more per tab, placed inline
   between related fields. Explains how combinations of settings work together.

### Visual treatment

- Section overview: `background: blue-tinted`, `border-left: 3px solid blue`
- Interaction note: `background: amber-tinted`, `border-left: 3px solid amber`
- Both use a small uppercase label ("About this section" / "How these interact")
- Always visible, not collapsible

### Notes per tab

**1. 基本設定**
- Overview: What ID/name/priority mean, how priority affects claim order

**2. エピソードフィルタ**
- Overview: What filters do, regex pattern basics
- Interaction: How require + exclude combine (placed between the two filter sections)

**3. エピソードリスト**
- Overview: These are defaults; groups can override them
- Interaction: How title extractor chain works (between extraction steps)

**4. リゾルバー**
- Overview: What resolvers do, how they classify episodes
- Interaction: Resolver type + playlist structure combinations
- Interaction: Why numbering extractor appears for seasonNumber

**5. グループ**
- Overview: What groups are, when they matter, override concept
- Interaction: How group overrides relate to episodeList defaults

**6. 表示設定**
- Overview: Visual presentation options, can be overridden per group
- Interaction: Year binding + show year headers relationship

### i18n keys

Extend the existing translation files with two new prefixes:

- `sectionNote.<tabName>` — section overview text
- `interactionNote.<tabName>.<topic>` — interaction note text

Use a new `notes` namespace (`locales/en/notes.json`, `locales/ja/notes.json`)
separate from field-level hints, since these are conceptually different content.

## Components

### New components

- `SectionNote` — styled wrapper for section overview notes. Props: `i18nKey`.
- `InteractionNote` — styled wrapper for interaction notes. Props: `i18nKey`.
- Tab panel components extracted from current `playlist-form.tsx`:
  - `BasicSettingsTab`
  - `EpisodeFilterTab`
  - `EpisodeListTab`
  - `ResolverTab`
  - `GroupsTab`
  - `DisplaySettingsTab`

### Modified components

- `PlaylistForm` — replace single scrolling layout with shadcn/ui `Tabs` component.
  Each `TabsContent` delegates to the corresponding tab panel component.

### Preserved components

- `HintLabel` / `HintIcon` — existing tooltips stay as-is. They explain individual
  fields. Notes explain concepts and combinations — complementary, not replacement.
- `GroupDefCard` — existing group card with accordion overrides, used within GroupsTab.
- `TitleExtractorForm`, `NumberingExtractorForm`, `SortForm` — reused within their
  new tab locations.

## Tab Validation Indicators

Show a small error dot/badge on tab labels when that tab contains validation errors.
This prevents the "did I fill everything?" confusion when errors are hidden in
non-active tabs.

## Live Preview Enhancements

### Auto-update with debounce

The preview panel auto-updates as the user edits form fields, debounced to avoid
excessive re-renders. No manual refresh button needed.

- Watch form values via React Hook Form's `watch()` or `useWatch()`
- Debounce interval: ~300-500ms after last keystroke
- Preview reflects current form state, not last-saved state

### Filtered Episodes tab

Add a second tab to the preview panel alongside the existing preview:

| Tab | Content |
|-----|---------|
| Filtered Episodes (new) | List of episodes that passed include/exclude filters |
| Preview (existing) | Live playlist preview as it appears in the app |

The filtered episodes tab shows the result of applying the current require/exclude
filters against the loaded feed. This gives immediate feedback on whether filters
are working as intended. Updates with the same debounce as the main preview.

### Default tab behavior

- **New playlist:** Filtered Episodes tab is shown initially.
- **Auto-switch to Preview:** For a new config, once a valid resolver configuration
  becomes available, the preview panel automatically switches to the Preview tab.
  This happens only once — subsequent edits to the resolver do not trigger another
  auto-switch.
- **Existing playlist:** Preserve last-used tab (or Filtered Episodes as default).

## Form State

React Hook Form state persists across tab switches naturally (components are not
unmounted). No additional state management needed.

## Out of Scope

- Changing the pattern-level settings card (stays above tabs as-is)
- Changing the JSON mode editor
- Rewriting tooltip content (existing HintLabel hints remain)
