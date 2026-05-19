import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useForm, FormProvider } from 'react-hook-form';
import type { PresetConfig } from '@/schemas/config-schema.ts';
import type { PreviewPlaylist, PreviewResult } from '@/schemas/api-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import {
  PreviewPlaylistSelector,
  generateEntries,
} from '@/components/editor/preview/preview-playlist-selector.tsx';

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string, opts?: Record<string, unknown>) => {
    // Minimal i18n stub: replace {{n}} and {{year}} placeholders
    if (!opts) return key;
    let out = key;
    for (const [k, v] of Object.entries(opts)) {
      out = out.replace(`{{${k}}}`, String(v));
    }
    return out;
  }}),
}));

// Mock Radix Select so tests don't rely on pointer-events / scrollIntoView APIs
// that jsdom does not implement. The mock exposes the same surface
// (value, onValueChange, options as <li> elements) so we can verify behaviour
// without fighting the Radix internals.
vi.mock('@/components/ui/select.tsx', () => {
  let capturedOnValueChange: ((v: string) => void) | undefined;

  return {
    Select: ({
      children,
      value,
      onValueChange,
    }: {
      children: React.ReactNode;
      value?: string;
      onValueChange?: (v: string) => void;
    }) => {
      capturedOnValueChange = onValueChange;
      return (
        <div data-testid="select" data-value={value}>
          {children}
        </div>
      );
    },
    SelectTrigger: ({ children }: { children: React.ReactNode }) => (
      <button role="combobox">{children}</button>
    ),
    SelectValue: ({ children }: { children: React.ReactNode }) => (
      <span data-testid="select-value">{children}</span>
    ),
    SelectContent: ({ children }: { children: React.ReactNode }) => (
      <ul>{children}</ul>
    ),
    SelectItem: ({
      children,
      value,
    }: {
      children: React.ReactNode;
      value: string;
    }) => (
      <li
        role="option"
        data-value={value}
        onClick={() => capturedOnValueChange?.(value)}
      >
        {children}
      </li>
    ),
  };
});

// -- Helpers --

/** Minimal i18n stub matching the mock above for use in pure function tests. */
function stubT(key: string, opts?: Record<string, unknown>): string {
  if (!opts) return key;
  let out = key;
  for (const [k, v] of Object.entries(opts)) {
    out = out.replace(`{{${k}}}`, String(v));
  }
  return out;
}

function makePreviewResult(
  playlists: PreviewResult['playlists'],
): PreviewResult {
  return {
    playlists,
    ungrouped: [],
    excluded: [],
    resolverType: null,
    debug: {
      totalEpisodes: 0,
      groupedEpisodes: 0,
      ungroupedEpisodes: 0,
      excludedEpisodes: 0,
    },
  };
}

function makePreviewPlaylist(
  id: string,
  displayName: string,
  groups: PreviewPlaylist['groups'],
): PreviewPlaylist {
  return {
    id,
    displayName,
    sortKey: id,
    episodeCount: groups?.reduce((s, g) => s + g.episodeCount, 0) ?? 0,
    yearBinding: 'none',
    claimedByOthers: [],
    groups,
  };
}

function makeGroup(
  id: string,
  displayName: string,
  episodes: { publishedAt?: string; seasonNumber?: number }[],
) {
  return {
    id,
    displayName,
    sortKey: id,
    episodeCount: episodes.length,
    episodes: episodes.map((ep, i) => ({
      id: i,
      title: `Episode ${i}`,
      publishedAt: ep.publishedAt ?? null,
      seasonNumber: ep.seasonNumber ?? null,
      episodeNumber: null,
      extractedDisplayName: null,
    })),
  };
}

interface WrapperConfig {
  config: PresetConfig;
  activePlaylistId: string;
  activeEntryIndex?: number;
  onSelectPlaylist?: (playlistId: string, entryIndex: number) => void;
  onSelectEntry?: (playlistId: string, entryIndex: number) => void;
}

