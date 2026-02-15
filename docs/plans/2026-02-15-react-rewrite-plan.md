# sp_react Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite the Flutter web client (sp_web) as a React SPA that talks to the existing Dart API server.

**Architecture:** Vite SPA with TanStack Router (file-based routing), TanStack Query for server state, Zustand for local UI state, React Hook Form + Zod for forms, CodeMirror 6 for JSON editing. shadcn/ui + Tailwind CSS for styling.

**Tech Stack:** React 19, TypeScript, Vite, Tailwind CSS, shadcn/ui, TanStack Query, TanStack Router, Zustand, React Hook Form, Zod, CodeMirror 6

**Design doc:** `docs/plans/2026-02-15-react-rewrite-design.md`

---

## Task 1: Project Scaffold

**Files:**
- Create: `packages/sp_react/package.json`
- Create: `packages/sp_react/tsconfig.json`
- Create: `packages/sp_react/tsconfig.app.json`
- Create: `packages/sp_react/tsconfig.node.json`
- Create: `packages/sp_react/vite.config.ts`
- Create: `packages/sp_react/index.html`
- Create: `packages/sp_react/src/main.tsx`
- Create: `packages/sp_react/src/vite-env.d.ts`

**Step 1: Create the Vite + React + TypeScript project**

```bash
cd /Users/tohru/Documents/src/projects/audiflow-smartplaylist-web/packages
pnpm create vite sp_react --template react-ts
```

**Step 2: Install core dependencies**

```bash
cd /Users/tohru/Documents/src/projects/audiflow-smartplaylist-web/packages/sp_react
pnpm add @tanstack/react-query @tanstack/react-router zustand react-hook-form @hookform/resolvers zod
pnpm add -D @tanstack/router-plugin @tanstack/router-devtools
```

**Step 3: Install Tailwind CSS v4**

```bash
pnpm add -D tailwindcss @tailwindcss/vite
```

Update `vite.config.ts`:

```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { TanStackRouterVite } from '@tanstack/router-plugin/vite';

export default defineConfig({
  plugins: [
    TanStackRouterVite({ quoteStyle: 'single' }),
    react(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      '@': '/src',
    },
  },
});
```

Create `src/index.css`:

```css
@import 'tailwindcss';
```

**Step 4: Initialize shadcn/ui**

```bash
pnpm add -D shadcn
pnpx shadcn@latest init
```

When prompted: style=new-york, base-color=neutral, css-variables=yes.

**Step 5: Install frequently used shadcn components**

```bash
pnpx shadcn@latest add button card input textarea select accordion tabs dialog alert-dialog alert checkbox label separator toast sonner badge
```

**Step 6: Create minimal main.tsx entry point**

```tsx
// src/main.tsx
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <div>sp_react scaffold works</div>
  </StrictMode>,
);
```

**Step 7: Verify the app runs**

```bash
pnpm dev
```

Expected: Browser opens with "sp_react scaffold works" text.

**Step 8: Commit**

```bash
jj new -m "feat: scaffold sp_react with Vite, React, Tailwind, shadcn/ui"
```

---

## Task 2: Zod Schemas and TypeScript Types

**Files:**
- Create: `packages/sp_react/src/schemas/config-schema.ts`
- Create: `packages/sp_react/src/schemas/api-schema.ts`
- Create: `packages/sp_react/src/schemas/__tests__/config-schema.test.ts`

**Step 1: Install test dependencies**

```bash
cd /Users/tohru/Documents/src/projects/audiflow-smartplaylist-web/packages/sp_react
pnpm add -D vitest @testing-library/react @testing-library/jest-dom jsdom
```

Add to `vite.config.ts`:

```ts
/// <reference types="vitest/config" />
// ... add to defineConfig:
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test-setup.ts',
  },
```

Create `src/test-setup.ts`:

```ts
import '@testing-library/jest-dom/vitest';
```

**Step 2: Write failing tests for config schema**

```ts
// src/schemas/__tests__/config-schema.test.ts
import { describe, it, expect } from 'vitest';
import {
  playlistDefinitionSchema,
  patternConfigSchema,
  smartPlaylistSortSpecSchema,
  type PlaylistDefinition,
  type PatternConfig,
} from '../config-schema';

describe('playlistDefinitionSchema', () => {
  it('parses a minimal valid definition', () => {
    const input = {
      id: 'playlist-1',
      displayName: 'My Playlist',
      resolverType: 'rssMetadata',
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.id).toBe('playlist-1');
    expect(result.priority).toBe(0);
    expect(result.episodeYearHeaders).toBe(false);
    expect(result.contentType).toBeUndefined();
  });

  it('parses a full definition with all optional fields', () => {
    const input = {
      id: 'playlist-2',
      displayName: 'Full Playlist',
      resolverType: 'category',
      priority: 5,
      contentType: 'groups',
      yearHeaderMode: 'firstEpisode',
      episodeYearHeaders: true,
      showDateRange: true,
      titleFilter: '^Season \\d+',
      excludeFilter: 'Bonus',
      requireFilter: 'Episode',
      nullSeasonGroupKey: 0,
      groups: [
        { id: 'g1', displayName: 'Group 1', pattern: '^S01' },
      ],
      customSort: {
        type: 'simple',
        field: 'newestEpisodeDate',
        order: 'descending',
      },
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.priority).toBe(5);
    expect(result.groups).toHaveLength(1);
  });

  it('rejects missing required fields', () => {
    expect(() => playlistDefinitionSchema.parse({})).toThrow();
    expect(() => playlistDefinitionSchema.parse({ id: 'x' })).toThrow();
  });
});

describe('patternConfigSchema', () => {
  it('parses a minimal config', () => {
    const input = {
      id: 'pattern-1',
      playlists: [],
    };
    const result = patternConfigSchema.parse(input);
    expect(result.yearGroupedEpisodes).toBe(false);
    expect(result.feedUrls).toBeUndefined();
  });

  it('parses config with playlists', () => {
    const input = {
      id: 'pattern-1',
      podcastGuid: 'abc-123',
      feedUrls: ['https://example.com/feed.xml'],
      yearGroupedEpisodes: true,
      playlists: [
        { id: 'p1', displayName: 'P1', resolverType: 'year' },
      ],
    };
    const result = patternConfigSchema.parse(input);
    expect(result.playlists).toHaveLength(1);
    expect(result.feedUrls).toEqual(['https://example.com/feed.xml']);
  });
});

describe('smartPlaylistSortSpecSchema', () => {
  it('parses simple sort', () => {
    const input = { type: 'simple', field: 'alphabetical', order: 'ascending' };
    const result = smartPlaylistSortSpecSchema.parse(input);
    expect(result.type).toBe('simple');
  });

  it('parses composite sort with condition', () => {
    const input = {
      type: 'composite',
      rules: [
        { field: 'playlistNumber', order: 'ascending' },
        {
          field: 'newestEpisodeDate',
          order: 'descending',
          condition: { type: 'sortKeyGreaterThan', value: 100 },
        },
      ],
    };
    const result = smartPlaylistSortSpecSchema.parse(input);
    expect(result.type).toBe('composite');
  });
});
```

