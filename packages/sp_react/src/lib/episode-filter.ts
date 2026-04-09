import type { FeedEpisode } from '@/schemas/api-schema.ts';

interface FilterEntry {
  title?: string;
  description?: string;
}

interface EpisodeFilters {
  require?: FilterEntry[];
  exclude?: FilterEntry[];
}

function matchesEntry(episode: FeedEpisode, entry: FilterEntry): boolean {
  if (entry.title !== undefined) {
    try {
      const re = new RegExp(entry.title, 'i');
      if (!re.test(episode.title)) return false;
    } catch {
      return false;
    }
  }
  if (entry.description !== undefined) {
    try {
      const re = new RegExp(entry.description, 'i');
      if (!re.test(episode.description ?? '')) return false;
    } catch {
      return false;
    }
  }
  return entry.title !== undefined || entry.description !== undefined;
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
      (e) => e.title !== undefined || e.description !== undefined,
    ) ?? [];
  const excludeEntries =
    filters.exclude?.filter(
      (e) => e.title !== undefined || e.description !== undefined,
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
