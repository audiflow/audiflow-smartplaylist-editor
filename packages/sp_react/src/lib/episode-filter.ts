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

// Mirrors the server's CompiledFilterEntry: invalid regexes become None (skipped).
function tryCompileRegex(pattern: string): RegExp | null {
  try {
    return new RegExp(pattern, 'i');
  } catch {
    return null;
  }
}

// An entry matches when every compiled regex field matches.
// Invalid regexes and empty fields are treated as no-ops (always pass),
// matching the server's CompiledFilterEntry::matches behavior where
// None fields are skipped and the entry returns true by default.
function matchesEntry(episode: FeedEpisode, entry: FilterEntry): boolean {
  if (isNonEmpty(entry.title)) {
    const re = tryCompileRegex(entry.title);
    // Invalid regex = no-op for this field (matches server behavior)
    if (re !== null && !re.test(episode.title)) return false;
  }
  if (isNonEmpty(entry.description)) {
    const re = tryCompileRegex(entry.description);
    if (re !== null && !re.test(episode.description ?? '')) return false;
  }
  return true;
}

// Require entries use AND semantics: episode must match ALL entries.
// Mirrors the server's `self.require.iter().all(|f| f.matches(episode))`.
function matchesAllEntries(episode: FeedEpisode, entries: FilterEntry[]): boolean {
  return entries.every((entry) => matchesEntry(episode, entry));
}

// Exclude entries use OR semantics: episode is excluded if ANY entry matches.
// Mirrors the server's `self.exclude.iter().any(|f| f.matches(episode))`.
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
    result = result.filter((ep) => matchesAllEntries(ep, requireEntries));
  }

  if (0 < excludeEntries.length) {
    result = result.filter((ep) => !matchesAnyEntry(ep, excludeEntries));
  }

  return result;
}