**Step 3: Run tests to verify they fail**

```bash
pnpm test -- --run
```

Expected: FAIL - module not found.

**Step 4: Implement config schemas**

```ts
// src/schemas/config-schema.ts
import { z } from 'zod';

// --- Enums ---

export const sortFieldSchema = z.enum([
  'playlistNumber',
  'newestEpisodeDate',
  'progress',
  'alphabetical',
]);

export const sortOrderSchema = z.enum(['ascending', 'descending']);

export const contentTypeSchema = z.enum(['episodes', 'groups']);

export const yearHeaderModeSchema = z.enum([
  'none',
  'firstEpisode',
  'perEpisode',
]);

export const resolverTypeSchema = z.enum([
  'rssMetadata',
  'category',
  'year',
  'titleAppearanceOrder',
]);

// --- Sort ---

const sortConditionSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('sortKeyGreaterThan'),
    value: z.number(),
  }),
]);

const sortRuleSchema = z.object({
  field: sortFieldSchema,
  order: sortOrderSchema,
  condition: sortConditionSchema.nullish(),
});

export const smartPlaylistSortSpecSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('simple'),
    field: sortFieldSchema,
    order: sortOrderSchema,
  }),
  z.object({
    type: z.literal('composite'),
    rules: z.array(sortRuleSchema),
  }),
]);

// --- Group Definition ---

export const groupDefSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  pattern: z.string().nullish(),
  episodeYearHeaders: z.boolean().nullish(),
  showDateRange: z.boolean().nullish(),
});

// --- Extractors ---

export const titleExtractorSchema: z.ZodType = z.object({
  source: z.enum(['title', 'description', 'seasonNumber', 'episodeNumber']),
  pattern: z.string().nullish(),
  group: z.number().int().default(0),
  template: z.string().nullish(),
  fallback: z.lazy(() => titleExtractorSchema).nullish(),
  fallbackValue: z.string().nullish(),
});

export const episodeExtractorSchema = z.object({
  source: z.enum(['title', 'description']),
  pattern: z.string(),
  seasonGroup: z.number().int().default(1),
  episodeGroup: z.number().int().default(2),
  fallbackSeasonNumber: z.number().int().nullish(),
  fallbackEpisodePattern: z.string().nullish(),
  fallbackEpisodeCaptureGroup: z.number().int().default(1),
});

export const episodeNumberExtractorSchema = z.object({
  pattern: z.string(),
  captureGroup: z.number().int().default(1),
  fallbackToRss: z.boolean().default(true),
});

// --- Playlist Definition ---

export const playlistDefinitionSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  resolverType: z.string(),
  priority: z.number().int().default(0),
  contentType: contentTypeSchema.nullish(),
  yearHeaderMode: yearHeaderModeSchema.nullish(),
  episodeYearHeaders: z.boolean().default(false),
  showDateRange: z.boolean().default(false),
  titleFilter: z.string().nullish(),
  excludeFilter: z.string().nullish(),
  requireFilter: z.string().nullish(),
  nullSeasonGroupKey: z.number().int().nullish(),
  groups: z.array(groupDefSchema).nullish(),
  customSort: smartPlaylistSortSpecSchema.nullish(),
  titleExtractor: titleExtractorSchema.nullish(),
  episodeNumberExtractor: episodeNumberExtractorSchema.nullish(),
  smartPlaylistEpisodeExtractor: episodeExtractorSchema.nullish(),
});

// --- Pattern Config ---

export const patternConfigSchema = z.object({
  id: z.string(),
  podcastGuid: z.string().nullish(),
  feedUrls: z.array(z.string()).nullish(),
  yearGroupedEpisodes: z.boolean().default(false),
  playlists: z.array(playlistDefinitionSchema),
});

// --- Derived Types ---

export type PlaylistDefinition = z.infer<typeof playlistDefinitionSchema>;
export type PatternConfig = z.infer<typeof patternConfigSchema>;
export type SmartPlaylistSortSpec = z.infer<typeof smartPlaylistSortSpecSchema>;
export type GroupDef = z.infer<typeof groupDefSchema>;
export type TitleExtractor = z.infer<typeof titleExtractorSchema>;
export type EpisodeExtractor = z.infer<typeof episodeExtractorSchema>;
export type EpisodeNumberExtractor = z.infer<typeof episodeNumberExtractorSchema>;
```

**Step 5: Implement API response schemas**

