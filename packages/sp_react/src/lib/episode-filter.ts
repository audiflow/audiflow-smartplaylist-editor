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

// Returns true when at least one field compiled to a valid regex.
// Entries where all fields are null (empty source or invalid regex) would
// match every episode via matchesCompiled, which is harmless for require
// (AND semantics) but dangerous for exclude (OR semantics -- would exclude
// all episodes). Filtering these out diverges from server behavior
// intentionally: the editor processes in-progress typing, so safety
// (not excluding everything by accident) trumps exact server parity.
function hasCompiledField(entry: CompiledEntry): boolean {
  return entry.title !== null || entry.description !== null;
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
      .map(compileEntry)
      .filter(hasCompiledField) ?? [];
  const excludeCompiled =
    filters.exclude
      ?.filter((e) => isNonEmpty(e.title) || isNonEmpty(e.description))
      .map(compileEntry)
      .filter(hasCompiledField) ?? [];

  let result = [...episodes];

  // Require entries use OR semantics across rules: episode is included
  // when it matches ANY rule. Each rule's own fields are still AND
  // (enforced inside matchesCompiled). Mirrors the server contract
  // advertised by the v5 playlist-definition schema.
  if (0 < requireCompiled.length) {
    result = result.filter((ep) => requireCompiled.some((c) => matchesCompiled(ep, c)));
  }

  // Exclude entries use OR semantics: episode is excluded if ANY entry matches.
  // Mirrors the server's `self.exclude.iter().any(|f| f.matches(episode))`.
  if (0 < excludeCompiled.length) {
    result = result.filter((ep) => !excludeCompiled.some((c) => matchesCompiled(ep, c)));
  }

  return result;
}
