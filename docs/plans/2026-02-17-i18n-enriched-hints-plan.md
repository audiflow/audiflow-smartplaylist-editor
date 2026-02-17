# i18n and Enriched Hints Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add react-i18next internationalization (English + Japanese) and enrich all field descriptions so users understand how to configure smart playlists.

**Architecture:** react-i18next with i18next-browser-languagedetector for auto-detection (fallback: English). Six JSON namespaces (common, editor, hints, preview, settings, feed) under `src/locales/{en,ja}/`. Components call `useTranslation(namespace)` to get translated strings.

**Tech Stack:** i18next, react-i18next, i18next-browser-languagedetector

---

### Task 1: Install i18n Dependencies

**Files:**
- Modify: `packages/sp_react/package.json`

**Step 1: Install packages**

Run: `cd packages/sp_react && pnpm add i18next react-i18next i18next-browser-languagedetector`

**Step 2: Verify install**

Run: `cd packages/sp_react && pnpm exec tsc --noEmit`
Expected: no errors

**Step 3: Commit**

```
feat: add i18n dependencies (i18next, react-i18next, language detector)
```

---

### Task 2: Create i18n Setup and English Translation Files

**Files:**
- Create: `src/lib/i18n.ts`
- Create: `src/locales/en/common.json`
- Create: `src/locales/en/editor.json`
- Create: `src/locales/en/hints.json`
- Create: `src/locales/en/preview.json`
- Create: `src/locales/en/settings.json`
- Create: `src/locales/en/feed.json`

**Step 1: Create `src/lib/i18n.ts`**

```typescript
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';

import commonEn from '@/locales/en/common.json';
import editorEn from '@/locales/en/editor.json';
import hintsEn from '@/locales/en/hints.json';
import previewEn from '@/locales/en/preview.json';
import settingsEn from '@/locales/en/settings.json';
import feedEn from '@/locales/en/feed.json';

void i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources: {
      en: {
        common: commonEn,
        editor: editorEn,
        hints: hintsEn,
        preview: previewEn,
        settings: settingsEn,
        feed: feedEn,
      },
    },
    fallbackLng: 'en',
    defaultNS: 'common',
    interpolation: { escapeValue: false },
    detection: { order: ['navigator'] },
  });

export default i18n;
```

**Step 2: Create `src/locales/en/common.json`**

Shared strings: buttons, nav, errors, auth.

```json
{
  "cancel": "Cancel",
  "retry": "Retry",
  "dismiss": "Dismiss",
  "generate": "Generate",
  "revoke": "Revoke",
  "help": "Help",
  "appTitle": "audiflow Smart Playlist Editor",
  "signInGithub": "Sign in with GitHub",
  "settings": "Settings",
  "createNew": "Create New",
  "unauthorized": "Unauthorized",
  "httpError": "HTTP {{status}}: {{text}}"
}
```

**Step 3: Create `src/locales/en/editor.json`**

Editor page strings organized by section.

