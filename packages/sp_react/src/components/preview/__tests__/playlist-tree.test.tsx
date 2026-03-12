import { describe, it, expect } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { PlaylistTree } from '../playlist-tree.tsx';
import type { PreviewPlaylist, PreviewGroup, PreviewEpisode } from '@/schemas/api-schema.ts';
import type { EpisodeSortRule } from '../episode-sort-utils.ts';

function makeEpisode(
  overrides: Partial<PreviewEpisode> & { id: number },
): PreviewEpisode {
  return {
    title: `Episode ${overrides.id}`,
    publishedAt: null,
    seasonNumber: null,
    episodeNumber: null,
    extractedDisplayName: null,
    ...overrides,
  };
}

function makeGroup(
  id: string,
  episodes: PreviewEpisode[],
  overrides?: Partial<PreviewGroup>,
): PreviewGroup {
  return {
    id,
    displayName: id,
    sortKey: 0,
    episodeCount: episodes.length,
    episodes,
    ...overrides,
  };
}

function makePlaylist(
  id: string,
  groups: PreviewGroup[],
  overrides?: Partial<PreviewPlaylist>,
): PreviewPlaylist {
  return {
    id,
    displayName: id,
    sortKey: 0,
    resolverType: null,
    episodeCount: groups.reduce((sum, g) => sum + g.episodeCount, 0),
    yearBinding: 'none',
    groups,
    claimedByOthers: [],
    ...overrides,
  };
}

/** Clicks all accordion triggers to expand content, then returns episode titles in DOM order. */
async function expandAndGetEpisodeTitles(container: HTMLElement): Promise<string[]> {
  const user = userEvent.setup();
  const triggers = container.querySelectorAll<HTMLButtonElement>('[data-slot="accordion-trigger"]');
  for (const trigger of triggers) {
    await user.click(trigger);
  }
  const items = container.querySelectorAll('li');
  return Array.from(items).map((li) => {
    const span = li.querySelector('span.truncate');
    return span?.textContent ?? '';
  });
}

// Shared episodes
const ep2024a = makeEpisode({ id: 1, title: 'Alpha', publishedAt: '2024-03-01T00:00:00Z', episodeNumber: 3 });
const ep2024b = makeEpisode({ id: 2, title: 'Beta', publishedAt: '2024-08-15T00:00:00Z', episodeNumber: 1 });
const ep2025a = makeEpisode({ id: 3, title: 'Charlie', publishedAt: '2025-01-10T00:00:00Z', episodeNumber: 2 });
const ep2025b = makeEpisode({ id: 4, title: 'Delta', publishedAt: '2025-06-20T00:00:00Z', episodeNumber: 4 });

