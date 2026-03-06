import { describe, it, expect } from 'vitest';
import type { PreviewGroup, PreviewEpisode } from '@/schemas/api-schema.ts';
import { groupByYear } from '../year-group-utils.ts';

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

function makeGroup(id: string, episodes: PreviewEpisode[]): PreviewGroup {
  return {
    id,
    displayName: id,
    sortKey: 0,
    episodeCount: episodes.length,
    episodes,
  };
}

describe('groupByYear', () => {
  const ep2024a = makeEpisode({ id: 1, publishedAt: '2024-03-01T00:00:00Z' });
  const ep2024b = makeEpisode({ id: 2, publishedAt: '2024-08-15T00:00:00Z' });
  const ep2025a = makeEpisode({ id: 3, publishedAt: '2025-01-10T00:00:00Z' });
  const ep2025b = makeEpisode({ id: 4, publishedAt: '2025-06-20T00:00:00Z' });

  describe('none mode', () => {
    it('returns null', () => {
      const groups = [makeGroup('g1', [ep2024a, ep2025a])];
      expect(groupByYear(groups, 'none')).toBeNull();
    });
  });

  describe('firstEpisode mode', () => {
    it('places group under year of its first episode', () => {
      const groups = [
        makeGroup('g1', [ep2024a, ep2024b, ep2025a]),
        makeGroup('g2', [ep2025a, ep2025b]),
      ];
      const result = groupByYear(groups, 'firstEpisode')!;
      const years = result.map((y) => y.year);
      expect(years).toEqual([2025, 2024]);

      const y2024 = result.find((y) => y.year === 2024)!;
      expect(y2024.entries).toHaveLength(1);
      expect(y2024.entries[0].group.id).toBe('g1');
      expect(y2024.entries[0].episodeCount).toBe(3);

      const y2025 = result.find((y) => y.year === 2025)!;
      expect(y2025.entries).toHaveLength(1);
      expect(y2025.entries[0].group.id).toBe('g2');
      expect(y2025.entries[0].filteredEpisodes).toBeUndefined();
    });

    it('uses year 0 for episodes without publishedAt', () => {
      const epNoDate = makeEpisode({ id: 10, publishedAt: null });
      const groups = [makeGroup('g1', [epNoDate])];
      const result = groupByYear(groups, 'firstEpisode')!;
      expect(result).toHaveLength(1);
      expect(result[0].year).toBe(0);
    });
  });

  describe('perEpisode mode', () => {
    it('duplicates group across years with filtered counts and episodes', () => {
      const groups = [makeGroup('g1', [ep2024a, ep2024b, ep2025a])];
      const result = groupByYear(groups, 'perEpisode')!;
      const years = result.map((y) => y.year);
      expect(years).toEqual([2025, 2024]);

      const y2024 = result.find((y) => y.year === 2024)!;
      expect(y2024.entries).toHaveLength(1);
      expect(y2024.entries[0].group.id).toBe('g1');
      expect(y2024.entries[0].episodeCount).toBe(2);
      expect(y2024.entries[0].filteredEpisodes).toEqual([ep2024a, ep2024b]);

      const y2025 = result.find((y) => y.year === 2025)!;
      expect(y2025.entries).toHaveLength(1);
      expect(y2025.entries[0].group.id).toBe('g1');
      expect(y2025.entries[0].episodeCount).toBe(1);
      expect(y2025.entries[0].filteredEpisodes).toEqual([ep2025a]);
    });

    it('handles multiple groups across overlapping years', () => {
      const groups = [
        makeGroup('g1', [ep2024a, ep2025a]),
        makeGroup('g2', [ep2025a, ep2025b]),
      ];
      const result = groupByYear(groups, 'perEpisode')!;

      const y2025 = result.find((y) => y.year === 2025)!;
      expect(y2025.entries).toHaveLength(2);

      const y2024 = result.find((y) => y.year === 2024)!;
      expect(y2024.entries).toHaveLength(1);
      expect(y2024.entries[0].group.id).toBe('g1');
    });
  });

  it('sorts years descending', () => {
    const groups = [
      makeGroup('g1', [ep2024a]),
      makeGroup('g2', [ep2025a]),
    ];
    const result = groupByYear(groups, 'firstEpisode')!;
    expect(result[0].year).toBe(2025);
    expect(result[1].year).toBe(2024);
  });
});