```json
{
  "newConfig": "New Config",
  "editConfig": "Edit: {{configId}}",
  "autoSavedAt": "Auto-saved at {{time}}",
  "schemaDocs": "Schema Docs",
  "formMode": "Form Mode",
  "jsonMode": "JSON Mode",
  "viewFeed": "View Feed",
  "submitPr": "Submit PR",
  "runPreview": "Run Preview",
  "add": "Add",
  "playlistFallbackName": "Playlist {{number}}",
  "noPlaylists": "No playlists. Click \"Add\" to create one.",

  "patternSettings": "Pattern Settings",
  "configId": "Config ID",
  "podcastGuid": "Podcast GUID",
  "feedUrlsLabel": "Feed URLs (comma-separated)",
  "yearGroupedEpisodes": "Year Grouped Episodes",

  "basicSettings": "Basic Settings",
  "playlistId": "ID",
  "displayName": "Display Name",
  "resolverType": "Resolver Type",
  "selectResolver": "Select resolver",
  "priority": "Priority",

  "filters": "Filters",
  "titleFilter": "Title Filter",
  "excludeFilter": "Exclude Filter",
  "requireFilter": "Require Filter",

  "episodeYearHeaders": "Episode Year Headers",
  "showDateRange": "Show Date Range",
  "advancedNote": "Advanced fields (groups, extractors, sort) can be edited in JSON mode.",
  "removePlaylist": "Remove Playlist",

  "feedUrl": "Feed URL",
  "selectFeedUrl": "Select feed URL",
  "loadFeed": "Load Feed",

  "regexTest": "Test regex",
  "regexTestMatches": "Test regex ({{count}} matches)",
  "regexInvalid": "Invalid regex: {{error}}",
  "regexLoadFeed": "Load a feed to test regex against episode titles.",

  "tabPreviewEmpty": "Run preview to see results for this playlist.",

  "placeholderPatternId": "pattern-id",
  "placeholderGuid": "Optional GUID",
  "placeholderFeedUrls": "https://example.com/feed1.xml, https://example.com/feed2.xml",
  "placeholderPlaylistId": "playlist-id",
  "placeholderDisplayName": "My Playlist",
  "placeholderRegex": "Regex pattern",
  "placeholderFeedUrl": "https://example.com/feed.xml",

  "submitTitle": "Submit Configuration",
  "submitDescription": "Create a pull request on GitHub with your SmartPlaylist configuration.",
  "submitPattern": "Pattern: {{patternId}}",
  "submitting": "Submitting...",
  "submitSuccess": "Pull request created!",
  "openPr": "Open PR",
  "submitFailed": "Failed to submit: {{error}}",

  "draftFound": "Draft Found",
  "draftDescription": "A saved draft was found from {{savedAt}}. Would you like to restore it or discard it?",
  "draftDiscard": "Discard",
  "draftRestore": "Restore",
  "draftUnknownTime": "unknown time",

  "toastDraftRestoreFailed": "Failed to restore draft: {{error}}",
  "toastInvalidJson": "Invalid JSON: {{error}}",
  "toastEnterFeedUrl": "Enter a feed URL before running preview",
  "toastInvalidJsonPreview": "Invalid JSON: cannot run preview"
}
```

**Step 4: Create `src/locales/en/hints.json`**

Enriched descriptions that explain what, when, and why for each field.

```json
{
  "patternId": "A unique slug identifying this pattern config (e.g., 'my-podcast'). Used as the folder name in the config repository.",
  "podcastGuid": "The podcast's globally unique identifier from its RSS feed. When set, this takes priority over feed URL matching for more reliable identification.",
  "feedUrls": "One or more RSS feed URLs that identify this podcast. The app matches incoming feeds against these URLs to determine which pattern config to apply.",
  "yearGroupedEpisodes": "When enabled, the main episode list in the app groups episodes by their publication year with year headers.",

  "playlistId": "A unique slug for this playlist within the pattern (e.g., 'season-1'). Used as the filename in the config repository.",
  "displayName": "The name shown to users in the app. Choose something descriptive like 'Seasons' or 'Story Arcs'.",
  "resolverType": "Determines how episodes are grouped into this playlist. Each resolver uses a different strategy to organize episodes.",
  "resolverType_rss": "RSS Metadata: Groups episodes by their season number from RSS feed metadata. Best for podcasts that properly tag seasons in their feed (e.g., itunes:season).",
  "resolverType_category": "Category: Groups episodes by matching their titles against regex patterns you define in the 'groups' section. Use when episodes follow naming conventions like 'Arc 1: ...' or 'Mystery Series: ...'.",
  "resolverType_year": "Year: Groups episodes by their publication year. Good for long-running podcasts where yearly grouping is a natural fit.",
  "resolverType_titleAppearanceOrder": "Title Appearance Order: Groups episodes by a recurring pattern in their titles, ordered by when each pattern first appears in the feed. Useful for podcasts with titled story arcs or series.",
  "priority": "Controls the order in which this playlist appears relative to siblings. Lower numbers appear first. Episodes claimed by a higher-priority playlist are excluded from lower-priority ones.",

  "titleFilter": "A regex pattern to include episodes. Only episodes whose title matches this pattern are considered for this playlist. Leave empty to include all episodes.",
  "excludeFilter": "A regex pattern to exclude episodes. Episodes whose title matches this pattern are removed, even if they matched the title filter. Useful for filtering out trailers or bonus content.",
  "requireFilter": "A stricter regex that episodes must match to be included. Unlike title filter, this is applied after grouping and removes non-matching episodes from each group.",

  "episodeYearHeaders": "When enabled, episode lists within this playlist show year separator headers, helping users orient themselves in long episode lists.",
  "showDateRange": "When enabled, each group card displays the date range of its episodes (earliest to latest), giving users a quick sense of the group's timespan."
}
```