```ts
// src/schemas/api-schema.ts
import { z } from 'zod';

// --- Pattern Summary (from GET /api/configs/patterns) ---

export const patternSummarySchema = z.object({
  id: z.string(),
  version: z.number().int(),
  displayName: z.string(),
  feedUrlHint: z.string(),
  playlistCount: z.number().int(),
});

export type PatternSummary = z.infer<typeof patternSummarySchema>;

// --- Pattern Meta (from GET /api/configs/patterns/:id) ---

export const patternMetaSchema = z.object({
  version: z.number().int(),
  id: z.string(),
  podcastGuid: z.string().nullish(),
  feedUrls: z.array(z.string()),
  yearGroupedEpisodes: z.boolean().default(false),
  playlists: z.array(z.string()),
});

export type PatternMeta = z.infer<typeof patternMetaSchema>;

// --- Feed Episode (from GET /api/feeds) ---

export const feedEpisodeSchema = z.object({
  id: z.number(),
  title: z.string(),
  description: z.string().nullish(),
  guid: z.string().nullish(),
  publishedAt: z.string().nullish(),
  seasonNumber: z.number().int().nullish(),
  episodeNumber: z.number().int().nullish(),
  imageUrl: z.string().nullish(),
});

export type FeedEpisode = z.infer<typeof feedEpisodeSchema>;

// --- Preview Result (from POST /api/configs/preview) ---

export const previewEpisodeSchema = z.object({
  id: z.number(),
  title: z.string(),
  seasonNumber: z.number().int().nullish(),
  episodeNumber: z.number().int().nullish(),
});

export const previewGroupSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  sortKey: z.union([z.string(), z.number()]),
  episodeCount: z.number().int(),
  episodes: z.array(previewEpisodeSchema),
});

export const previewPlaylistSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  sortKey: z.union([z.string(), z.number()]),
  resolverType: z.string().nullish(),
  episodeCount: z.number().int(),
  groups: z.array(previewGroupSchema).optional(),
});

export const previewDebugSchema = z.object({
  totalEpisodes: z.number().int(),
  groupedEpisodes: z.number().int(),
  ungroupedEpisodes: z.number().int(),
});

export const previewResultSchema = z.object({
  playlists: z.array(previewPlaylistSchema),
  ungrouped: z.array(previewEpisodeSchema),
  resolverType: z.string().nullish(),
  debug: previewDebugSchema.optional(),
});

export type PreviewResult = z.infer<typeof previewResultSchema>;
export type PreviewPlaylist = z.infer<typeof previewPlaylistSchema>;
export type PreviewGroup = z.infer<typeof previewGroupSchema>;
export type PreviewEpisode = z.infer<typeof previewEpisodeSchema>;

// --- Auth (from POST /api/auth/refresh) ---

export const tokenResponseSchema = z.object({
  accessToken: z.string(),
  refreshToken: z.string(),
});

// --- API Keys ---

export const apiKeySchema = z.object({
  id: z.string(),
  name: z.string(),
  maskedKey: z.string(),
  createdAt: z.string(),
});

export const generatedKeySchema = z.object({
  key: z.string(),
  metadata: apiKeySchema,
});

export type ApiKey = z.infer<typeof apiKeySchema>;

// --- Submit Response ---

export const submitResponseSchema = z.object({
  prUrl: z.string(),
  branch: z.string(),
});

export type SubmitResponse = z.infer<typeof submitResponseSchema>;
```

**Step 6: Run tests to verify they pass**

```bash
pnpm test -- --run
```

Expected: All tests PASS.

**Step 7: Commit**

```bash
jj new -m "feat: add Zod schemas and TypeScript types for all models"
```

---

## Task 3: API Client with Token Refresh

**Files:**
- Create: `packages/sp_react/src/api/client.ts`
- Create: `packages/sp_react/src/api/__tests__/client.test.ts`

**Step 1: Write failing tests for API client**

```ts
// src/api/__tests__/client.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ApiClient } from '../client';

function mockFetch(responses: Array<{ status: number; body?: unknown }>) {
  let callIndex = 0;
  return vi.fn(async () => {
    const resp = responses[callIndex++] ?? { status: 500 };
    return {
      status: resp.status,
      ok: 200 <= resp.status && resp.status < 300,
      json: async () => resp.body,
      text: async () => JSON.stringify(resp.body),
    } as Response;
  });
}

describe('ApiClient', () => {
  let client: ApiClient;

  beforeEach(() => {
    client = new ApiClient('http://localhost:8080');
  });

  it('sends GET with auth header', async () => {
    const fetchMock = mockFetch([{ status: 200, body: { ok: true } }]);
    globalThis.fetch = fetchMock;

    client.setToken('test-token');
    const result = await client.get<{ ok: boolean }>('/api/health');

    expect(result).toEqual({ ok: true });
    const [url, opts] = fetchMock.mock.calls[0];
    expect(url).toBe('http://localhost:8080/api/health');
    expect(opts.headers['Authorization']).toBe('Bearer test-token');
  });

  it('sends POST with JSON body', async () => {
    const fetchMock = mockFetch([{ status: 200, body: { created: true } }]);
    globalThis.fetch = fetchMock;

    client.setToken('t');
    const result = await client.post<{ created: boolean }>('/api/data', { name: 'test' });

    expect(result).toEqual({ created: true });
    const [, opts] = fetchMock.mock.calls[0];
    expect(opts.method).toBe('POST');
    expect(JSON.parse(opts.body)).toEqual({ name: 'test' });
  });

  it('retries on 401 after successful refresh', async () => {
    const fetchMock = mockFetch([
      { status: 401 },
      { status: 200, body: { accessToken: 'new-t', refreshToken: 'new-rt' } },
      { status: 200, body: { data: 'success' } },
    ]);
    globalThis.fetch = fetchMock;

    client.setToken('old-t');
    client.setRefreshToken('old-rt');
    const result = await client.get<{ data: string }>('/api/test');

    expect(result).toEqual({ data: 'success' });
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });

  it('calls onUnauthorized when refresh fails', async () => {
    const fetchMock = mockFetch([
      { status: 401 },
      { status: 401 },
    ]);
    globalThis.fetch = fetchMock;

    const onUnauthorized = vi.fn();
    client.onUnauthorized = onUnauthorized;
    client.setToken('t');
    client.setRefreshToken('rt');

    await expect(client.get('/api/test')).rejects.toThrow();
    expect(onUnauthorized).toHaveBeenCalled();
  });

  it('deduplicates concurrent refresh attempts', async () => {
    let refreshCallCount = 0;
    const fetchMock = vi.fn(async (url: string) => {
      if (url.includes('/api/auth/refresh')) {
        refreshCallCount++;
        return {
          status: 200,
          ok: true,
          json: async () => ({ accessToken: 'new-t', refreshToken: 'new-rt' }),
        } as Response;
      }
      if (refreshCallCount === 0) {
        return { status: 401, ok: false, json: async () => ({}) } as Response;
      }
      return { status: 200, ok: true, json: async () => ({ ok: true }) } as Response;
    });
    globalThis.fetch = fetchMock;

    client.setToken('t');
    client.setRefreshToken('rt');

    await Promise.all([
      client.get('/api/a'),
      client.get('/api/b'),
    ]);

    expect(refreshCallCount).toBe(1);
  });
});
```

