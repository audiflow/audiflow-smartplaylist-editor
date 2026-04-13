import { useState, useEffect, useMemo } from 'react';
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
};

// -- Entry generation --

export function generateEntries(
  playlistId: string,
  displayName: string,
  partitionBy: PartitionBy | undefined,
  previewPlaylist: PreviewPlaylist | null | undefined,
): SelectorEntry[] {
  if (partitionBy === 'seasonNumber') {
    const seasons = collectUniqueSeasonNumbers(previewPlaylist);
    if (0 < seasons.length) {
      return seasons.map((s, i) => ({
        playlistId,
        entryIndex: i,
        label: String(s),
      }));
    }
  }

  if (partitionBy === 'year') {
    const years = collectUniqueYears(previewPlaylist);
    if (0 < years.length) {
      return years.map((y, i) => ({
        playlistId,
        entryIndex: i,
        label: String(y),
      }));
    }
  }

  // TODO: partitionBy: 'group' is intentionally deferred — title-length issue
  //       prevents reliable label generation. Render as a single entry until
  //       the next iteration resolves the display strategy.
  return [{ playlistId, entryIndex: 0, label: displayName }];
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
    const publishedAt = group.episodes[0]?.publishedAt;
    if (publishedAt) {
      const year = new Date(publishedAt).getFullYear();
      if (!seen.has(year)) {
        seen.add(year);
        result.push(year);
      }
    }
  }
  return result;
}

// -- Component --

interface PreviewPlaylistSelectorProps {
  activePlaylistId: string;
  onSelectPlaylist: (playlistId: string) => void;
}

export function PreviewPlaylistSelector({
  activePlaylistId,
  onSelectPlaylist,
}: PreviewPlaylistSelectorProps) {
  const { control } = useFormContext<PatternConfig>();
  const playlists = useWatch({ control, name: 'playlists' });
  const previewData = useEditorStore((s) => s.previewData);

  // Track the selected entry within the active playlist (resets when playlist changes).
  const [activeEntryIndex, setActiveEntryIndex] = useState(0);
  useEffect(() => {
    setActiveEntryIndex(0);
  }, [activePlaylistId]);

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
      );
    });
  }, [playlists, previewData]);

  // Compose a unique value for each entry to use as the Select value key.
  function entryKey(entry: SelectorEntry): string {
    return `${entry.playlistId}:${entry.entryIndex}`;
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
    const pl = playlists?.find((p) => p.id === activePlaylistId);
    return `${activePlaylistId}:0:${pl?.displayName ?? ''}`;
  }, [allEntries, activePlaylistId, activeEntryIndex, playlists]);

  const selectedLabel = useMemo((): string => {
    const entry = allEntries.find((e) => entryKey(e) === selectedKey);
    if (entry) return entry.label;
    const pl = playlists?.find((p) => p.id === activePlaylistId);
    return pl?.displayName ?? '';
  }, [allEntries, selectedKey, activePlaylistId, playlists]);

  function handleSelect(value: string): void {
    const entry = allEntries.find((e) => entryKey(e) === value);
    if (!entry) return;

    if (entry.playlistId !== activePlaylistId) {
      onSelectPlaylist(entry.playlistId);
      // activeEntryIndex will reset to 0 via useEffect
    } else {
      setActiveEntryIndex(entry.entryIndex);
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