**Step 5: Create `src/locales/en/preview.json`**

```json
{
  "title": "Preview",
  "runPreview": "Run Preview",
  "idleMessage": "Run a preview to see how your configuration groups episodes.",
  "failed": "Preview failed: {{error}}",
  "ungroupedEpisodes": "Ungrouped Episodes",
  "episodes": "{{count}} episodes",
  "noGroups": "No groups",
  "totalLabel": "Total: ",
  "groupedLabel": "Grouped: ",
  "ungroupedLabel": "Ungrouped: ",
  "matchedLabel": "Matched: ",
  "claimedLabel": "Claimed: ",
  "lostLabel": "Lost to others: ",
  "claimedByOthers": "Claimed by other playlists ({{count}})",
  "claimedBy": "claimed by {{name}}"
}
```

**Step 6: Create `src/locales/en/settings.json`**

```json
{
  "apiKeys": "API Keys",
  "apiKeysDescription": "Manage API keys for programmatic access. Keys are shown only once after generation.",
  "keyNamePlaceholder": "Key name (e.g., CI pipeline)",
  "saveKeyWarning": "Save this key now. It will not be shown again.",
  "existingKeys": "Existing keys",
  "noKeysYet": "No API keys yet. Generate one above.",
  "createdAt": "Created {{date}}",
  "revokeTitle": "Revoke API key?",
  "revokeDescription": "Are you sure? This action cannot be undone. Any integrations using this key will stop working immediately.",
  "toastKeyGenerated": "API key generated",
  "toastKeyGenerateFailed": "Failed to generate API key",
  "toastKeyRevoked": "API key revoked",
  "toastKeyRevokeFailed": "Failed to revoke API key",
  "toastCopied": "Copied to clipboard",
  "toastCopyFailed": "Failed to copy to clipboard"
}
```

**Step 7: Create `src/locales/en/feed.json`**

```json
{
  "title": "Feed Viewer",
  "feedUrl": "Feed URL",
  "load": "Load",
  "loadFailed": "Failed to load feed: {{error}}",
  "filterPlaceholder": "Filter episodes by title...",
  "episodeCount": "{{filtered}} of {{total}} episodes",
  "columnTitle": "Title",
  "columnSeason": "Season",
  "columnEpisode": "Episode",
  "columnPublished": "Published",
  "noEpisodes": "No episodes found",
  "loadConfigFailed": "Failed to load config: {{error}}"
}
```

**Step 8: Verify TypeScript compiles**

Run: `cd packages/sp_react && pnpm exec tsc --noEmit`
Expected: no errors

**Step 9: Commit**

```
feat: add i18n setup and English translation files
```

---

### Task 3: Create Japanese Translation Files

**Files:**
- Create: `src/locales/ja/common.json`
- Create: `src/locales/ja/editor.json`
- Create: `src/locales/ja/hints.json`
- Create: `src/locales/ja/preview.json`
- Create: `src/locales/ja/settings.json`
- Create: `src/locales/ja/feed.json`

