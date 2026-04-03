import { useEffect, useMemo, useRef, useState } from 'react';
import { useDerivePatternId } from '@/api/queries.ts';

interface DeriveResult {
  id: string | null;
  source: string | null;
  isLoading: boolean;
}

/**
 * Debounced hook that derives a deterministic pattern ID from
 * podcastGuid and feedUrls via the server endpoint.
 *
 * Returns `null` ID when neither input is provided.
 * Only fires after 300ms of input stability.
 */
export function useDerivedPatternId(
  podcastGuid: string | null | undefined,
  feedUrls: string[] | null | undefined,
): DeriveResult {
  const mutation = useDerivePatternId();
  const [result, setResult] = useState<{ id: string | null; source: string | null }>({
    id: null,
    source: null,
  });
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const requestIdRef = useRef(0);

  const hasInput =
    (podcastGuid != null && podcastGuid !== '') ||
    (feedUrls != null && 0 < feedUrls.filter(Boolean).length);

  // Stable key for feedUrls to avoid JSON.stringify in deps
  const feedUrlsKey = useMemo(
    () => feedUrls?.filter(Boolean).join('\0') ?? '',
    [feedUrls],
  );

  useEffect(() => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
    }

    if (!hasInput) {
      // Invalidate any in-flight request so stale callbacks cannot
      // repopulate state after the inputs have been cleared.
      requestIdRef.current += 1;
      setResult({ id: null, source: null });
      return;
    }

    const currentRequestId = ++requestIdRef.current;

    timerRef.current = setTimeout(() => {
      mutation.mutate(
        { podcastGuid, feedUrls },
        {
          onSuccess: (data) => {
            // Ignore stale responses from earlier requests
            if (requestIdRef.current === currentRequestId) {
              setResult({ id: data.id, source: data.source });
            }
          },
          onError: () => {
            if (requestIdRef.current === currentRequestId) {
              setResult({ id: null, source: null });
            }
          },
        },
      );
    }, 300);

    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
    };
  }, [podcastGuid, feedUrlsKey, mutation]);

  return {
    id: result.id,
    source: result.source,
    isLoading: hasInput && mutation.isPending,
  };
}
