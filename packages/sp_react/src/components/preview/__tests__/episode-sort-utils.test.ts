import { describe, it, expect } from 'vitest';
import type { PreviewEpisode } from '@/schemas/api-schema.ts';
import { sortEpisodes } from '../episode-sort-utils.ts';

function makeEpisode(
  overrides: Partial<PreviewEpisode> & { id: number },
): PreviewEpisode {
  return {
    title: `Episode ${overrides.id}`,
    publishedAt: null,
    seasonNumber: null,
    episodeNumber: null,
    extractedDisplayName: null,
    ...overrides,
  };
}

describe('sortEpisodes', () => {
  const epA = makeEpisode({ id: 1, title: 'Alpha', publishedAt: '2024-01-01T00:00:00Z', episodeNumber: 3 });
  const epB = makeEpisode({ id: 2, title: 'Beta', publishedAt: '2025-06-01T00:00:00Z', episodeNumber: 1 });
  const epC = makeEpisode({ id: 3, title: 'Charlie', publishedAt: '2024-06-01T00:00:00Z', episodeNumber: 2 });

  describe('publishedAt field', () => {
    it('sorts ascending', () => {
      const result = sortEpisodes([epB, epA, epC], { field: 'publishedAt', order: 'ascending' });
      expect(result.map((e) => e.id)).toEqual([1, 3, 2]);
    });

    it('sorts descending', () => {
      const result = sortEpisodes([epA, epC, epB], { field: 'publishedAt', order: 'descending' });
      expect(result.map((e) => e.id)).toEqual([2, 3, 1]);
    });
  });

  describe('episodeNumber field', () => {
    it('sorts ascending', () => {
      const result = sortEpisodes([epA, epB, epC], { field: 'episodeNumber', order: 'ascending' });
      expect(result.map((e) => e.id)).toEqual([2, 3, 1]);
    });

    it('sorts descending', () => {
      const result = sortEpisodes([epA, epB, epC], { field: 'episodeNumber', order: 'descending' });
      expect(result.map((e) => e.id)).toEqual([1, 3, 2]);
    });
  });

  describe('title field', () => {
    it('sorts ascending', () => {
      const result = sortEpisodes([epC, epA, epB], { field: 'title', order: 'ascending' });
      expect(result.map((e) => e.id)).toEqual([1, 2, 3]);
    });

    it('sorts descending', () => {
      const result = sortEpisodes([epA, epB, epC], { field: 'title', order: 'descending' });
      expect(result.map((e) => e.id)).toEqual([3, 2, 1]);
    });
  });

  it('does not mutate the input array', () => {
    const input = [epC, epA, epB];
    const copy = [...input];
    sortEpisodes(input, { field: 'episodeNumber', order: 'ascending' });
    expect(input).toEqual(copy);
  });
});
