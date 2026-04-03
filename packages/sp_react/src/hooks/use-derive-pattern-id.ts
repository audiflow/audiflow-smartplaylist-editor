import { useEffect, useRef, useState } from 'react';
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

  const hasInput =
    (podcastGuid != null && podcastGuid !== '') ||
    (feedUrls != null && 0 < feedUrls.filter(Boolean).length);

  useEffect(() => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
    }

    if (!hasInput) {
      setResult({ id: null, source: null });
      return;
    }

    timerRef.current = setTimeout(() => {
      mutation.mutate(
        { podcastGuid, feedUrls },
        {
          onSuccess: (data) => setResult({ id: data.id, source: data.source }),
          onError: () => setResult({ id: null, source: null }),
        },
      );
    }, 300);

    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
    };
  }, [podcastGuid, JSON.stringify(feedUrls)]); // eslint-disable-line react-hooks/exhaustive-deps

  return {
    id: result.id,
    source: result.source,
    isLoading: mutation.isPending,
  };
}
