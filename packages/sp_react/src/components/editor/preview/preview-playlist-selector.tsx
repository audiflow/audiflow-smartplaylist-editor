import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { useFormContext, useWatch } from 'react-hook-form';
import type { PatternConfig, PartitionBy } from '@/schemas/config-schema.ts';
import type { PreviewPlaylist } from '@/schemas/api-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';

// -- Types --

export type SelectorEntry = {
  playlistId: string;
  entryIndex: number;
  label: string;
  /** The raw partition value (season number or year) for filtering, or null for non-partitioned entries. */
  partitionValue: number | null;
  /**
   * The group id this entry maps to when `partitionBy === 'group'`. Lets the
   * filtering layer narrow preview groups down to the chosen classifier.
   */
  partitionGroupId?: string;
};

// -- Entry generation --

export function generateEntries(
  playlistId: string,
  displayName: string,
  partitionBy: PartitionBy | undefined,
  previewPlaylist: PreviewPlaylist | null | undefined,
  t: (key: string, opts?: Record<string, unknown>) => string,
): SelectorEntry[] {
  if (partitionBy === 'seasonNumber') {
    const seasons = collectUniqueSeasonNumbers(previewPlaylist);
    if (0 < seasons.length) {
      return seasons.map((s, i) => ({
        playlistId,
        entryIndex: i,
        label: resolveSeasonLabel(s, previewPlaylist, t),
        partitionValue: s,
      }));
    }
  }

  if (partitionBy === 'year') {
    const years = collectUniqueYears(previewPlaylist);
    if (0 < years.length) {
      return years.map((y, i) => ({
        playlistId,
        entryIndex: i,
        label: resolveYearLabel(y, previewPlaylist, t),
        partitionValue: y,
      }));
    }
  }

  if (partitionBy === 'group') {
    const groups = previewPlaylist?.groups ?? [];
    if (0 < groups.length) {
      return groups.map((group, i) => ({
        playlistId,
        entryIndex: i,
        label: group.displayName,
        partitionValue: null,
        partitionGroupId: group.id,
      }));
    }
  }

  return [{ playlistId, entryIndex: 0, label: displayName, partitionValue: null }];
}

/**
 * Find the displayName of the year-partitioned group matching the target year.
 *
 * The backend emits synthetic groups with `id: "year_{year}"` and a
 * `displayName` computed from `selector.titleExtractor` (when configured).
 * Prefer that label so editing `selector.titleExtractor` is visible in the
 * selector. Fall back to a localized default when no custom extractor is set.
 */
function resolveYearLabel(
  year: number,
  previewPlaylist: PreviewPlaylist | null | undefined,
  t: (key: string, opts?: Record<string, unknown>) => string,
): string {
  if (previewPlaylist?.groups) {
    const targetId = `year_${year}`;
    for (const group of previewPlaylist.groups) {
      if (group.id === targetId) {
        return group.displayName;
      }
    }
  }
  return t('selector.yearEntry', { year });
}

/** Find the displayName of a group whose first episode has a matching seasonNumber. */
function resolveSeasonLabel(
  seasonNumber: number,
  previewPlaylist: PreviewPlaylist | null | undefined,
  t: (key: string, opts?: Record<string, unknown>) => string,
): string {
  if (previewPlaylist?.groups) {
    for (const group of previewPlaylist.groups) {
      if (group.episodes[0]?.seasonNumber === seasonNumber) {
        return group.displayName;
      }
    }
  }
  return t('selector.seasonEntry', { n: seasonNumber });
}

function collectUniqueSeasonNumbers(
  previewPlaylist: PreviewPlaylist | null | undefined,
): number[] {
  if (!previewPlaylist?.groups) return [];
  const seen = new Set<number>();
  const result: number[] = [];
  for (const group of previewPlaylist.groups) {
    const sn = group.episodes[0]?.seasonNumber;
    if (sn != null && !seen.has(sn)) {
      seen.add(sn);
      result.push(sn);
    }
  }
  return result;
}

function collectUniqueYears(
  previewPlaylist: PreviewPlaylist | null | undefined,
): number[] {
  if (!previewPlaylist?.groups) return [];
  const seen = new Set<number>();
  const result: number[] = [];
  for (const group of previewPlaylist.groups) {
    // Prefer the synthetic year_{N} partition ids emitted by the backend
    // (which bucket by UTC year). Only fall back to parsing the episode
    // date when a group predates partitioning, and in that fallback use
    // UTC so the selector never drifts by browser timezone.
    const year =
      extractYearFromGroupId(group.id) ??
      extractUtcYear(group.episodes[0]?.publishedAt);
    if (year != null && !seen.has(year)) {
      seen.add(year);
      result.push(year);
    }
  }
  return result;
}

function extractYearFromGroupId(id: string): number | null {
  const match = id.match(/^year_(-?\d+)$/);
  if (!match) return null;
  const value = parseInt(match[1], 10);
  return Number.isFinite(value) ? value : null;
}

