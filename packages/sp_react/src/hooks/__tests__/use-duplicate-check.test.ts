import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { http } from 'msw';
import { server } from '@/mocks/server.ts';
import { createTestQueryClient, createTestProviders, TEST_BASE_URL } from '@/test-utils.tsx';
import { useDuplicateCheck } from '@/hooks/use-duplicate-check.ts';
import type { QueryClient } from '@tanstack/react-query';

describe('useDuplicateCheck', () => {
  let queryClient: QueryClient;

  beforeEach(() => {
    queryClient = createTestQueryClient();
  });

  function renderDuplicateCheck(
    currentPatternId: string | null,
    podcastGuid: string | null | undefined,
    feedUrls: string[] | null | undefined,
  ) {
    return renderHook(
      () => useDuplicateCheck(currentPatternId, podcastGuid, feedUrls),
      { wrapper: createTestProviders(queryClient) },
    );
  }

  it('returns empty array before identifiers have loaded', () => {
    // Override to never respond
    server.use(
      http.get(`${TEST_BASE_URL}/api/configs/patterns/identifiers`, () => {
        return new Promise(() => {
          // Never resolves -- simulates pending fetch
        });
      }),
    );

    const { result } = renderDuplicateCheck(null, 'guid-alpha-111', null);

    expect(result.current).toEqual([]);
  });

  it('returns empty when no duplicates exist', async () => {
    const { result } = renderDuplicateCheck(
      null,
      'guid-unique-999',
      ['https://example.com/unique/feed.xml'],
    );

    // Wait for identifiers to load, then confirm still empty
    await waitFor(() => {
      // Query should have settled -- we verify by checking that the hook
      // re-rendered after data arrived. Since there are no duplicates,
      // result stays empty. We rely on waitFor's polling.
      expect(queryClient.getQueryState(['patternIdentifiers'])?.status).toBe(
        'success',
      );
    });

    expect(result.current).toEqual([]);
  });

  it('detects duplicate podcastGuid', async () => {
    const { result } = renderDuplicateCheck(
      null,
      'guid-alpha-111', // matches pattern-1
      null,
    );

    await waitFor(() => {
      expect(1 <= result.current.length).toBe(true);
    });

    expect(result.current).toEqual([
      {
        field: 'podcastGuid',
        value: 'guid-alpha-111',
        claimedBy: 'pattern-1',
      },
    ]);
  });

  it('detects duplicate feedUrl', async () => {
    const { result } = renderDuplicateCheck(
      null,
      null,
      ['https://example.com/beta/feed.xml'], // matches pattern-2
    );

    await waitFor(() => {
      expect(1 <= result.current.length).toBe(true);
    });

    expect(result.current).toEqual([
      {
        field: 'feedUrls',
        value: 'https://example.com/beta/feed.xml',
        claimedBy: 'pattern-2',
      },
    ]);
  });

  it('detects both podcastGuid and feedUrl duplicates simultaneously', async () => {
    const { result } = renderDuplicateCheck(
      null,
      'guid-alpha-111', // matches pattern-1
      ['https://example.com/beta/feed.xml'], // matches pattern-2
    );

    await waitFor(() => {
      expect(2 <= result.current.length).toBe(true);
    });

    expect(result.current).toEqual([
      {
        field: 'podcastGuid',
        value: 'guid-alpha-111',
        claimedBy: 'pattern-1',
      },
      {
        field: 'feedUrls',
        value: 'https://example.com/beta/feed.xml',
        claimedBy: 'pattern-2',
      },
    ]);
  });

  it('excludes current pattern from comparison (no self-conflict)', async () => {
    const { result } = renderDuplicateCheck(
      'pattern-1', // exclude self
      'guid-alpha-111', // would match pattern-1, but it is excluded
      ['https://example.com/alpha/feed.xml'], // same
    );

    await waitFor(() => {
      expect(queryClient.getQueryState(['patternIdentifiers'])?.status).toBe(
        'success',
      );
    });

    expect(result.current).toEqual([]);
  });

  it('returns empty when podcastGuid is null', async () => {
    const { result } = renderDuplicateCheck(
      null,
      null,
      ['https://example.com/unique/feed.xml'],
    );

    await waitFor(() => {
      expect(queryClient.getQueryState(['patternIdentifiers'])?.status).toBe(
        'success',
      );
    });

    expect(result.current).toEqual([]);
  });

  it('returns empty when podcastGuid is undefined', async () => {
    const { result } = renderDuplicateCheck(
      null,
      undefined,
      ['https://example.com/unique/feed.xml'],
    );

    await waitFor(() => {
      expect(queryClient.getQueryState(['patternIdentifiers'])?.status).toBe(
        'success',
      );
    });

    expect(result.current).toEqual([]);
  });

  it('returns empty when feedUrls is null', async () => {
    const { result } = renderDuplicateCheck(
      null,
      'guid-unique-999',
      null,
    );

    await waitFor(() => {
      expect(queryClient.getQueryState(['patternIdentifiers'])?.status).toBe(
        'success',
      );
    });

    expect(result.current).toEqual([]);
  });

  it('returns empty when feedUrls is undefined', async () => {
    const { result } = renderDuplicateCheck(
      null,
      'guid-unique-999',
      undefined,
    );

    await waitFor(() => {
      expect(queryClient.getQueryState(['patternIdentifiers'])?.status).toBe(
        'success',
      );
    });

    expect(result.current).toEqual([]);
  });

  it('deduplicates feedUrls so the same URL produces only one conflict', async () => {
    const { result } = renderDuplicateCheck(
      null,
      null,
      [
        'https://example.com/alpha/feed.xml',
        'https://example.com/alpha/feed.xml', // duplicate entry
      ],
    );

    await waitFor(() => {
      expect(1 <= result.current.length).toBe(true);
    });

    // Only one conflict despite the URL appearing twice in the input
    expect(result.current).toEqual([
      {
        field: 'feedUrls',
        value: 'https://example.com/alpha/feed.xml',
        claimedBy: 'pattern-1',
      },
    ]);
  });
});