**Step 2: Run tests to verify they fail**

```bash
pnpm test -- --run src/api/__tests__/client.test.ts
```

Expected: FAIL - module not found.

**Step 3: Implement API client**

```ts
// src/api/client.ts

export class ApiClient {
  private token: string | null = null;
  private refreshToken_: string | null = null;
  private refreshPromise: Promise<boolean> | null = null;

  onUnauthorized?: () => void;
  onTokensRefreshed?: (accessToken: string, refreshToken: string) => void;

  constructor(private readonly baseUrl: string) {}

  setToken(token: string): void {
    this.token = token;
  }

  clearToken(): void {
    this.token = null;
  }

  setRefreshToken(token: string): void {
    this.refreshToken_ = token;
  }

  clearRefreshToken(): void {
    this.refreshToken_ = null;
  }

  get hasToken(): boolean {
    return this.token !== null;
  }

  async get<T>(path: string): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'GET',
        headers: this.buildHeaders(),
      }),
    );
  }

  async post<T>(path: string, body?: unknown): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'POST',
        headers: this.buildHeaders(),
        body: body !== undefined ? JSON.stringify(body) : undefined,
      }),
    );
  }

  async put<T>(path: string, body?: unknown): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'PUT',
        headers: this.buildHeaders(),
        body: body !== undefined ? JSON.stringify(body) : undefined,
      }),
    );
  }

  async delete<T>(path: string): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'DELETE',
        headers: this.buildHeaders(),
      }),
    );
  }

  private async send<T>(request: () => Promise<Response>): Promise<T> {
    const response = await request();

    if (response.status !== 401) {
      if (!response.ok) {
        const text = await response.text();
        throw new Error(`HTTP ${response.status}: ${text}`);
      }
      return response.json() as Promise<T>;
    }

    if (!this.refreshToken_) {
      this.token = null;
      this.onUnauthorized?.();
      throw new Error('Unauthorized');
    }

    const refreshed = await this.tryRefresh();

    if (!refreshed) {
      this.token = null;
      this.refreshToken_ = null;
      this.onUnauthorized?.();
      throw new Error('Unauthorized');
    }

    const retryResponse = await request();
    if (!retryResponse.ok) {
      const text = await retryResponse.text();
      throw new Error(`HTTP ${retryResponse.status}: ${text}`);
    }
    return retryResponse.json() as Promise<T>;
  }

  private async tryRefresh(): Promise<boolean> {
    if (this.refreshPromise) return this.refreshPromise;

    this.refreshPromise = (async () => {
      try {
        const response = await fetch(`${this.baseUrl}/api/auth/refresh`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ refreshToken: this.refreshToken_ }),
        });

        if (response.status !== 200) return false;

        const body = await response.json();
        this.token = body.accessToken;
        this.refreshToken_ = body.refreshToken;
        this.onTokensRefreshed?.(body.accessToken, body.refreshToken);
        return true;
      } catch {
        return false;
      } finally {
        this.refreshPromise = null;
      }
    })();

    return this.refreshPromise;
  }

  private buildHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    return headers;
  }
}
```

**Step 4: Run tests to verify they pass**

```bash
pnpm test -- --run src/api/__tests__/client.test.ts
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
jj new -m "feat: add API client with JWT refresh and deduplication"
```

---

## Task 4: Auth Store (Zustand)

**Files:**
- Create: `packages/sp_react/src/stores/auth-store.ts`
- Create: `packages/sp_react/src/stores/__tests__/auth-store.test.ts`

**Step 1: Write failing tests**

```ts
// src/stores/__tests__/auth-store.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { useAuthStore } from '../auth-store';

describe('authStore', () => {
  beforeEach(() => {
    useAuthStore.setState({
      token: null,
      refreshToken: null,
    });
    localStorage.clear();
  });

  it('starts unauthenticated', () => {
    const state = useAuthStore.getState();
    expect(state.token).toBeNull();
    expect(state.isAuthenticated).toBe(false);
  });

  it('sets tokens and persists to localStorage', () => {
    useAuthStore.getState().setTokens('t', 'rt');
    const state = useAuthStore.getState();
    expect(state.token).toBe('t');
    expect(state.refreshToken).toBe('rt');
    expect(state.isAuthenticated).toBe(true);
    expect(localStorage.getItem('auth:token')).toBe('t');
    expect(localStorage.getItem('auth:refreshToken')).toBe('rt');
  });

  it('logs out and clears localStorage', () => {
    useAuthStore.getState().setTokens('t', 'rt');
    useAuthStore.getState().logout();
    const state = useAuthStore.getState();
    expect(state.token).toBeNull();
    expect(state.isAuthenticated).toBe(false);
    expect(localStorage.getItem('auth:token')).toBeNull();
  });

  it('loads tokens from localStorage on init', () => {
    localStorage.setItem('auth:token', 'saved-t');
    localStorage.setItem('auth:refreshToken', 'saved-rt');
    useAuthStore.getState().loadFromStorage();
    const state = useAuthStore.getState();
    expect(state.token).toBe('saved-t');
    expect(state.refreshToken).toBe('saved-rt');
  });
});
```

