# React Rewrite Design: sp_web -> sp_react

## Overview

Rewrite the Flutter web client (sp_web, ~4,100 lines) as a React SPA (sp_react).
The Dart server (sp_server) and shared models (sp_shared) remain unchanged.
The React app is served as static files and talks directly to the existing Dart API.

## Tech Stack

| Layer | Choice |
|---|---|
| Build | Vite + React 19 + TypeScript |
| Styling | Tailwind CSS + shadcn/ui |
| Server state | TanStack Query |
| Client state | Zustand |
| Routing | TanStack Router (file-based) |
| Forms | React Hook Form + Zod |
| Code editor | CodeMirror 6 |
| Serving | SPA (static files) -> existing Dart server |

## Project Structure

```
packages/sp_react/
├── index.html
├── vite.config.ts
├── tsconfig.json
├── tailwind.config.ts
├── package.json
├── src/
│   ├── main.tsx                    # Entry point, providers
│   ├── app.tsx                     # Root component, router mount
│   ├── routes/
│   │   ├── __root.tsx              # Root layout (TanStack Router)
│   │   ├── login.tsx
│   │   ├── browse.tsx
│   │   ├── editor.tsx              # /editor (new)
│   │   ├── editor.$id.tsx          # /editor/:id (edit)
│   │   └── settings.tsx
│   ├── components/
│   │   ├── ui/                     # shadcn/ui components (owned source)
│   │   ├── editor/
│   │   │   ├── config-form.tsx
│   │   │   ├── playlist-form.tsx
│   │   │   ├── json-editor.tsx     # CodeMirror 6 wrapper
│   │   │   ├── regex-tester.tsx
│   │   │   ├── feed-url-input.tsx
│   │   │   └── submit-dialog.tsx
│   │   ├── preview/
│   │   │   ├── preview-panel.tsx
│   │   │   ├── playlist-tree.tsx
│   │   │   └── debug-info-panel.tsx
│   │   └── settings/
│   │       └── api-key-manager.tsx
│   ├── api/
│   │   ├── client.ts               # Fetch wrapper with JWT refresh
│   │   └── queries.ts              # TanStack Query hooks
│   ├── stores/
│   │   ├── auth-store.ts           # Zustand: tokens, login/logout
│   │   └── editor-store.ts         # Zustand: form/json mode, auto-save
│   ├── schemas/
│   │   └── config-schema.ts        # Zod schemas mirroring sp_shared models
│   ├── lib/
│   │   ├── draft-service.ts        # localStorage draft persistence
│   │   └── json-merge.ts           # Three-way merge (port from Dart)
│   └── types/
│       └── models.ts               # TypeScript interfaces for API responses
```

## API Client and Auth

### ApiClient

Fetch wrapper matching the current Dart ApiClient behavior:
- JWT Bearer token injection
- Silent token refresh on 401 with deduplication (same Completer pattern)
- Methods: GET, POST, PUT, DELETE
- JSON encoding/decoding

### Auth Flow (unchanged)

1. User clicks "Sign in with GitHub" -> navigates to `/api/auth/github?redirect_uri=...`
2. Server handles OAuth, redirects back with `?token=...&refresh_token=...`
3. `main.tsx` extracts tokens from URL search params on mount
4. Stores in Zustand auth store + localStorage
5. Cleans URL via `window.history.replaceState`
6. TanStack Router guard: no token -> `/login`, has token -> `/browse`

### Auth Store (Zustand)

```ts
interface AuthState {
  token: string | null;
  refreshToken: string | null;
  setTokens: (token: string, refreshToken: string) => void;
  logout: () => void;
}
```

### TanStack Query Hooks

```ts
usePatterns()              // GET /api/configs/patterns
useAssembledConfig(id)     // GET /api/configs/patterns/:id/assembled
useFeed(url)               // GET /api/feeds?url=...
usePreviewMutation()       // POST /api/configs/preview
useSubmitPr()              // POST /api/configs/submit
useApiKeys()               // GET /api/keys
useGenerateKey()           // POST /api/keys
useRevokeKey()             // DELETE /api/keys/:id
```

## Editor State Split

The current 428-line EditorController splits into three concerns:

### TanStack Query (server data)
- Fetching assembled config
- Fetching feed
- Running preview (mutation)
- Submitting PR (mutation)

### Zustand (local UI state)

```ts
interface EditorState {
  isJsonMode: boolean;
  feedUrl: string;
  lastAutoSavedAt: Date | null;
  pendingDraft: Draft | null;
  configVersion: number;
  toggleJsonMode: () => void;
  setFeedUrl: (url: string) => void;
  incrementConfigVersion: () => void;
}
```

### React Hook Form (config data)

```ts
const form = useForm<PatternConfig>({
  resolver: zodResolver(patternConfigSchema),
  defaultValues: assembledConfig,
});
```

Dynamic playlists via `useFieldArray` - replaces 9 TextEditingControllers per playlist.

### Auto-Save

