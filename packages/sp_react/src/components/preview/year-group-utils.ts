import type { PreviewGroup, PreviewEpisode } from '@/schemas/api-schema.ts';
import type { YearBinding } from '@/schemas/config-schema.ts';

export interface YearGroupEntry {
  group: PreviewGroup;
  episodeCount: number;
  /** Year-filtered episodes. Present only in splitByYear mode. */
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

function groupByPinToYear(groups: PreviewGroup[]): YearSection[] {
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

function groupBySplitByYear(groups: PreviewGroup[]): YearSection[] {
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

/**
 * Groups preview groups into year sections.
 *
 * When `groupOverrides` is provided, each group may use a different
 * year-binding mode. Groups whose effective mode is 'none' fall back
 * to 'pinToYear' so they still appear in year sections.
 */
export function groupByYear(
  groups: PreviewGroup[],
  mode: YearBinding,
  groupOverrides?: ReadonlyMap<string, YearBinding>,
): YearSection[] | null {
  const hasMixedModes = groupOverrides && 0 < groupOverrides.size;

  if (!hasMixedModes) {
    if (mode === 'none') return null;
    if (mode === 'pinToYear') return groupByPinToYear(groups);
    return groupBySplitByYear(groups);
  }

  return groupByYearMixed(groups, mode, groupOverrides);
}

function groupByYearMixed(
  groups: PreviewGroup[],
  defaultMode: YearBinding,
  overrides: ReadonlyMap<string, YearBinding>,
): YearSection[] | null {
  const effectiveModes = groups.map(
    (g) => overrides.get(g.id) ?? defaultMode,
  );

  if (effectiveModes.every((m) => m === 'none')) return null;

  const byYear = new Map<number, YearGroupEntry[]>();

  for (let i = 0; i < groups.length; i++) {
    const group = groups[i];
    let mode = effectiveModes[i];
    // In a mixed context, 'none' groups still need a year section
    if (mode === 'none') mode = 'pinToYear';

    if (mode === 'pinToYear') {
      const year = getEpisodeYear(group.episodes[0]?.publishedAt);
      const entries = byYear.get(year) ?? [];
      entries.push({ group, episodeCount: group.episodeCount });
      byYear.set(year, entries);
    } else {
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
  }

  return [...byYear.entries()]
    .sort((a, b) => b[0] - a[0])
    .map(([year, entries]) => ({ year, entries }));
}