**Step 2: Run tests to verify failure**

```bash
pnpm test -- --run src/stores/__tests__/auth-store.test.ts
```

**Step 3: Implement auth store**

```ts
// src/stores/auth-store.ts
import { create } from 'zustand';

interface AuthState {
  token: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  setTokens: (token: string, refreshToken: string) => void;
  logout: () => void;
  loadFromStorage: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  token: null,
  refreshToken: null,
  isAuthenticated: false,

  setTokens: (token, refreshToken) => {
    localStorage.setItem('auth:token', token);
    localStorage.setItem('auth:refreshToken', refreshToken);
    set({ token, refreshToken, isAuthenticated: true });
  },

  logout: () => {
    localStorage.removeItem('auth:token');
    localStorage.removeItem('auth:refreshToken');
    set({ token: null, refreshToken: null, isAuthenticated: false });
  },

  loadFromStorage: () => {
    const token = localStorage.getItem('auth:token');
    const refreshToken = localStorage.getItem('auth:refreshToken');
    if (token && refreshToken) {
      set({ token, refreshToken, isAuthenticated: true });
    }
  },
}));
```

**Step 4: Run tests**

```bash
pnpm test -- --run src/stores/__tests__/auth-store.test.ts
```

Expected: PASS.

**Step 5: Commit**

```bash
jj new -m "feat: add Zustand auth store with localStorage persistence"
```

---

## Task 5: Draft Service and JSON Merge

**Files:**
- Create: `packages/sp_react/src/lib/draft-service.ts`
- Create: `packages/sp_react/src/lib/json-merge.ts`
- Create: `packages/sp_react/src/lib/__tests__/draft-service.test.ts`
- Create: `packages/sp_react/src/lib/__tests__/json-merge.test.ts`

**Step 1: Write failing tests for draft service**

```ts
// src/lib/__tests__/draft-service.test.ts
import { describe, it, expect, beforeEach } from 'vitest';
import { DraftService } from '../draft-service';

describe('DraftService', () => {
  beforeEach(() => localStorage.clear());

  it('saves and loads a draft', () => {
    const service = new DraftService();
    const base = { id: 'p1', playlists: [] };
    const modified = { id: 'p1', playlists: [{ id: 'pl1' }] };

    service.saveDraft({ configId: 'p1', base, modified });
    const loaded = service.loadDraft('p1');

    expect(loaded).not.toBeNull();
    expect(loaded!.base).toEqual(base);
    expect(loaded!.modified).toEqual(modified);
    expect(loaded!.savedAt).toBeDefined();
  });

  it('returns null for missing draft', () => {
    const service = new DraftService();
    expect(service.loadDraft('nonexistent')).toBeNull();
  });

  it('uses __new__ key for null configId', () => {
    const service = new DraftService();
    service.saveDraft({ configId: null, base: {}, modified: { x: 1 } });
    expect(service.hasDraft(null)).toBe(true);
    expect(localStorage.getItem('autosave:__new__')).not.toBeNull();
  });

  it('clears a draft', () => {
    const service = new DraftService();
    service.saveDraft({ configId: 'p1', base: {}, modified: {} });
    service.clearDraft('p1');
    expect(service.hasDraft('p1')).toBe(false);
  });

  it('returns null for corrupted JSON', () => {
    const service = new DraftService();
    localStorage.setItem('autosave:bad', 'not-json');
    expect(service.loadDraft('bad')).toBeNull();
  });
});
```

**Step 2: Write failing tests for JSON merge**

```ts
// src/lib/__tests__/json-merge.test.ts
import { describe, it, expect } from 'vitest';
import { merge } from '../json-merge';

describe('merge', () => {
  it('returns latest when no user changes', () => {
    const base = { a: 1, b: 2 };
    const latest = { a: 1, b: 3 };
    const modified = { a: 1, b: 2 };
    expect(merge({ base, latest, modified })).toEqual({ a: 1, b: 3 });
  });

  it('preserves user changes', () => {
    const base = { a: 1, b: 2 };
    const latest = { a: 1, b: 2 };
    const modified = { a: 1, b: 99 };
    expect(merge({ base, latest, modified })).toEqual({ a: 1, b: 99 });
  });

  it('user change wins over upstream change', () => {
    const base = { a: 1 };
    const latest = { a: 2 };
    const modified = { a: 3 };
    expect(merge({ base, latest, modified })).toEqual({ a: 3 });
  });

  it('user removal wins', () => {
    const base = { a: 1, b: 2 };
    const latest = { a: 1, b: 2 };
    const modified = { a: 1 };
    expect(merge({ base, latest, modified })).toEqual({ a: 1 });
  });

  it('upstream adds new key untouched by user', () => {
    const base = { a: 1 };
    const latest = { a: 1, b: 2 };
    const modified = { a: 1 };
    expect(merge({ base, latest, modified })).toEqual({ a: 1, b: 2 });
  });

  it('merges nested maps recursively', () => {
    const base = { nested: { a: 1, b: 2 } };
    const latest = { nested: { a: 1, b: 3 } };
    const modified = { nested: { a: 99, b: 2 } };
    expect(merge({ base, latest, modified })).toEqual({ nested: { a: 99, b: 3 } });
  });

  it('merges id-based arrays', () => {
    const base = { items: [{ id: 'a', v: 1 }, { id: 'b', v: 2 }] };
    const latest = { items: [{ id: 'a', v: 1 }, { id: 'b', v: 3 }] };
    const modified = { items: [{ id: 'a', v: 99 }, { id: 'b', v: 2 }] };
    const result = merge({ base, latest, modified });
    expect(result.items).toEqual([{ id: 'a', v: 99 }, { id: 'b', v: 3 }]);
  });

  it('merges index-based arrays', () => {
    const base = { tags: ['a', 'b'] };
    const latest = { tags: ['a', 'c'] };
    const modified = { tags: ['x', 'b'] };
    const result = merge({ base, latest, modified });
    expect(result.tags).toEqual(['x', 'c']);
  });
});
```