function Wrapper({
  config,
  activePlaylistId,
  activeEntryIndex = 0,
  onSelectPlaylist = vi.fn(),
  onSelectEntry = vi.fn(),
}: WrapperConfig) {
  const form = useForm<PresetConfig>({ defaultValues: config });
  return (
    <FormProvider {...form}>
      <PreviewPlaylistSelector
        activePlaylistId={activePlaylistId}
        activeEntryIndex={activeEntryIndex}
        onSelectEntry={onSelectEntry}
        onSelectPlaylist={onSelectPlaylist}
      />
    </FormProvider>
  );
}

// ============================================================
// Pure function tests — generateEntries
// ============================================================

describe('generateEntries', () => {
  describe('partitionBy: undefined — one entry per playlist', () => {
    it('returns a single entry with displayName when partitionBy is undefined', () => {
      const entries = generateEntries('pl-a', 'Alpha', undefined, null, stubT);
      expect(entries).toHaveLength(1);
      expect(entries[0]).toMatchObject({ playlistId: 'pl-a', entryIndex: 0, label: 'Alpha', partitionValue: null });
    });

  });

  describe('partitionBy: year — one entry per distinct year', () => {
    it('returns one entry per distinct year from preview groups', () => {
      const preview = makePreviewPlaylist('pl', 'PL', [
        makeGroup('g1', 'G1', [{ publishedAt: '2024-06-01T00:00:00Z' }]),
        makeGroup('g2', 'G2', [{ publishedAt: '2025-01-15T00:00:00Z' }]),
        makeGroup('g3', 'G3', [{ publishedAt: '2024-11-30T00:00:00Z' }]),
      ]);
      const entries = generateEntries('pl', 'PL', 'year', preview, stubT);
      expect(entries).toHaveLength(2);
      // stubT produces 'selector.yearEntry' with {{year}} replaced
      expect(entries[0].label).toBe('selector.yearEntry'.replace('{{year}}', '2024'));
      expect(entries[0].partitionValue).toBe(2024);
      expect(entries[1].partitionValue).toBe(2025);
    });

    it('prefers server displayName when a custom selector titleExtractor is set', () => {
      const preview = makePreviewPlaylist('pl', 'PL', [
        {
          id: 'year_2024',
          displayName: 'Custom 2024 label',
          sortKey: 2024,
          episodeCount: 1,
          episodes: [
            { id: 1, title: 'ep', publishedAt: '2024-06-01T00:00:00Z', seasonNumber: null, episodeNumber: null, extractedDisplayName: null },
          ],
        },
      ]);
      const entries = generateEntries('pl', 'PL', 'year', preview, stubT, true);
      expect(entries[0].label).toBe('Custom 2024 label');
    });

    it('falls back to single entry when no preview data', () => {
      const entries = generateEntries('pl', 'PL', 'year', null, stubT);
      expect(entries).toHaveLength(1);
      expect(entries[0].label).toBe('PL');
    });
  });

  describe('partitionBy: seasonNumber — one entry per distinct season', () => {
    it('uses localized i18n label when no custom extractor is set', () => {
      const preview = makePreviewPlaylist('pl', 'PL', [
        makeGroup('g1', 'Season One', [{ seasonNumber: 1 }]),
        makeGroup('g2', 'Season Two', [{ seasonNumber: 2 }]),
      ]);
      const entries = generateEntries('pl', 'PL', 'seasonNumber', preview, stubT);
      expect(entries).toHaveLength(2);
      // Labels come from the localized i18n template, not server defaults
      expect(entries[0].label).toBe('selector.seasonEntry'.replace('{{n}}', '1'));
      expect(entries[0].partitionValue).toBe(1);
      expect(entries[1].label).toBe('selector.seasonEntry'.replace('{{n}}', '2'));
      expect(entries[1].partitionValue).toBe(2);
    });

    it('uses server displayName when a custom selector titleExtractor is set', () => {
      const preview = makePreviewPlaylist('pl', 'PL', [
        makeGroup('g1', 'シーズン 1', [{ seasonNumber: 1 }]),
        makeGroup('g2', 'シーズン 2', [{ seasonNumber: 2 }]),
      ]);
      const entries = generateEntries('pl', 'PL', 'seasonNumber', preview, stubT, true);
      expect(entries[0].label).toBe('シーズン 1');
      expect(entries[1].label).toBe('シーズン 2');
    });

    it('falls back to single displayName entry when no seasonNumber on episodes', () => {
      const preview = makePreviewPlaylist('pl', 'PL', [
        makeGroup('g1', 'Some Group', [{ publishedAt: '2024-01-01T00:00:00Z' }]),
      ]);
      const entries = generateEntries('pl', 'PL', 'seasonNumber', preview, stubT);
      // collectUniqueSeasonNumbers returns [] because no seasonNumber on episodes,
      // so falls back to single displayName entry
      expect(entries).toHaveLength(1);
      expect(entries[0].label).toBe('PL');
    });

    it('mixes matched and fallback labels under a custom extractor', () => {
      const preview = makePreviewPlaylist('pl', 'PL', [
        makeGroup('g1', 'シーズン 1', [{ seasonNumber: 1 }]),
      ]);
      const previewCustom: PreviewPlaylist = {
        ...preview,
        groups: [
          ...preview.groups!,
          {
            id: 'g2',
            displayName: 'g2',
            sortKey: 'g2',
            episodeCount: 0,
            episodes: [{ id: 99, title: 'ep', publishedAt: null, seasonNumber: 2, episodeNumber: null, extractedDisplayName: null }],
          },
        ],
      };
      const entries = generateEntries('pl', 'PL', 'seasonNumber', previewCustom, stubT, true);
      expect(entries[0].label).toBe('シーズン 1');
      expect(entries[1].label).toBe('g2');
    });

    it('returns i18n fallback label when no preview data', () => {
      const entries = generateEntries('pl', 'PL', 'seasonNumber', null, stubT);
      expect(entries).toHaveLength(1);
      expect(entries[0].label).toBe('PL');
    });
  });
});