**Step 1: Create all six Japanese translation files**

Mirror every key from the English files with Japanese translations. The hints.json descriptions should be equally detailed and helpful in Japanese.

**Step 2: Register Japanese resources in `src/lib/i18n.ts`**

Add imports for all `ja/*.json` files and add a `ja` key to the `resources` object.

**Step 3: Verify TypeScript compiles**

Run: `cd packages/sp_react && pnpm exec tsc --noEmit`

**Step 4: Commit**

```
feat: add Japanese translation files
```

---

### Task 4: Wire i18n into App Entry Point and Test Setup

**Files:**
- Modify: `src/main.tsx`
- Modify: `src/test-setup.ts`

**Step 1: Import i18n in main.tsx**

Add `import '@/lib/i18n.ts';` near the top of `src/main.tsx` (before app renders). No provider wrapper needed - react-i18next auto-binds via `initReactI18next` plugin.

**Step 2: Initialize i18n in test-setup.ts**

Add a test i18n setup that loads English translations synchronously so tests can query by English text:

```typescript
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

import commonEn from '@/locales/en/common.json';
import editorEn from '@/locales/en/editor.json';
import hintsEn from '@/locales/en/hints.json';
import previewEn from '@/locales/en/preview.json';
import settingsEn from '@/locales/en/settings.json';
import feedEn from '@/locales/en/feed.json';

void i18n
  .use(initReactI18next)
  .init({
    resources: {
      en: {
        common: commonEn,
        editor: editorEn,
        hints: hintsEn,
        preview: previewEn,
        settings: settingsEn,
        feed: feedEn,
      },
    },
    lng: 'en',
    defaultNS: 'common',
    interpolation: { escapeValue: false },
  });
```

**Step 3: Run tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: all 81 tests still pass (no components changed yet)

**Step 4: Commit**

```
feat: wire i18n into app entry and test setup
```

---

### Task 5: Migrate Editor Components to i18n

**Files:**
- Modify: `src/components/editor/editor-layout.tsx`
- Modify: `src/components/editor/pattern-settings.tsx`
- Modify: `src/components/editor/playlist-form.tsx`
- Modify: `src/components/editor/hint-label.tsx`
- Modify: `src/components/editor/feed-url-input.tsx`
- Modify: `src/components/editor/submit-dialog.tsx`
- Modify: `src/components/editor/draft-restore-dialog.tsx`
- Modify: `src/components/editor/regex-tester.tsx`
- Modify: `src/components/editor/playlist-tab-content.tsx`
- Delete: `src/components/editor/field-hints.ts`

**Step 1: Update HintLabel**

Change `hint` prop from a string value to a translation key. Component calls `useTranslation('hints')` internally and renders `t(hint)`.

```tsx
import { useTranslation } from 'react-i18next';
// ...
export function HintLabel({ hint, children, ...props }: HintLabelProps) {
  const { t } = useTranslation('hints');
  if (!hint) {
    return <Label {...props}>{children}</Label>;
  }
  return (
    <div className="flex items-center gap-1">
      <Label {...props}>{children}</Label>
      <Tooltip>
        <TooltipTrigger type="button" tabIndex={-1} className="...">
          <CircleHelp className="h-3.5 w-3.5" />
          <span className="sr-only">{t('common:help')}</span>
        </TooltipTrigger>
        <TooltipContent side="top">{t(hint)}</TooltipContent>
      </Tooltip>
    </div>
  );
}
```

**Step 2: Update pattern-settings.tsx**

Add `const { t } = useTranslation('editor');` and replace all hardcoded strings with `t('key')` calls. Update HintLabel hint props from `FIELD_HINTS.xxx` to just the key string `"patternId"`, `"podcastGuid"` etc. Remove `field-hints.ts` import.

**Step 3: Update playlist-form.tsx**

Same pattern: add `useTranslation('editor')`, replace strings, update HintLabel hint props to key strings. Remove `field-hints.ts` import.

