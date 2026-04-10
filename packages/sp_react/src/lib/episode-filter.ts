import type { FeedEpisode } from '@/schemas/api-schema.ts';
import type { EpisodeFilterEntry, EpisodeFilters } from '@/schemas/config-schema.ts';

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

// Precompiled filter entry with regexes compiled once.
// Invalid regexes become null (skipped), matching the server's
// CompiledFilterEntry behavior where None fields are skipped.
interface CompiledEntry {
  title: RegExp | null;
  description: RegExp | null;
}

function compileEntry(entry: EpisodeFilterEntry): CompiledEntry {
  return {
    title: isNonEmpty(entry.title) ? tryCompileRegex(entry.title) : null,
    description: isNonEmpty(entry.description) ? tryCompileRegex(entry.description) : null,
  };
}

// An entry matches when every compiled regex field matches.
// Null fields are no-ops (always pass), matching the server's
// CompiledFilterEntry::matches behavior.
function matchesCompiled(episode: FeedEpisode, compiled: CompiledEntry): boolean {
  if (compiled.title !== null && !compiled.title.test(episode.title)) return false;
  if (compiled.description !== null && !compiled.description.test(episode.description ?? '')) return false;
  return true;
}

export function filterEpisodes(
  episodes: readonly FeedEpisode[],
  filters: EpisodeFilters | undefined,
): FeedEpisode[] {
  if (!filters) return [...episodes];

  // Precompile regexes once before iterating over episodes.
  const requireCompiled =
    filters.require
      ?.filter((e) => isNonEmpty(e.title) || isNonEmpty(e.description))
      .map(compileEntry) ?? [];
  const excludeCompiled =
    filters.exclude
      ?.filter((e) => isNonEmpty(e.title) || isNonEmpty(e.description))
      .map(compileEntry) ?? [];

  let result = [...episodes];

  // Require entries use AND semantics: episode must match ALL entries.
  // Mirrors the server's `self.require.iter().all(|f| f.matches(episode))`.
  if (0 < requireCompiled.length) {
    result = result.filter((ep) => requireCompiled.every((c) => matchesCompiled(ep, c)));
  }

  // Exclude entries use OR semantics: episode is excluded if ANY entry matches.
  // Mirrors the server's `self.exclude.iter().any(|f| f.matches(episode))`.
  if (0 < excludeCompiled.length) {
    result = result.filter((ep) => !excludeCompiled.some((c) => matchesCompiled(ep, c)));
  }

  return result;
}
