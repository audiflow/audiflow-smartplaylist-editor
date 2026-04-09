import type { FeedEpisode } from '@/schemas/api-schema.ts';

interface FilterEntry {
  title?: string;
  description?: string;
}

interface EpisodeFilters {
  require?: FilterEntry[];
  exclude?: FilterEntry[];
}

function isNonEmpty(value: string | undefined): value is string {
  return value !== undefined && value !== '';
}

function matchesEntry(episode: FeedEpisode, entry: FilterEntry): boolean {
  if (isNonEmpty(entry.title)) {
    try {
      const re = new RegExp(entry.title, 'i');
      if (!re.test(episode.title)) return false;
    } catch {
      return false;
    }
  }
  if (isNonEmpty(entry.description)) {
    try {
      const re = new RegExp(entry.description, 'i');
      if (!re.test(episode.description ?? '')) return false;
    } catch {
      return false;
    }
  }
  return isNonEmpty(entry.title) || isNonEmpty(entry.description);
}

function matchesAnyEntry(episode: FeedEpisode, entries: FilterEntry[]): boolean {
  return entries.some((entry) => matchesEntry(episode, entry));
}

export function filterEpisodes(
  episodes: readonly FeedEpisode[],
  filters: EpisodeFilters | undefined,
): FeedEpisode[] {
  if (!filters) return [...episodes];

  const requireEntries =
    filters.require?.filter(
      (e) => isNonEmpty(e.title) || isNonEmpty(e.description),
    ) ?? [];
  const excludeEntries =
    filters.exclude?.filter(
      (e) => isNonEmpty(e.title) || isNonEmpty(e.description),
    ) ?? [];

  let result = [...episodes];

  if (0 < requireEntries.length) {
    result = result.filter((ep) => matchesAnyEntry(ep, requireEntries));
  }

  if (0 < excludeEntries.length) {
    result = result.filter((ep) => !matchesAnyEntry(ep, excludeEntries));
  }

  return result;
}
