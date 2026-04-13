import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useForm, FormProvider } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import type { PreviewPlaylist, PreviewResult } from '@/schemas/api-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import {
  PreviewPlaylistSelector,
  generateEntries,
} from '@/components/editor/preview/preview-playlist-selector.tsx';

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key }),
}));

// Mock Radix Select so tests don't rely on pointer-events / scrollIntoView APIs
// that jsdom does not implement. The mock exposes the same surface
// (value, onValueChange, options as <li> elements) so we can verify behaviour
// without fighting the Radix internals.
vi.mock('@/components/ui/select.tsx', () => ({
  Select: ({
    children,
    value,
    onValueChange,
  }: {
    children: React.ReactNode;
    value?: string;
    onValueChange?: (v: string) => void;
  }) => (
    <div data-testid="select" data-value={value} data-on-change={String(onValueChange)}>
      {/* Provide a button that triggers selection via data attributes in tests */}
      {children}
    </div>
  ),
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
    onClick,
  }: {
    children: React.ReactNode;
    value: string;
    onClick?: () => void;
  }) => (
    <li
      role="option"
      data-value={value}
      onClick={onClick}
    >
      {children}
    </li>
  ),
}));

// After mocking Select, the onValueChange wiring won't work through the mock
// automatically. We need to wire it manually. Let's use a proper mock that
// captures onValueChange and calls it when an option is clicked.
// Re-mock more carefully:

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
  episodes: { publishedAt?: string; seasonNumber?: number }[],
) {
  return {
    id,
    displayName: id,
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
  config: PatternConfig;
  activePlaylistId: string;
  onSelectPlaylist?: (id: string) => void;
}

function Wrapper({
  config,
  activePlaylistId,
  onSelectPlaylist = vi.fn(),
}: WrapperConfig) {
  const form = useForm<PatternConfig>({ defaultValues: config });
  return (
    <FormProvider {...form}>
      <PreviewPlaylistSelector
        activePlaylistId={activePlaylistId}
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
      const entries = generateEntries('pl-a', 'Alpha', undefined, null);
      expect(entries).toHaveLength(1);
      expect(entries[0]).toEqual({ playlistId: 'pl-a', entryIndex: 0, label: 'Alpha' });
    });

    it('returns a single entry for partitionBy: group (deferred)', () => {
      const entries = generateEntries('pl-a', 'Alpha', 'group', null);
      expect(entries).toHaveLength(1);
      expect(entries[0].label).toBe('Alpha');
    });
  });

  describe('partitionBy: year — one entry per distinct year', () => {
    it('returns one entry per distinct year from preview groups', () => {
      const preview = makePreviewPlaylist('pl', 'PL', [
        makeGroup('g1', [{ publishedAt: '2024-06-01T00:00:00Z' }]),
        makeGroup('g2', [{ publishedAt: '2025-01-15T00:00:00Z' }]),
        makeGroup('g3', [{ publishedAt: '2024-11-30T00:00:00Z' }]),
      ]);
      const entries = generateEntries('pl', 'PL', 'year', preview);
      expect(entries).toHaveLength(2);
      expect(entries[0].label).toBe('2024');
      expect(entries[1].label).toBe('2025');
    });

    it('falls back to single entry when no preview data', () => {
      const entries = generateEntries('pl', 'PL', 'year', null);
      expect(entries).toHaveLength(1);
      expect(entries[0].label).toBe('PL');
    });
  });

  describe('partitionBy: seasonNumber — one entry per distinct season', () => {
    it('returns one entry per distinct season number', () => {
      const preview = makePreviewPlaylist('pl', 'PL', [
        makeGroup('g1', [{ seasonNumber: 1 }]),
        makeGroup('g2', [{ seasonNumber: 2 }]),
        makeGroup('g3', [{ seasonNumber: 1 }]),
      ]);
      const entries = generateEntries('pl', 'PL', 'seasonNumber', preview);
      expect(entries).toHaveLength(2);
      expect(entries[0].label).toBe('1');
      expect(entries[1].label).toBe('2');
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
      const config: PatternConfig = {
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
      const config: PatternConfig = {
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
      const config: PatternConfig = {
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
            makeGroup('g1', [{ publishedAt: '2024-06-01T00:00:00Z' }]),
            makeGroup('g2', [{ publishedAt: '2025-01-15T00:00:00Z' }]),
          ]),
        ]),
      );

      render(<Wrapper config={config} activePlaylistId="pl-year" />);

      const options = screen.getAllByRole('option');
      const labels = options.map((o) => o.textContent);
      expect(labels).toContain('2024');
      expect(labels).toContain('2025');
      expect(labels).toContain('Other');
    });
  });

  describe('cross-playlist selection', () => {
    it('calls onSelectPlaylist when clicking an option from a different playlist', async () => {
      const user = userEvent.setup();
      const onSelectPlaylist = vi.fn();
      const config: PatternConfig = {
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

      expect(onSelectPlaylist).toHaveBeenCalledWith('pl-b');
    });

    it('does not call onSelectPlaylist when clicking a same-playlist year entry', async () => {
      const user = userEvent.setup();
      const onSelectPlaylist = vi.fn();
      const config: PatternConfig = {
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
            makeGroup('g1', [{ publishedAt: '2024-06-01T00:00:00Z' }]),
            makeGroup('g2', [{ publishedAt: '2025-01-15T00:00:00Z' }]),
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

      const year2025 = screen.getByRole('option', { name: '2025' });
      await user.click(year2025);

      expect(onSelectPlaylist).not.toHaveBeenCalled();
    });
  });
});