```ts
const formValues = form.watch();
useEffect(() => {
  const timer = setTimeout(() => {
    draftService.save(configId, formValues);
    setLastAutoSavedAt(new Date());
  }, 2000);
  return () => clearTimeout(timer);
}, [formValues]);
```

### Form/JSON Mode Toggle

- To JSON: serialize `form.getValues()` to JSON string for CodeMirror
- To Form: parse JSON, validate with Zod, `form.reset(parsed)` on success

### Draft Restore

- On mount: check localStorage for pending draft
- Show shadcn `AlertDialog` with restore/discard options
- Restore: `form.reset(mergedDraft)` using three-way merge
- Three-way merge logic ported directly from Dart `JsonMerge` service

## Component Mapping

| Current Flutter Widget | React Equivalent |
|---|---|
| Card | shadcn `Card` |
| TextField / TextFormField | shadcn `Input`, `Textarea` |
| DropdownButton | shadcn `Select` |
| ExpansionTile | shadcn `Accordion` / `Collapsible` |
| AlertDialog / SubmitDialog | shadcn `Dialog`, `AlertDialog` |
| SegmentedButton (Form/JSON) | shadcn `Tabs` |
| CheckboxListTile | shadcn `Checkbox` + `Label` |
| MaterialBanner | shadcn `Alert` |
| SnackBar | Sonner `Toast` |
| CircularProgressIndicator | TanStack Query `isPending` |
| ListView with Cards | Card list / shadcn `Table` |
| SelectionArea | Native browser text selection |
| LayoutBuilder responsive | Tailwind `lg:` breakpoint prefix |

### PlaylistForm

Current: 507 lines, 9 TextEditingControllers per playlist.
React: ~200-250 lines with `useFieldArray`. Each playlist in a shadcn `Accordion` item.
All fields registered via `form.register('playlists.${index}.fieldName')`.

### RegexTester

- 300ms debounced regex compilation via custom hook
- Match highlighting via string split on regex -> `<span>` with Tailwind classes
- Sample titles as static array

### JsonEditor

- CodeMirror 6 with `@codemirror/lang-json`
- Built-in lint gutter for validation errors
- ~60 lines

### PreviewPanel + PlaylistTree

- Nested shadcn `Accordion` for 3-level tree
- TanStack Query `isPending`/`isError` for loading/error states

### Responsive Layout

```tsx
<div className="flex flex-col lg:flex-row">
  <div className="w-full lg:w-1/2">{/* editor */}</div>
  <div className="w-full lg:w-1/2">{/* preview */}</div>
</div>
```

Tabbed mode on small screens via shadcn `Tabs` + Tailwind breakpoint.

## Zod Schemas

Single source of truth for TypeScript types + runtime validation + form validation:

```ts
export const playlistDefinitionSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  resolverType: z.enum(['rssMetadata', 'category', 'year', 'titleAppearanceOrder']),
  contentType: z.enum(['episodes', 'groups']),
  priority: z.number().int(),
  titleFilter: z.string().optional(),
  excludeFilter: z.string().optional(),
  requireFilter: z.string().optional(),
  // ... remaining fields
});

export const patternConfigSchema = z.object({
  id: z.string(),
  podcastGuid: z.string().optional(),
  feedUrls: z.array(z.string()),
  playlists: z.array(playlistDefinitionSchema),
});

// Types derived - no duplication
export type PlaylistDefinition = z.infer<typeof playlistDefinitionSchema>;
export type PatternConfig = z.infer<typeof patternConfigSchema>;
```

Sync strategy: manually maintained. Same discipline as hand-written fromJson/toJson.

## What Ports, What Changes, What Gets Dropped

### Direct ports
- `JsonMerge` three-way merge -> `src/lib/json-merge.ts`
- `LocalDraftService` localStorage -> `src/lib/draft-service.ts`
- API endpoints and request/response shapes -> unchanged
- OAuth flow -> identical redirect-based flow

### Simpler in React
- Form state: 9 TextEditingControllers per playlist -> single RHF `useFieldArray`
- Responsive layout: LayoutBuilder -> Tailwind `lg:` prefix
- Text selection: explicit `SelectionArea` -> native browser behavior
- JSON editor: manual TextField + validation -> CodeMirror with built-in lint
- Loading/error states: manual flags -> TanStack Query `isPending`/`isError`

### Dropped entirely
- Riverpod providers/notifiers -> TanStack Query + Zustand
- GoRouter redirect logic -> TanStack Router `beforeLoad`
- `web` package for browser APIs -> native `window`, `localStorage`, `fetch`
- Flutter `MaterialApp`, `ThemeData` -> Tailwind config + shadcn theme
- `http` package -> native `fetch`

### Watch out for
- CodeMirror 6 setup has a learning curve (extensions-based architecture)
- shadcn Accordion nesting for 3-level playlist tree may need custom styling
- RHF + deeply nested field arrays need careful Zod schema design upfront
- Auto-save with `form.watch()` can cause excess re-renders if not scoped

### Estimated scale
- Current Flutter: 4,100 lines / 27 files
- Expected React: ~2,500-3,000 lines / ~25 files
