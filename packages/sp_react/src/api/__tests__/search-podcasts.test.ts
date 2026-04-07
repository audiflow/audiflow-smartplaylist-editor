import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import { QueryClient } from '@tanstack/react-query';
import { server } from '@/mocks/server.ts';
import { createTestProviders, TEST_BASE_URL } from '@/test-utils.tsx';
import { useSearchPodcasts } from '../queries.ts';

const BASE = TEST_BASE_URL;

let queryClient: QueryClient;
let wrapper: ReturnType<typeof createTestProviders>;

beforeEach(() => {
  queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
    },
  });
  wrapper = createTestProviders(queryClient);
});

describe('useSearchPodcasts', () => {
  it('does not fetch when term is empty', () => {
    const { result } = renderHook(() => useSearchPodcasts(''), { wrapper });
    expect(result.current.fetchStatus).toBe('idle');
  });

  it('fetches results when term has 3+ characters', async () => {
    const { result } = renderHook(() => useSearchPodcasts('test'), { wrapper });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data?.results).toHaveLength(1);
    expect(result.current.data?.results[0].trackName).toBe('Test Podcast for test');
  });

  it('handles API errors gracefully', async () => {
    server.use(
      http.get(`${BASE}/api/podcasts/search`, () =>
        HttpResponse.json({ error: 'fail' }, { status: 500 }),
      ),
    );

    const { result } = renderHook(() => useSearchPodcasts('test'), { wrapper });
    await waitFor(() => expect(result.current.isError).toBe(true));
  });
});
