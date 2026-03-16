# React Testing Strategy

Date: 2026-03-16
Goal: Add test coverage to sp_react for refactoring confidence and regression prevention.

## Current State

16 test files exist covering schemas, utilities, store, and a handful of components.
Most editor components (15+), hooks (2), and the query layer are untested.

Infrastructure is already set up: Vitest + jsdom + @testing-library/react + i18n test setup.

## Infrastructure Additions

### New dependency

- `msw` (Mock Service Worker) - intercept fetch at the service worker level so TanStack Query
  works naturally in tests (loading states, caching, error handling).

### New files

| File | Purpose |
|------|---------|
| `src/mocks/handlers.ts` | MSW request handlers for all sp_server endpoints |
| `src/mocks/server.ts` | MSW `setupServer()` instance, wired into vitest lifecycle |
| `src/mocks/fixtures.ts` | Reusable typed test data (valid pattern, minimal pattern, invalid pattern) |
| `src/test-utils.tsx` | Custom `render()` wrapping QueryClientProvider + ApiClientProvider + I18nextProvider |

### Changes to existing files

- `src/test-setup.ts` - Import and start MSW server (`beforeAll`, `afterEach`, `afterAll`)

### test-utils.tsx design

```tsx
function renderWithProviders(
  ui: ReactElement,
  options?: { queryClient?: QueryClient },
): RenderResult;
```

Creates a fresh `QueryClient` per test (retry: false, gcTime: 0) to prevent state leaking.
Wraps in `ApiClientProvider` with a client pointing at the MSW-intercepted base URL.
Wraps in `I18nextProvider` (already initialized in test-setup.ts).

No router wrapper by default - most component tests don't need routing. Tests that do
can wrap with `createMemoryRouter` explicitly.

### MSW handlers

Default handlers return successful responses with fixture data. Tests override individual
handlers via `server.use()` for error scenarios and edge cases.

Endpoints to mock:

| Endpoint | Default response |
|----------|-----------------|
| `GET /api/configs/patterns` | Array of 2 PatternSummary fixtures |
| `GET /api/configs/patterns/identifiers` | Array of 2 PatternIdentifiers fixtures |
| `GET /api/configs/patterns/:id/assembled` | Full PatternConfig fixture |
| `PUT /api/configs/patterns/:id/meta` | 200 OK |
| `POST /api/configs/patterns` | 201 Created |
| `DELETE /api/configs/patterns/:id` | 204 No Content |
| `PUT /api/configs/patterns/:id/playlists/:pid` | 200 OK |
| `DELETE /api/configs/patterns/:id/playlists/:pid` | 204 No Content |
| `GET /api/feeds?url=...` | FeedEpisode array fixture (10 episodes) |
| `POST /api/configs/preview` | PreviewResult fixture |
| `POST /api/configs/validate` | `{ valid: true }` |

### Fixtures

Typed with Zod `z.infer` types. Three levels:

- `VALID_PATTERN_CONFIG` - full PatternConfig with 2 playlists, groups, extractors
- `MINIMAL_PATTERN_CONFIG` - required fields only
- `FEED_EPISODES` - 10 episodes with varied metadata (some nullish fields)
- `PREVIEW_RESULT` - realistic preview output with groups and ungrouped episodes
- `PATTERN_SUMMARIES` - list of 2 pattern summaries
- `PATTERN_IDENTIFIERS` - list of 2 identifiers (for duplicate check tests)

## Priority Tiers

### Tier 1: High value (test first)

#### 1a. queries.ts - TanStack Query hooks (integration, MSW)

All 10 hooks. Test per hook:
- Success path: renders data after loading
- Error path: server returns 4xx/5xx, hook exposes error
- Mutations: `onSuccess` invalidates correct query keys (verify via `queryClient.getQueryState`)
- Conditional queries: `enabled: false` does not fire (useAssembledConfig with null id, useFeed with null url)

File: `src/api/__tests__/queries.test.ts`

#### 1b. use-duplicate-check.ts (unit)

Pure logic over cached data. Test cases:
- No identifiers loaded yet -> empty conflicts
- No duplicates -> empty conflicts
- Duplicate podcastGuid -> returns conflict with claimedBy
- Duplicate feedUrl -> returns conflict
- Both duplicated -> returns both conflicts
- Current pattern excluded from comparison (self-match)
- Duplicate across multiple other patterns (first match wins)

File: `src/hooks/__tests__/use-duplicate-check.test.ts`

#### 1c. use-file-events.ts (unit)

Mock `EventSource` globally. Test cases:
- Opens SSE connection on mount with correct URL
- Closes connection on unmount
- `patterns/meta.json` change -> invalidates `['patterns']` query
- `patterns/{id}/meta.json` change -> invalidates `['assembledConfig', id]`
- `patterns/{id}/playlists/{pid}.json` change -> invalidates `['assembledConfig', id]`
- Unrecognized path -> no invalidation
- Respects VITE_API_BASE_URL env variable

File: `src/hooks/__tests__/use-file-events.test.ts`

#### 1d. config-form.tsx (integration, MSW)