**Step 3: Run tests to verify failure**

```bash
pnpm test -- --run src/lib/__tests__/
```

**Step 4: Implement draft service**

Reference: Dart `LocalDraftService` implementation. See design doc for full algorithm.

The implementation should include:
- `DraftEntry` interface with `base`, `modified`, `savedAt` fields
- `parseDraftEntry` function that validates JSON structure
- `DraftService` class with `saveDraft`, `loadDraft`, `clearDraft`, `hasDraft` methods
- Storage key format: `autosave:${configId ?? '__new__'}`
- ISO-8601 timestamps via `new Date().toISOString()`
- Silent failure on JSON parse errors (return null)

**Step 5: Implement JSON merge**

Port directly from Dart `JsonMerge`. The implementation should include:
- `merge({ base, latest, modified })` entry point
- `mergeMaps` with key-by-key three-way comparison
- `mergeLists` dispatching to id-based or index-based strategies
- `mergeIdLists` matching array items by `id` field
- `mergeIndexLists` positional merge with tail handling
- `deepEquals` recursive comparison
- `isObject` type guard
- User changes always win on conflict

**Step 6: Run tests**

```bash
pnpm test -- --run src/lib/__tests__/
```

Expected: PASS.

**Step 7: Commit**

```bash
jj new -m "feat: add draft service and three-way JSON merge"
```

---

## Task 6: TanStack Query Hooks

**Files:**
- Create: `packages/sp_react/src/api/queries.ts`
- Create: `packages/sp_react/src/api/client-provider.tsx`

**Step 1: Create API client provider**

React context wrapper that provides `ApiClient` to the component tree. Uses `createContext` + custom `useApiClient` hook that throws if used outside the provider.

**Step 2: Implement TanStack Query hooks**

All hooks use `useApiClient()` to get the client instance:

| Hook | Method | Path | Notes |
|------|--------|------|-------|
| `usePatterns` | `useQuery` | `GET /api/configs/patterns` | Returns `PatternSummary[]` |
| `useAssembledConfig(id)` | `useQuery` | `GET /api/configs/patterns/:id/assembled` | `enabled: !!id` |
| `useFeed(url)` | `useQuery` | `GET /api/feeds?url=...` | `staleTime: 15min`, `enabled: !!url` |
| `usePreviewMutation` | `useMutation` | `POST /api/configs/preview` | Takes `{ config, episodes }` |
| `useSubmitPr` | `useMutation` | `POST /api/configs/submit` | Takes submit params |
| `useApiKeys` | `useQuery` | `GET /api/keys` | Returns `{ keys: ApiKey[] }` |
| `useGenerateKey` | `useMutation` | `POST /api/keys` | Invalidates `['apiKeys']` on success |
| `useRevokeKey` | `useMutation` | `DELETE /api/keys/:id` | Invalidates `['apiKeys']` on success |

**Step 3: Verify compilation**

```bash
pnpm tsc --noEmit
```

Expected: No errors.

**Step 4: Commit**

```bash
jj new -m "feat: add TanStack Query hooks and API client provider"
```

---

## Task 7: Router and Auth Guard

**Files:**
- Create: `packages/sp_react/src/routes/__root.tsx`
- Create: `packages/sp_react/src/routes/login.tsx`
- Create: `packages/sp_react/src/routes/browse.tsx`
- Create: `packages/sp_react/src/routes/settings.tsx`
- Create: `packages/sp_react/src/routes/editor.tsx`
- Create: `packages/sp_react/src/routes/editor.$id.tsx`
- Modify: `packages/sp_react/src/main.tsx`

**Step 1: Create route files with auth guards**

Each route uses TanStack Router's `beforeLoad` to check auth:
- Unauthenticated users on protected routes -> `redirect({ to: '/login' })`
- Authenticated users on `/login` -> `redirect({ to: '/browse' })`

Route structure:
- `__root.tsx` - Root layout with `<Outlet />`
- `login.tsx` - OAuth login screen with "Sign in with GitHub" button
- `browse.tsx` - Placeholder (implemented in Task 8)
- `editor.tsx` - Placeholder for `/editor` (new config)
- `editor.$id.tsx` - Placeholder for `/editor/:id` (edit existing)
- `settings.tsx` - Placeholder (implemented in Task 9)

**Step 2: Wire up main.tsx**

Entry point responsibilities:
1. Extract OAuth tokens from URL search params (`?token=...&refresh_token=...`)
2. Store tokens in auth store + clean URL via `replaceState`
3. Or load tokens from localStorage if no URL params
4. Create `ApiClient` instance and sync with auth store
5. Subscribe to auth store changes to keep API client tokens in sync
6. Set up `onTokensRefreshed` and `onUnauthorized` callbacks
7. Create `QueryClient` and `createRouter`
8. Render provider tree: `QueryClientProvider > ApiClientProvider > RouterProvider`

**Step 3: Verify the app runs with routing**

```bash
pnpm dev
```

Expected: Login screen renders at `/login`.

**Step 4: Commit**

```bash
jj new -m "feat: add TanStack Router with auth guard and OAuth token extraction"
```

---

## Task 8: Browse Screen

**Files:**
- Modify: `packages/sp_react/src/routes/browse.tsx`

**Step 1: Implement browse screen**

Reference Flutter `browse_screen.dart` (144 lines). Components:
- Header with title, Settings button, Create New button
- `usePatterns()` query for data
- Loading/error/empty states
- Card list of patterns with `displayName`, `feedUrlHint`, `playlistCount`
- Click navigates to `/editor/:id`

Note: Use `0 < patterns.length` (not `patterns.length > 0`) per project rules.