describe('PlaylistTree', () => {
  describe('baseline rendering (no year binding, no sort rules)', () => {
    it('renders groups with correct names and episode counts', () => {
      const playlist = makePlaylist('p1', [
        makeGroup('g1', [ep2024a, ep2024b], { displayName: 'Group One' }),
        makeGroup('g2', [ep2025a], { displayName: 'Group Two' }),
      ]);

      render(<PlaylistTree playlists={[playlist]} />);

      expect(screen.getByText('Group One')).toBeInTheDocument();
      expect(screen.getByText('2 episodes')).toBeInTheDocument();
      expect(screen.getByText('Group Two')).toBeInTheDocument();
      expect(screen.getByText('1 episode')).toBeInTheDocument();
    });

    it('renders episodes in server-returned order', async () => {
      const playlist = makePlaylist('p1', [
        makeGroup('g1', [ep2024b, ep2025a, ep2024a]),
      ]);

      const { container } = render(<PlaylistTree playlists={[playlist]} />);
      const titles = await expandAndGetEpisodeTitles(container);
      expect(titles).toEqual(['Beta', 'Charlie', 'Alpha']);
    });

    it('shows no-groups message when playlist has no groups', () => {
      const playlist = makePlaylist('p1', []);

      render(<PlaylistTree playlists={[playlist]} />);
      expect(screen.getByText('No groups')).toBeInTheDocument();
    });
  });

  describe('episode sort rules applied per-group', () => {
    it('sorts a group by its specific rule', async () => {
      const playlist = makePlaylist('p1', [
        makeGroup('g1', [ep2024a, ep2024b, ep2025a]),
      ]);
      const rules = new Map<string, EpisodeSortRule>([
        ['g1', { field: 'episodeNumber', order: 'descending' }],
      ]);

      const { container } = render(
        <PlaylistTree playlists={[playlist]} episodeSortRules={rules} />,
      );
      const titles = await expandAndGetEpisodeTitles(container);
      // episodeNumbers: Alpha=3, Beta=1, Charlie=2 -> descending: 3,2,1
      expect(titles).toEqual(['Alpha', 'Charlie', 'Beta']);
    });

    it('uses _default rule for groups without a specific rule', async () => {
      const playlist = makePlaylist('p1', [
        makeGroup('g1', [ep2024a, ep2024b, ep2025a]),
        makeGroup('g2', [ep2025b, ep2025a]),
      ]);
      const rules = new Map<string, EpisodeSortRule>([
        ['g1', { field: 'episodeNumber', order: 'ascending' }],
        ['_default', { field: 'publishedAt', order: 'descending' }],
      ]);

      const { container } = render(
        <PlaylistTree playlists={[playlist]} episodeSortRules={rules} />,
      );

      // g1: episodeNumber ascending: Beta(1), Charlie(2), Alpha(3)
      // g2: _default publishedAt descending: Delta(2025-06), Charlie(2025-01)
      const titles = await expandAndGetEpisodeTitles(container);
      expect(titles).toEqual(['Beta', 'Charlie', 'Alpha', 'Delta', 'Charlie']);
    });

    it('leaves episodes unsorted when no rules provided', async () => {
      const playlist = makePlaylist('p1', [
        makeGroup('g1', [ep2025a, ep2024a, ep2024b]),
      ]);

      const { container } = render(<PlaylistTree playlists={[playlist]} />);
      const titles = await expandAndGetEpisodeTitles(container);
      expect(titles).toEqual(['Charlie', 'Alpha', 'Beta']);
    });
  });

  describe('year binding + episode sorting composed', () => {
    it('renders year sections with sorted episodes within each year', async () => {
      const playlist = makePlaylist('p1', [
        makeGroup('g1', [ep2024a, ep2024b, ep2025a, ep2025b]),
      ]);
      const rules = new Map<string, EpisodeSortRule>([
        ['_default', { field: 'episodeNumber', order: 'ascending' }],
      ]);

      const { container } = render(
        <PlaylistTree
          playlists={[playlist]}
          yearBinding="splitByYear"
          episodeSortRules={rules}
        />,
      );

      // Year sections should appear: 2025 first (descending), then 2024
      const yearHeaders = screen.getAllByText(/^\d{4}$/);
      expect(yearHeaders.map((el) => el.textContent)).toEqual(['2025', '2024']);

      // Expand all accordions to reveal episode content
      const titles = await expandAndGetEpisodeTitles(container);
      // 2025 section: Charlie(epNum=2), Delta(epNum=4) -> ascending: Charlie, Delta
      // 2024 section: Alpha(epNum=3), Beta(epNum=1) -> ascending: Beta, Alpha
      expect(titles).toEqual(['Charlie', 'Delta', 'Beta', 'Alpha']);
    });

    it('shows unknown year header for episodes without dates', async () => {
      const epNoDate = makeEpisode({ id: 10, title: 'Timeless' });
      const playlist = makePlaylist('p1', [
        makeGroup('g1', [epNoDate]),
      ]);

      const { container } = render(
        <PlaylistTree playlists={[playlist]} yearBinding="splitByYear" />,
      );

      expect(screen.getByText('Unknown Year')).toBeInTheDocument();

      // Expand accordion to see episode content
      const user = userEvent.setup();
      const trigger = container.querySelector<HTMLButtonElement>('[data-slot="accordion-trigger"]')!;
      await user.click(trigger);

      expect(screen.getByText('Timeless')).toBeInTheDocument();
    });
  });

  describe('per-group year binding overrides', () => {
    it('applies different year strategies per group', () => {
      const playlist = makePlaylist('p1', [
        makeGroup('g1', [ep2024a, ep2025a], { displayName: 'Group One' }),
        makeGroup('g2', [ep2024b, ep2025b], { displayName: 'Group Two' }),
      ]);
      const overrides = new Map([
        ['g1', 'splitByYear' as const],
        ['g2', 'pinToYear' as const],
      ]);

      render(
        <PlaylistTree
          playlists={[playlist]}
          yearBinding="none"
          groupYearBindingOverrides={overrides}
        />,
      );

      // Year sections should appear (2025 first, 2024 second)
      const yearHeaders = screen.getAllByText(/^\d{4}$/);
      expect(yearHeaders.map((el) => el.textContent)).toEqual(['2025', '2024']);

      // g1 splitByYear: appears in both 2025 and 2024 year sections
      const groupOneElements = screen.getAllByText('Group One');
      expect(2 <= groupOneElements.length).toBe(true);

      // g2 pinToYear: pinned to 2024 (first episode year), appears once
      const groupTwoElements = screen.getAllByText('Group Two');
      expect(groupTwoElements).toHaveLength(1);

      // g2 pinned under 2024, so find the 2024 year section and verify g2 is there
      const year2024Header = yearHeaders.find((el) => el.textContent === '2024')!;
      const year2024Section = year2024Header.closest('div[class]')!.parentElement!;
      expect(within(year2024Section).getByText('Group Two')).toBeInTheDocument();
    });
  });

  describe('prependSeasonNumber formatting', () => {
    it('prepends season number for groups with season_ id prefix', () => {
      const playlist = makePlaylist('p1', [
        makeGroup('season_1', [ep2024a], {
          displayName: 'First Season',
          sortKey: 1,
        }),
        makeGroup('category_drama', [ep2024b], {
          displayName: 'Drama',
        }),
      ]);

      render(<PlaylistTree playlists={[playlist]} prependSeasonNumber />);

      expect(screen.getByText('S1 First Season')).toBeInTheDocument();
      expect(screen.getByText('Drama')).toBeInTheDocument();
    });

    it('does not prepend when prependSeasonNumber is false', () => {
      const playlist = makePlaylist('p1', [
        makeGroup('season_1', [ep2024a], {
          displayName: 'First Season',
          sortKey: 1,
        }),
      ]);

      render(<PlaylistTree playlists={[playlist]} />);

      expect(screen.getByText('First Season')).toBeInTheDocument();
      expect(screen.queryByText('S1 First Season')).not.toBeInTheDocument();
    });
  });
});