function extractUtcYear(publishedAt: string | undefined): number | null {
  if (!publishedAt) return null;
  const date = new Date(publishedAt);
  const utcYear = date.getUTCFullYear();
  return Number.isFinite(utcYear) ? utcYear : null;
}

// -- Component --

interface PreviewPlaylistSelectorProps {
  activePlaylistId: string;
  activeEntryIndex: number;
  onSelectEntry: (playlistId: string, entryIndex: number) => void;
  /**
   * Called when the user chooses an entry that belongs to a different playlist.
   * `entryIndex` identifies which entry within the target playlist was picked
   * so the caller can deep-link into it instead of defaulting to entry 0.
   */
  onSelectPlaylist: (playlistId: string, entryIndex: number) => void;
}

export function PreviewPlaylistSelector({
  activePlaylistId,
  activeEntryIndex,
  onSelectEntry,
  onSelectPlaylist,
}: PreviewPlaylistSelectorProps) {
  const { t } = useTranslation('preview');
  const { control } = useFormContext<PatternConfig>();
  const playlists = useWatch({ control, name: 'playlists' });
  const previewData = useEditorStore((s) => s.previewData);

  const allEntries = useMemo((): SelectorEntry[] => {
    if (!playlists) return [];
    return playlists.flatMap((playlist) => {
      const previewPlaylist = previewData?.playlists.find(
        (p) => p.id === playlist.id,
      );
      return generateEntries(
        playlist.id,
        playlist.displayName ?? '',
        playlist.selector?.partitionBy,
        previewPlaylist,
        t,
      );
    });
  }, [playlists, previewData, t]);

  // Compose a globally-unique value for each entry using '::' as a separator
  // so that Radix onValueChange fires even when entryIndex collides across
  // different playlists (e.g. two playlists both have their first entry at
  // index 0 — the keys "pl-a::0" and "pl-b::0" are always distinct).
  function entryKey(entry: SelectorEntry): string {
    return `${entry.playlistId}::${entry.entryIndex}`;
  }

  // Parse a key produced by entryKey back into its components.
  function parseEntryKey(key: string): { playlistId: string; entryIndex: number } | null {
    const separatorIndex = key.lastIndexOf('::');
    if (separatorIndex === -1) return null;
    const playlistId = key.slice(0, separatorIndex);
    const entryIndex = parseInt(key.slice(separatorIndex + 2), 10);
    if (!playlistId || isNaN(entryIndex)) return null;
    return { playlistId, entryIndex };
  }

  // The currently selected entry key: first entry for active playlist at the
  // active entry index, falling back to the first entry of that playlist.
  const selectedKey = useMemo((): string => {
    const entriesForActive = allEntries.filter(
      (e) => e.playlistId === activePlaylistId,
    );
    const target =
      entriesForActive[activeEntryIndex] ?? entriesForActive[0];
    if (target) return entryKey(target);
    // Fallback when no preview data yet — look up displayName from form.
    // Use '::' separator to stay consistent with entryKey format.
    return `${activePlaylistId}::0`;
  }, [allEntries, activePlaylistId, activeEntryIndex, playlists]);

  const selectedLabel = useMemo((): string => {
    const entry = allEntries.find((e) => entryKey(e) === selectedKey);
    if (entry) return entry.label;
    const pl = playlists?.find((p) => p.id === activePlaylistId);
    return pl?.displayName ?? '';
  }, [allEntries, selectedKey, activePlaylistId, playlists]);

  function handleSelect(value: string): void {
    const parsed = parseEntryKey(value);
    if (!parsed) return;

    const { playlistId, entryIndex } = parsed;
    if (playlistId !== activePlaylistId) {
      // Forward the chosen entry so the target playlist opens with it
      // preselected instead of snapping to entry 0.
      onSelectPlaylist(playlistId, entryIndex);
    } else {
      onSelectEntry(playlistId, entryIndex);
    }
  }

  return (
    <header
      data-preview-region="playlist-header"
      className="sticky top-0 z-20 mb-3 border-b bg-background/95 px-4 py-3 backdrop-blur-sm rounded-t"
    >
      <Select value={selectedKey} onValueChange={handleSelect}>
        <SelectTrigger className="w-full border-none shadow-none px-0 font-semibold text-base h-auto py-0 focus-visible:ring-0">
          <SelectValue>{selectedLabel}</SelectValue>
        </SelectTrigger>
        <SelectContent>
          {allEntries.map((entry) => (
            <SelectItem key={entryKey(entry)} value={entryKey(entry)}>
              {entry.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </header>
  );
}

// -- Filtering helpers --

/** Returns the active entry for the given playlist, or null if none applies. */
export function getActiveEntry(
  entries: SelectorEntry[],
  playlistId: string,
  activeEntryIndex: number,
): SelectorEntry | null {
  const forPlaylist = entries.filter((e) => e.playlistId === playlistId);
  return forPlaylist[activeEntryIndex] ?? forPlaylist[0] ?? null;
}