**Step 2: Verify in browser**

```bash
pnpm dev
```

**Step 3: Commit**

```bash
jj new -m "feat: implement browse screen with pattern listing"
```

---

## Task 9: Settings Screen with API Key Manager

**Files:**
- Modify: `packages/sp_react/src/routes/settings.tsx`
- Create: `packages/sp_react/src/components/settings/api-key-manager.tsx`

**Step 1: Implement API key manager component**

Reference Flutter `api_key_manager.dart` (317 lines). Features:
- Generate key form (name input + generate button)
- Newly generated key banner (monospace, copy to clipboard, dismiss)
- Key list with name, masked key, creation date, revoke button
- Revoke confirmation via shadcn `AlertDialog`
- Uses `useApiKeys`, `useGenerateKey`, `useRevokeKey` hooks

**Step 2: Wire up settings route**

Header with back button + title. Main content area with `ApiKeyManager`.

**Step 3: Verify in browser**

```bash
pnpm dev
```

**Step 4: Commit**

```bash
jj new -m "feat: implement settings screen with API key manager"
```

---

## Task 10: Editor Store (Zustand)

**Files:**
- Create: `packages/sp_react/src/stores/editor-store.ts`
- Create: `packages/sp_react/src/stores/__tests__/editor-store.test.ts`

**Step 1: Write failing tests**

Test: starts in form mode, toggles json mode, sets feed URL, increments config version, resets state.

**Step 2: Run tests to verify failure**

```bash
pnpm test -- --run src/stores/__tests__/editor-store.test.ts
```

**Step 3: Implement editor store**

```ts
interface EditorState {
  isJsonMode: boolean;
  feedUrl: string;
  lastAutoSavedAt: Date | null;
  configVersion: number;
  toggleJsonMode: () => void;
  setFeedUrl: (url: string) => void;
  setLastAutoSavedAt: (date: Date) => void;
  incrementConfigVersion: () => void;
  reset: () => void;
}
```

**Step 4: Run tests**

```bash
pnpm test -- --run src/stores/__tests__/editor-store.test.ts
```

Expected: PASS.

**Step 5: Commit**

```bash
jj new -m "feat: add editor Zustand store"
```

---

## Task 11: Editor Components - Regex Tester

**Files:**
- Create: `packages/sp_react/src/components/editor/regex-tester.tsx`
- Create: `packages/sp_react/src/components/editor/__tests__/regex-tester.test.tsx`

**Step 1: Write tests**

Test: renders expand button, shows match count for valid pattern, shows error for invalid regex.

**Step 2: Implement regex tester**

Reference Flutter `regex_tester.dart` (252 lines). Features:
- Collapsible inline testing widget
- `useDeferredValue` for debounced pattern compilation
- 8 hardcoded sample episode titles
- Match highlighting via string split on regex matches + `<span>` with Tailwind classes
- Configurable highlight color: green for include, red for exclude
- Match count in header

**Step 3: Run tests**

```bash
pnpm test -- --run src/components/editor/__tests__/regex-tester.test.tsx
```

Expected: PASS.

**Step 4: Commit**

```bash
jj new -m "feat: implement regex tester component"
```

---

## Task 12: Editor Components - JSON Editor (CodeMirror 6)

**Files:**
- Create: `packages/sp_react/src/components/editor/json-editor.tsx`

**Step 1: Install CodeMirror dependencies**

```bash
cd /Users/tohru/Documents/src/projects/audiflow-smartplaylist-web/packages/sp_react
pnpm add @codemirror/lang-json @codemirror/lint codemirror @codemirror/view @codemirror/state
```

**Step 2: Implement JSON editor**

Features:
- `useRef` for CodeMirror `EditorView` instance
- `useEffect` to create view on mount, destroy on unmount
- `json()` language + `jsonParseLinter()` for built-in validation
- `EditorView.updateListener` to fire `onChange` callback
- Sync external `value` prop changes (e.g., form -> JSON mode toggle)
- Theme: full height, scrollable

**Step 3: Verify compilation**

```bash
pnpm tsc --noEmit
```

**Step 4: Commit**

```bash
jj new -m "feat: implement CodeMirror 6 JSON editor"
```

---

## Task 13: Editor Components - Feed URL Input and Submit Dialog

**Files:**
- Create: `packages/sp_react/src/components/editor/feed-url-input.tsx`
- Create: `packages/sp_react/src/components/editor/submit-dialog.tsx`

**Step 1: Implement feed URL input**

Two modes:
- Has predefined feedUrls: shadcn `Select` dropdown
- No predefined feedUrls: shadcn `Input` text field
- "Load Feed" button with loading state

**Step 2: Implement submit dialog**

Reference Flutter `submit_dialog.dart` (144 lines). Multi-state dialog:
1. Confirm: shows config ID, feed URL, submit button
2. Submitting: loading indicator
3. Success: PR URL with "Open PR" button
4. Error: message with retry

Uses `window.open(prUrl, '_blank')` for opening PR.

**Step 3: Verify compilation**

```bash
pnpm tsc --noEmit
```

**Step 4: Commit**

```bash
jj new -m "feat: add feed URL input and submit dialog components"
```

---

## Task 14: Preview Components

**Files:**
- Create: `packages/sp_react/src/components/preview/preview-panel.tsx`
- Create: `packages/sp_react/src/components/preview/playlist-tree.tsx`
- Create: `packages/sp_react/src/components/preview/debug-info-panel.tsx`

**Step 1: Implement debug info panel**

Compact stats card: total episodes, grouped, ungrouped.

**Step 2: Implement playlist tree**

Reference Flutter `playlist_tree.dart` (160 lines). Three-level nested accordion:
1. Playlist level: display name, resolver badge, episode count
2. Group level: display name, episode count
3. Episode level: title text

**Step 3: Implement preview panel**

Header with "Run Preview" button. Four states: empty, loading, error, results.
Results show: debug info panel + playlist tree + ungrouped episodes section.

