import { useMemo } from 'react';
import { usePatternIdentifiers } from '@/api/queries.ts';

export interface DuplicateConflict {
  field: 'podcastGuid' | 'feedUrls';
  value: string;
  claimedBy: string;
}

/**
 * Checks the given podcastGuid and feedUrls against all other patterns
 * for uniqueness conflicts. Runs entirely client-side against the cached
 * identifiers list -- no per-keystroke API call.
 */
export function useDuplicateCheck(
  currentPatternId: string | null,
  podcastGuid: string | null | undefined,
  feedUrls: string[] | null | undefined,
): DuplicateConflict[] {
  const { data: identifiers } = usePatternIdentifiers();

  return useMemo(() => {
    if (!identifiers) return [];

    const others = currentPatternId
      ? identifiers.filter((p) => p.id !== currentPatternId)
      : identifiers;

    const conflicts: DuplicateConflict[] = [];

    if (podcastGuid) {
      const match = others.find((p) => p.podcastGuid === podcastGuid);
      if (match) {
        conflicts.push({
          field: 'podcastGuid',
          value: podcastGuid,
          claimedBy: match.id,
        });
      }
    }

    const uniqueUrls = [...new Set(feedUrls ?? [])];
    for (const url of uniqueUrls) {
      const match = others.find((p) => p.feedUrls.includes(url));
      if (match) {
        conflicts.push({
          field: 'feedUrls',
          value: url,
          claimedBy: match.id,
        });
      }
    }

    return conflicts;
  }, [identifiers, currentPatternId, podcastGuid, feedUrls]);
}
