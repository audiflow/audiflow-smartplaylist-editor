import type { PreviewEpisode } from '@/schemas/api-schema.ts';
import type { EpisodeSortField, SortOrder } from '@/schemas/config-schema.ts';

export interface EpisodeSortRule {
  field: EpisodeSortField;
  order: SortOrder;
}

function compareByField(
  a: PreviewEpisode,
  b: PreviewEpisode,
  field: EpisodeSortField,
): number {
  switch (field) {
    case 'publishedAt': {
      const aVal = a.publishedAt ?? '';
      const bVal = b.publishedAt ?? '';
      if (aVal < bVal) return -1;
      if (bVal < aVal) return 1;
      return 0;
    }
    case 'episodeNumber': {
      const aVal = a.episodeNumber ?? 0;
      const bVal = b.episodeNumber ?? 0;
      return aVal - bVal;
    }
    case 'title':
      return a.title.localeCompare(b.title);
  }
}

export function sortEpisodes(
  episodes: ReadonlyArray<PreviewEpisode>,
  rule: EpisodeSortRule,
): PreviewEpisode[] {
  const sorted = [...episodes];
  sorted.sort((a, b) => {
    const cmp = compareByField(a, b, rule.field);
    return rule.order === 'descending' ? -cmp : cmp;
  });
  return sorted;
}