**Step 4: Verify compilation**

```bash
pnpm tsc --noEmit
```

**Step 5: Commit**

```bash
jj new -m "feat: add preview panel, playlist tree, and debug info components"
```

---

## Task 15: Config Form and Playlist Form

**Files:**
- Create: `packages/sp_react/src/components/editor/config-form.tsx`
- Create: `packages/sp_react/src/components/editor/playlist-form.tsx`

**Step 1: Implement playlist form**

Reference Flutter `playlist_definition_form.dart` (507 lines). Key simplification with RHF:
- Uses `useFormContext<PatternConfig>()` to access form from parent
- Fields registered via `register('playlists.${index}.fieldName')`
- `watch()` for reactive values (regex patterns for RegexTester, displayName for header)
- shadcn `AccordionItem` for collapsible per playlist
- Sections: basic settings (id, displayName, resolverType, priority), filters (3 regex fields with RegexTester), boolean fields, remove button

**Step 2: Implement config form**

Reference Flutter `config_form.dart` (193 lines). Features:
- Top-level card: config ID, podcast GUID, feed URLs (comma-separated), yearGroupedEpisodes checkbox
- `useFieldArray({ control, name: 'playlists' })` for dynamic playlist list
- "Add Playlist" button that appends default playlist
- shadcn `Accordion` wrapping `PlaylistForm` for each entry

Note: Use `0 < fields.length` (not `fields.length > 0`) per project rules.

**Step 3: Verify compilation**

```bash
pnpm tsc --noEmit
```

**Step 4: Commit**

```bash
jj new -m "feat: implement config form and playlist form with RHF"
```

---

## Task 16: Editor Screen (Full Integration)

**Files:**
- Modify: `packages/sp_react/src/routes/editor.tsx`
- Modify: `packages/sp_react/src/routes/editor.$id.tsx`
- Create: `packages/sp_react/src/components/editor/editor-layout.tsx`
- Create: `packages/sp_react/src/hooks/use-auto-save.ts`

**Step 1: Implement auto-save hook**

Custom hook `useAutoSave(configId, base, getValues, watch)`:
- Watches form values via `watch()`
- 2-second debounce via `setTimeout` in `useEffect`
- Saves draft via `DraftService.saveDraft()`
- Updates `lastAutoSavedAt` in editor store

**Step 2: Implement shared editor layout**

`EditorLayout` is used by both `/editor` and `/editor/:id`. Props: `configId`, `initialConfig`.

Layout:
- Header: back button, title ("Edit: {id}" or "New Config"), auto-save timestamp, Form/JSON toggle, Submit PR button
- Feed URL input row
- Main content: responsive side-by-side (lg) or tabbed (mobile)
  - Editor panel: `FormProvider` wrapping either `ConfigForm` or `JsonEditor`
  - Preview panel: `PreviewPanel`

Key logic:
- `useForm<PatternConfig>` with zodResolver, defaultValues from initialConfig
- `useEditorStore` for local state (isJsonMode, feedUrl, lastAutoSavedAt)
- `useFeed(feedUrl)` for feed data
- `usePreviewMutation()` for preview
- `useSubmitPr()` for submission
- `useAutoSave()` for draft persistence
- Mode toggle: form->json serializes `getValues()`, json->form validates with Zod then `reset()`

**Step 3: Wire up editor routes**

- `/editor` renders `<EditorLayout configId={null} />`
- `/editor/:id` fetches config via `useAssembledConfig(id)`, shows loading/error, then renders `<EditorLayout configId={id} initialConfig={config} />`

**Step 4: Verify the full editor runs**

```bash
pnpm dev
```

**Step 5: Commit**

```bash
jj new -m "feat: implement full editor screen with auto-save and responsive layout"
```

---

## Task 17: Draft Restore Dialog

**Files:**
- Create: `packages/sp_react/src/components/editor/draft-restore-dialog.tsx`
- Modify: `packages/sp_react/src/components/editor/editor-layout.tsx`

**Step 1: Implement draft restore dialog**

shadcn `AlertDialog` showing:
- Draft saved timestamp
- "Restore" and "Discard" buttons

**Step 2: Integrate into editor-layout.tsx**

- On mount: check `draftService.loadDraft(configId)`, store in `pendingDraft` state
- Show `DraftRestoreDialog` when `pendingDraft` is non-null
- Restore: apply three-way `merge()` if initialConfig exists, else use modified directly; validate with Zod; `form.reset(parsed)`
- Discard: `draftService.clearDraft(configId)`, clear `pendingDraft`

**Step 3: Verify in browser**

```bash
pnpm dev
```

**Step 4: Commit**

```bash
jj new -m "feat: add draft restore dialog with three-way merge"
```

---

## Task 18: Final Integration and Polish

**Files:**
- Various minor adjustments across components

**Step 1: Run full test suite**

```bash
cd /Users/tohru/Documents/src/projects/audiflow-smartplaylist-web/packages/sp_react
pnpm test -- --run
```

Fix any failures.

**Step 2: Run type check**

```bash
pnpm tsc --noEmit
```

Fix any type errors.

**Step 3: Run linter**

```bash
pnpm lint
```

If ESLint is not set up, add it:

```bash
pnpm add -D eslint @eslint/js typescript-eslint eslint-plugin-react-hooks
```

**Step 4: Build for production**

```bash
pnpm build
```

Expected: Clean build with no errors. Output in `dist/`.

**Step 5: Manual smoke test**

Start both the Dart server and the React dev server. Test full flow:
1. Login via GitHub OAuth
2. Browse patterns
3. Open an existing pattern in editor
4. Toggle form/json mode
5. Load a feed
6. Run preview
7. Check auto-save (modify a field, wait 2s, refresh page, see restore dialog)
8. Test API key management in settings

**Step 6: Commit**

```bash
jj new -m "chore: final integration fixes and polish"
```

**Step 7: Create bookmark**

```bash
jj bookmark create feat/react-rewrite
```
