import type { PreviewGroup, PreviewEpisode } from '@/schemas/api-schema.ts';
import type { YearHeaderMode } from '@/schemas/config-schema.ts';

export interface YearGroupEntry {
  group: PreviewGroup;
  episodeCount: number;
  /** Year-filtered episodes. Present only in perEpisode mode. */
  filteredEpisodes?: PreviewEpisode[];
}

export interface YearSection {
  year: number;
  entries: YearGroupEntry[];
}

function getEpisodeYear(publishedAt: string | null | undefined): number {
  if (!publishedAt) return 0;
  return new Date(publishedAt).getFullYear();
}

function groupByFirstEpisode(groups: PreviewGroup[]): YearSection[] {
  const byYear = new Map<number, YearGroupEntry[]>();

  for (const group of groups) {
    const year = getEpisodeYear(group.episodes[0]?.publishedAt);
    const entries = byYear.get(year) ?? [];
    entries.push({ group, episodeCount: group.episodeCount });
    byYear.set(year, entries);
  }

  return [...byYear.entries()]
    .sort((a, b) => b[0] - a[0])
    .map(([year, entries]) => ({ year, entries }));
}

function groupByPerEpisode(groups: PreviewGroup[]): YearSection[] {
  const byYear = new Map<number, YearGroupEntry[]>();

  for (const group of groups) {
    const yearEpisodes = new Map<number, PreviewEpisode[]>();
    for (const ep of group.episodes) {
      const year = getEpisodeYear(ep.publishedAt);
      const eps = yearEpisodes.get(year) ?? [];
      eps.push(ep);
      yearEpisodes.set(year, eps);
    }

    for (const [year, eps] of yearEpisodes) {
      const entries = byYear.get(year) ?? [];
      entries.push({ group, episodeCount: eps.length, filteredEpisodes: eps });
      byYear.set(year, entries);
    }
  }

  return [...byYear.entries()]
    .sort((a, b) => b[0] - a[0])
    .map(([year, entries]) => ({ year, entries }));
}

export function groupByYear(
  groups: PreviewGroup[],
  mode: YearHeaderMode,
): YearSection[] | null {
  if (mode === 'none') return null;
  if (mode === 'firstEpisode') return groupByFirstEpisode(groups);
  return groupByPerEpisode(groups);
}