Central form orchestrator. Test cases:
- Renders with loaded config data (fields populated)
- Dirty flag set on field change
- Form submission calls correct mutation with form data
- Validation errors displayed for invalid input
- Loading state while fetching config

File: `src/components/editor/__tests__/config-form.test.tsx`

#### 1e. editor-layout.tsx (integration, MSW)

Navigation and lifecycle. Test cases:
- Back button resets editor store and navigates
- Conflict dialog appears when file changed externally (SSE event during editing)
- Tab switching between playlists
- New pattern vs edit existing pattern modes

File: `src/components/editor/__tests__/editor-layout.test.tsx`

### Tier 2: Medium value (test second)

#### 2a. groups-form.tsx + group-def-card.tsx (integration)

- Add new group -> card appears with default values
- Remove group -> card removed, array updated
- Edit group fields -> form data updated
- Minimum 1 group validation (if applicable)

File: `src/components/editor/__tests__/groups-form.test.tsx`

#### 2b. extractors-form.tsx + episode-extractor-form.tsx (integration)

- Add/remove extractor entries
- Primary + fallback pattern fields
- RSS fallback toggle
- Form data shape matches expected schema

File: `src/components/editor/__tests__/extractors-form.test.tsx`

#### 2c. playlist-form.tsx (integration)

- Create new playlist with required fields
- Edit existing playlist
- Resolver type selection changes available fields
- Validation on required fields

File: `src/components/editor/__tests__/playlist-form.test.tsx`

#### 2d. conflict-dialog.tsx (integration)

- Renders conflict details
- "Reload" action triggers config refetch
- "Keep editing" action dismisses dialog
- Dialog blocks interaction with underlying form

File: `src/components/editor/__tests__/conflict-dialog.test.tsx`

### Tier 3: Lower value (if time allows)

- `feed-url-input.tsx` - URL validation, add/remove URLs
- `pattern-settings.tsx` - podcastGuid, yearGroupedEpisodes toggle
- `sort-form.tsx` - sort field/order selection
- `json-editor.tsx` - skip (CodeMirror in jsdom is low ROI)
- Route components - skip (thin wrappers)

## Testing Patterns

### Integration tests (forms, queries)

```tsx
import { renderWithProviders } from '@/test-utils';
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { server } from '@/mocks/server';
import { http, HttpResponse } from 'msw';

it('shows error when save fails', async () => {
  server.use(
    http.put('/api/configs/patterns/:id/meta', () =>
      HttpResponse.json({ error: 'conflict' }, { status: 409 }),
    ),
  );

  renderWithProviders(<ConfigForm patternId="test-1" />);
  await userEvent.click(screen.getByRole('button', { name: /save/i }));
  await waitFor(() => {
    expect(screen.getByText(/conflict/i)).toBeInTheDocument();
  });
});
```

### Unit tests (hooks)

```tsx
import { renderHook, waitFor } from '@testing-library/react';
import { useDuplicateCheck } from '../use-duplicate-check';

// Wrap in QueryClientProvider + ApiClientProvider for usePatternIdentifiers dependency
it('detects duplicate podcastGuid', async () => {
  const { result } = renderHook(
    () => useDuplicateCheck('pattern-2', 'guid-1', []),
    { wrapper: TestWrapper },
  );
  await waitFor(() => {
    expect(result.current).toContainEqual({
      field: 'podcastGuid',
      value: 'guid-1',
      claimedBy: 'pattern-1',
    });
  });
});
```

### EventSource mock (for use-file-events)

```tsx
class MockEventSource {
  onmessage: ((event: MessageEvent) => void) | null = null;
  onerror: (() => void) | null = null;
  close = vi.fn();
  // Test helper to simulate server events
  simulateMessage(data: string) {
    this.onmessage?.(new MessageEvent('message', { data }));
  }
}
```

## Implementation Order

1. Infrastructure: install msw, create mocks/, test-utils.tsx, update test-setup.ts
2. Fixtures: build typed fixture data
3. Tier 1a: queries.ts tests
4. Tier 1b: use-duplicate-check tests
5. Tier 1c: use-file-events tests
6. Tier 1d: config-form tests
7. Tier 1e: editor-layout tests
8. Tier 2a-2d: remaining form component tests
9. Tier 3: optional lower-priority tests

Each step is independently mergeable. Tier 1 alone covers the highest-risk code.

## Estimated Test Count

| Tier | Files | Approximate test cases |
|------|-------|----------------------|
| Infrastructure | 4 new files | 0 (setup only) |
| Tier 1 | 5 test files | ~40-50 tests |
| Tier 2 | 4 test files | ~20-30 tests |
| Tier 3 | 2-3 test files | ~10-15 tests |
| **Total** | **13-16 new test files** | **~70-95 tests** |

## Conventions

- Test files go in `__tests__/` directories colocated with source (existing pattern)
- File naming: `{source-file}.test.ts` or `{source-file}.test.tsx`
- Each `describe` block maps to one exported function/component
- Arrange-Act-Assert structure
- No snapshot tests (brittle for refactoring)
- Tests must not depend on execution order
