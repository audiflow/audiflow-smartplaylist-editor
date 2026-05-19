import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook, waitFor, act } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import { QueryClient } from '@tanstack/react-query';
import { server } from '@/mocks/server.ts';
import { createTestProviders, TEST_BASE_URL } from '@/test-utils.tsx';
import {
  PRESET_SUMMARIES,
  PRESET_IDENTIFIERS,
  VALID_PRESET_CONFIG,
  FEED_EPISODES,
  PREVIEW_RESULT,
} from '@/mocks/fixtures.ts';
import {
  usePresets,
  usePresetIdentifiers,
  useAssembledConfig,
  useFeed,
  usePreviewMutation,
  useSavePlaylist,
  useSavePresetMeta,
  useCreatePreset,
  useDeletePlaylist,
  useDeletePreset,
} from '../queries.ts';

const BASE = TEST_BASE_URL;

let queryClient: QueryClient;
let wrapper: ReturnType<typeof createTestProviders>;
let invalidateSpy: ReturnType<typeof vi.spyOn>;

beforeEach(() => {
  queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false },
    },
  });
  wrapper = createTestProviders(queryClient);
  invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries');
});

function overrideWithError(method: 'get' | 'post' | 'put' | 'delete', path: string) {
  server.use(
    http[method](`${BASE}${path}`, () =>
      HttpResponse.json({ error: 'fail' }, { status: 500 }),
    ),
  );
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

describe('usePresets', () => {
  it('returns pattern summaries on success', async () => {
    const { result } = renderHook(() => usePresets(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toEqual(PRESET_SUMMARIES);
  });

  it('exposes error on server failure', async () => {
    overrideWithError('get', '/api/configs/presets');
    const { result } = renderHook(() => usePresets(), { wrapper });
    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error).toBeDefined();
  });
});

describe('usePresetIdentifiers', () => {
  it('returns identifiers on success', async () => {
    const { result } = renderHook(() => usePresetIdentifiers(), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toEqual(PRESET_IDENTIFIERS);
  });

  it('exposes error on server failure', async () => {
    overrideWithError('get', '/api/configs/presets/identifiers');
    const { result } = renderHook(() => usePresetIdentifiers(), { wrapper });
    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error).toBeDefined();
  });
});

describe('useAssembledConfig', () => {
  it('returns config when id is provided', async () => {
    const { result } = renderHook(() => useAssembledConfig('pattern-1'), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toEqual(VALID_PRESET_CONFIG);
  });

  it('does not fetch when id is null', async () => {
    const { result } = renderHook(() => useAssembledConfig(null), { wrapper });
    expect(result.current.fetchStatus).toBe('idle');
    expect(result.current.data).toBeUndefined();
  });

  it('exposes error on server failure', async () => {
    overrideWithError('get', '/api/configs/presets/:id/assembled');
    const { result } = renderHook(() => useAssembledConfig('pattern-1'), { wrapper });
    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error).toBeDefined();
  });
});

describe('useFeed', () => {
  it('returns episodes when url is provided', async () => {
    const { result } = renderHook(
      () => useFeed('https://example.com/feed.xml'),
      { wrapper },
    );
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toEqual(FEED_EPISODES);
  });

  it('does not fetch when url is null', async () => {
    const { result } = renderHook(() => useFeed(null), { wrapper });
    expect(result.current.fetchStatus).toBe('idle');
    expect(result.current.data).toBeUndefined();
  });

  it('exposes error on server failure', async () => {
    overrideWithError('get', '/api/feeds');
    const { result } = renderHook(
      () => useFeed('https://example.com/feed.xml'),
      { wrapper },
    );
    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error).toBeDefined();
  });
});

// ---------------------------------------------------------------------------
// Mutations
// ---------------------------------------------------------------------------

describe('usePreviewMutation', () => {
  it('returns preview result on success', async () => {
    const { result } = renderHook(() => usePreviewMutation(), { wrapper });
    act(() => {
      result.current.mutate({ config: {}, feedUrl: 'https://example.com/feed.xml' });
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data).toEqual(PREVIEW_RESULT);
  });

  it('exposes error on server failure', async () => {
    overrideWithError('post', '/api/configs/preview');
    const { result } = renderHook(() => usePreviewMutation(), { wrapper });
    act(() => {
      result.current.mutate({ config: {}, feedUrl: 'https://example.com/feed.xml' });
    });
    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error).toBeDefined();
  });
});

describe('useSavePlaylist', () => {
  it('invalidates assembledConfig on success', async () => {
    const { result } = renderHook(() => useSavePlaylist(), { wrapper });
    act(() => {
      result.current.mutate({ presetId: 'p1', playlistId: 'pl1', data: {} });
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(invalidateSpy).toHaveBeenCalledWith(
      expect.objectContaining({ queryKey: ['assembledConfig', 'p1'] }),
    );
  });

  it('exposes error on server failure', async () => {
    overrideWithError('put', '/api/configs/presets/:id/playlists/:pid');
    const { result } = renderHook(() => useSavePlaylist(), { wrapper });
    act(() => {
      result.current.mutate({ presetId: 'p1', playlistId: 'pl1', data: {} });
    });
    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error).toBeDefined();
  });
});

describe('useSavePresetMeta', () => {
  it('invalidates assembledConfig, patterns, and identifiers on success', async () => {
    const { result } = renderHook(() => useSavePresetMeta(), { wrapper });
    act(() => {
      result.current.mutate({ presetId: 'p1', data: {} });
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(invalidateSpy).toHaveBeenCalledWith(
      expect.objectContaining({ queryKey: ['assembledConfig', 'p1'] }),
    );
    expect(invalidateSpy).toHaveBeenCalledWith(
      expect.objectContaining({ queryKey: ['presets'] }),
    );
    expect(invalidateSpy).toHaveBeenCalledWith(
      expect.objectContaining({ queryKey: ['presetIdentifiers'] }),
    );
  });

  it('exposes error on server failure', async () => {
    overrideWithError('put', '/api/configs/presets/:id/meta');
    const { result } = renderHook(() => useSavePresetMeta(), { wrapper });
    act(() => {
      result.current.mutate({ presetId: 'p1', data: {} });
    });
    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error).toBeDefined();
  });
});

describe('useCreatePreset', () => {
  it('invalidates patterns and identifiers on success', async () => {
    const { result } = renderHook(() => useCreatePreset(), { wrapper });
    act(() => {
      result.current.mutate({ data: { id: 'new-pattern' } });
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(invalidateSpy).toHaveBeenCalledWith(
      expect.objectContaining({ queryKey: ['presets'] }),
    );
    expect(invalidateSpy).toHaveBeenCalledWith(
      expect.objectContaining({ queryKey: ['presetIdentifiers'] }),
    );
  });

  it('exposes error on server failure', async () => {
    overrideWithError('post', '/api/configs/presets');
    const { result } = renderHook(() => useCreatePreset(), { wrapper });
    act(() => {
      result.current.mutate({ data: {} });
    });
    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error).toBeDefined();
  });
});

describe('useDeletePlaylist', () => {
  it('invalidates assembledConfig on success', async () => {
    server.use(
      http.delete(`${BASE}/api/configs/presets/:id/playlists/:pid`, () =>
        HttpResponse.json(null),
      ),
    );
    const { result } = renderHook(() => useDeletePlaylist(), { wrapper });
    act(() => {
      result.current.mutate({ presetId: 'p1', playlistId: 'pl1' });
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(invalidateSpy).toHaveBeenCalledWith(
      expect.objectContaining({ queryKey: ['assembledConfig', 'p1'] }),
    );
  });

  it('exposes error on server failure', async () => {
    overrideWithError('delete', '/api/configs/presets/:id/playlists/:pid');
    const { result } = renderHook(() => useDeletePlaylist(), { wrapper });
    act(() => {
      result.current.mutate({ presetId: 'p1', playlistId: 'pl1' });
    });
    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error).toBeDefined();
  });
});

describe('useDeletePreset', () => {
  it('invalidates patterns and identifiers on success', async () => {
    server.use(
      http.delete(`${BASE}/api/configs/presets/:id`, () =>
        HttpResponse.json(null),
      ),
    );
    const { result } = renderHook(() => useDeletePreset(), { wrapper });
    act(() => {
      result.current.mutate('pattern-1');
    });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(invalidateSpy).toHaveBeenCalledWith(
      expect.objectContaining({ queryKey: ['presets'] }),
    );
    expect(invalidateSpy).toHaveBeenCalledWith(
      expect.objectContaining({ queryKey: ['presetIdentifiers'] }),
    );
  });

  it('exposes error on server failure', async () => {
    overrideWithError('delete', '/api/configs/presets/:id');
    const { result } = renderHook(() => useDeletePreset(), { wrapper });
    act(() => {
      result.current.mutate('pattern-1');
    });
    await waitFor(() => expect(result.current.isError).toBe(true));
    expect(result.current.error).toBeDefined();
  });
});