// ============================================================
// Component tests
// ============================================================

describe('PreviewPlaylistSelector', () => {
  beforeEach(() => {
    useEditorStore.getState().reset();
  });

  describe('trigger label', () => {
    it('shows the displayName of the active playlist when no preview data', () => {
      const config: PresetConfig = {
        id: 'test',
        displayName: 'Test',
        yearGroupedEpisodes: false,
        playlists: [
          { id: 'pl-a', displayName: 'Alpha', grouping: { by: 'seasonNumber' }, priority: 0 },
          { id: 'pl-b', displayName: 'Beta', grouping: { by: 'seasonNumber' }, priority: 1 },
        ],
      };

      render(<Wrapper config={config} activePlaylistId="pl-b" />);

      expect(screen.getByTestId('select-value')).toHaveTextContent('Beta');
    });
  });

  describe('entry rendering — partitionBy: undefined', () => {
    it('renders one option per playlist', () => {
      const config: PresetConfig = {
        id: 'test',
        displayName: 'Test',
        yearGroupedEpisodes: false,
        playlists: [
          { id: 'pl-a', displayName: 'Alpha', grouping: { by: 'seasonNumber' }, priority: 0 },
          { id: 'pl-b', displayName: 'Beta', grouping: { by: 'seasonNumber' }, priority: 1 },
        ],
      };

      render(<Wrapper config={config} activePlaylistId="pl-a" />);

      const options = screen.getAllByRole('option');
      expect(options.map((o) => o.textContent)).toEqual(['Alpha', 'Beta']);
    });
  });

  describe('entry rendering — partitionBy: year', () => {
    it('renders one option per distinct year plus other playlists as single entries', () => {
      const config: PresetConfig = {
        id: 'test',
        displayName: 'Test',
        yearGroupedEpisodes: false,
        playlists: [
          {
            id: 'pl-year',
            displayName: 'Year Playlist',
            grouping: { by: 'seasonNumber' },
            priority: 0,
            selector: { partitionBy: 'year' },
          },
          {
            id: 'pl-other',
            displayName: 'Other',
            grouping: { by: 'seasonNumber' },
            priority: 1,
          },
        ],
      };

      useEditorStore.getState().setPreviewData(
        makePreviewResult([
          makePreviewPlaylist('pl-year', 'Year Playlist', [
            makeGroup('g1', 'G1', [{ publishedAt: '2024-06-01T00:00:00Z' }]),
            makeGroup('g2', 'G2', [{ publishedAt: '2025-01-15T00:00:00Z' }]),
          ]),
        ]),
      );

      render(<Wrapper config={config} activePlaylistId="pl-year" />);

      const options = screen.getAllByRole('option');
      const labels = options.map((o) => o.textContent);
      // The i18n stub receives key 'selector.yearEntry' and opts {year: 2024/2025}.
      // The key string itself doesn't contain the placeholder so the stub returns
      // the key unchanged: 'selector.yearEntry'. We verify two such entries exist
      // (one per distinct year) plus the 'Other' playlist.
      expect(labels.filter((l) => l === 'selector.yearEntry')).toHaveLength(2);
      expect(labels).toContain('Other');
    });
  });

  describe('entry rendering — partitionBy: seasonNumber uses group displayName', () => {
    it('renders season entries using group displayName when custom selector titleExtractor is configured', () => {
      const config: PresetConfig = {
        id: 'test',
        displayName: 'Test',
        yearGroupedEpisodes: false,
        playlists: [
          {
            id: 'pl-season',
            displayName: 'Season Playlist',
            grouping: { by: 'seasonNumber' },
            priority: 0,
            selector: {
              partitionBy: 'seasonNumber',
              // Custom extractor opts the playlist into server-provided labels
              // rather than the localized "selector.seasonEntry" fallback.
              titleExtractor: { source: 'title', pattern: '(.+)' },
            },
          },
        ],
      };

      useEditorStore.getState().setPreviewData(
        makePreviewResult([
          makePreviewPlaylist('pl-season', 'Season Playlist', [
            makeGroup('g1', 'Season One', [{ seasonNumber: 1 }]),
            makeGroup('g2', 'Season Two', [{ seasonNumber: 2 }]),
          ]),
        ]),
      );

      render(<Wrapper config={config} activePlaylistId="pl-season" />);

      const options = screen.getAllByRole('option');
      const labels = options.map((o) => o.textContent);
      expect(labels).toContain('Season One');
      expect(labels).toContain('Season Two');
      // Raw numbers should not appear as standalone labels
      expect(labels).not.toContain('1');
      expect(labels).not.toContain('2');
    });
  });

  describe('cross-playlist selection', () => {
    it('calls onSelectPlaylist when clicking an option from a different playlist', async () => {
      const user = userEvent.setup();
      const onSelectPlaylist = vi.fn();
      const config: PresetConfig = {
        id: 'test',
        displayName: 'Test',
        yearGroupedEpisodes: false,
        playlists: [
          { id: 'pl-a', displayName: 'Alpha', grouping: { by: 'seasonNumber' }, priority: 0 },
          { id: 'pl-b', displayName: 'Beta', grouping: { by: 'seasonNumber' }, priority: 1 },
        ],
      };

      render(
        <Wrapper
          config={config}
          activePlaylistId="pl-a"
          onSelectPlaylist={onSelectPlaylist}
        />,
      );

      const betaOption = screen.getByRole('option', { name: 'Beta' });
      await user.click(betaOption);

      // Signature is now (playlistId, entryIndex); non-partitioned entry is 0.
      expect(onSelectPlaylist).toHaveBeenCalledWith('pl-b', 0);
    });

    it('calls onSelectPlaylist when active is pl-1 and user clicks entry from pl-2', async () => {
      const user = userEvent.setup();
      const onSelectPlaylist = vi.fn();
      const config: PresetConfig = {
        id: 'test',
        displayName: 'Test',
        yearGroupedEpisodes: false,
        playlists: [
          { id: 'pl-1', displayName: 'Playlist One', grouping: { by: 'seasonNumber' }, priority: 0 },
          { id: 'pl-2', displayName: 'Playlist Two', grouping: { by: 'seasonNumber' }, priority: 1 },
        ],
      };

      render(
        <Wrapper
          config={config}
          activePlaylistId="pl-1"
          onSelectPlaylist={onSelectPlaylist}
        />,
      );

      const pl2Option = screen.getByRole('option', { name: 'Playlist Two' });
      await user.click(pl2Option);

      // Entry 0 is the default single entry for a non-partitioned playlist.
      expect(onSelectPlaylist).toHaveBeenCalledWith('pl-2', 0);
    });

    it('calls onSelectEntry with new index when clicking a different entry within the same playlist', async () => {
      const user = userEvent.setup();
      const onSelectEntry = vi.fn();
      const config: PresetConfig = {
        id: 'test',
        displayName: 'Test',
        yearGroupedEpisodes: false,
        playlists: [
          {
            id: 'pl-1',
            displayName: 'Playlist One',
            grouping: { by: 'seasonNumber' },
            priority: 0,
            selector: { partitionBy: 'year' },
          },
        ],
      };

      useEditorStore.getState().setPreviewData(
        makePreviewResult([
          makePreviewPlaylist('pl-1', 'Playlist One', [
            makeGroup('g1', 'G1', [{ publishedAt: '2023-03-01T00:00:00Z' }]),
            makeGroup('g2', 'G2', [{ publishedAt: '2024-06-01T00:00:00Z' }]),
          ]),
        ]),
      );

      render(
        <Wrapper
          config={config}
          activePlaylistId="pl-1"
          activeEntryIndex={0}
          onSelectEntry={onSelectEntry}
        />,
      );

      // Two year entries are rendered; click the second one (entryIndex 1 = 2024).
      const yearOptions = screen.getAllByRole('option').filter(
        (o) => o.textContent === 'selector.yearEntry',
      );
      expect(yearOptions.length).toBe(2);
      await user.click(yearOptions[1]!);

      expect(onSelectEntry).toHaveBeenCalledWith('pl-1', 1);
    });

    it('does not call onSelectPlaylist when clicking a same-playlist year entry', async () => {
      const user = userEvent.setup();
      const onSelectPlaylist = vi.fn();
      const config: PresetConfig = {
        id: 'test',
        displayName: 'Test',
        yearGroupedEpisodes: false,
        playlists: [
          {
            id: 'pl-year',
            displayName: 'Year Playlist',
            grouping: { by: 'seasonNumber' },
            priority: 0,
            selector: { partitionBy: 'year' },
          },
        ],
      };

      useEditorStore.getState().setPreviewData(
        makePreviewResult([
          makePreviewPlaylist('pl-year', 'Year Playlist', [
            makeGroup('g1', 'G1', [{ publishedAt: '2024-06-01T00:00:00Z' }]),
            makeGroup('g2', 'G2', [{ publishedAt: '2025-01-15T00:00:00Z' }]),
          ]),
        ]),
      );

      render(
        <Wrapper
          config={config}
          activePlaylistId="pl-year"
          onSelectPlaylist={onSelectPlaylist}
        />,
      );

      // The i18n stub returns 'selector.yearEntry' for year labels (key unchanged
      // since the key itself lacks the {{year}} placeholder). Both year entries
      // share the same text content; click the second one (index 1 = 2025 entry).
      const yearOptions = screen.getAllByRole('option').filter(
        (o) => o.textContent === 'selector.yearEntry',
      );
      expect(yearOptions.length).toBe(2);
      await user.click(yearOptions[1]!);

      expect(onSelectPlaylist).not.toHaveBeenCalled();
    });
  });
});