**Step 4: Update editor-layout.tsx**

Add `useTranslation('editor')`, replace all hardcoded strings including toast messages, button labels, headings, and fallback names.

**Step 5: Update remaining editor components**

- `feed-url-input.tsx`: `useTranslation('editor')` for labels/buttons
- `submit-dialog.tsx`: `useTranslation('editor')` for dialog text, buttons, states
- `draft-restore-dialog.tsx`: `useTranslation('editor')` for dialog text
- `regex-tester.tsx`: `useTranslation('editor')` for button text, errors, empty state
- `playlist-tab-content.tsx`: `useTranslation('editor')` for empty state

**Step 6: Delete `field-hints.ts`**

No longer needed; hints namespace replaces it.

**Step 7: Run tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: all tests pass (regex-tester.test.tsx tests match by regex `/test/i`, `/matches/i` etc. which should still work with English translations loaded in test-setup.ts)

**Step 8: Commit**

```
feat: migrate editor components to i18n
```

---

### Task 6: Migrate Preview Components to i18n

**Files:**
- Modify: `src/components/preview/preview-panel.tsx`
- Modify: `src/components/preview/playlist-tree.tsx`
- Modify: `src/components/preview/debug-info-panel.tsx`
- Modify: `src/components/preview/playlist-debug-stats.tsx`
- Modify: `src/components/preview/claimed-episodes-section.tsx`

**Step 1: Update all preview components**

Add `const { t } = useTranslation('preview');` to each component and replace hardcoded strings.

**Step 2: Run tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: all tests pass

**Step 3: Commit**

```
feat: migrate preview components to i18n
```

---

### Task 7: Migrate Feed, Settings, and Route Components to i18n

**Files:**
- Modify: `src/components/feed/feed-viewer.tsx`
- Modify: `src/components/settings/api-key-manager.tsx`
- Modify: `src/routes/browse.tsx`
- Modify: `src/routes/login.tsx`
- Modify: `src/routes/settings.tsx`
- Modify: `src/routes/editor.$id.tsx`

**Step 1: Update feed-viewer.tsx**

Add `useTranslation('feed')`, replace all strings. The existing feed-viewer.test.tsx queries by `getByLabelText('Feed URL')` which maps to `t('feedUrl')` - since test-setup loads English, this still works.

**Step 2: Update api-key-manager.tsx**

Add `useTranslation('settings')`, replace all strings including toast messages and dialog text.

**Step 3: Update route components**

- `browse.tsx`: `useTranslation('common')` + `useTranslation('editor')` for headings, buttons, error/empty states
- `login.tsx`: `useTranslation('common')` for app title and sign-in button
- `settings.tsx`: `useTranslation('common')` for heading
- `editor.$id.tsx`: `useTranslation('feed')` for error message (uses `loadConfigFailed` key)

**Step 4: Update api/client.ts error messages**

Add `import i18n from '@/lib/i18n.ts'` and use `i18n.t('httpError', { status, text })` and `i18n.t('unauthorized')` for thrown Error messages. This uses `i18n.t()` directly (not the hook) since `client.ts` is not a React component.

**Step 5: Run tests**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: all tests pass

**Step 6: Verify build**

Run: `cd packages/sp_react && pnpm exec tsc --noEmit`
Expected: no errors

**Step 7: Commit**

```
feat: migrate feed, settings, and route components to i18n
```

---

### Task 8: Final Verification and Bookmark

**Step 1: Run full test suite**

Run: `cd packages/sp_react && pnpm test -- --run`
Expected: all tests pass

**Step 2: TypeScript check**

Run: `cd packages/sp_react && pnpm exec tsc --noEmit`
Expected: no errors

**Step 3: Verify no remaining hardcoded English in components**

Spot-check a few component files to confirm all user-visible strings use `t()`.

**Step 4: Create jj bookmark**

Run: `jj bookmark create feat/i18n-enriched-hints`
