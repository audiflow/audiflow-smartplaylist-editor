import { render, screen } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { FilteredEpisodesPanel } from '../filtered-episodes-panel.tsx';
import type { FeedEpisode } from '@/schemas/api-schema.ts';

vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, opts?: Record<string, unknown>) =>
      opts?.count !== undefined ? `${opts.count} episodes` : key,
  }),
}));

const episodes: FeedEpisode[] = [
  { id: 1, title: 'Episode 1', description: null, guid: null, publishedAt: null, seasonNumber: null, episodeNumber: null, imageUrl: null },
  { id: 2, title: 'Episode 2', description: null, guid: null, publishedAt: null, seasonNumber: null, episodeNumber: null, imageUrl: null },
];

describe('FilteredEpisodesPanel', () => {
  it('renders episode list with count', () => {
    render(
      <FilteredEpisodesPanel
        episodes={episodes}
        totalCount={5}
        feedLoaded
      />,
    );
    expect(screen.getByText('Episode 1')).toBeInTheDocument();
    expect(screen.getByText('Episode 2')).toBeInTheDocument();
  });

  it('shows empty message when no episodes match', () => {
    render(
      <FilteredEpisodesPanel
        episodes={[]}
        totalCount={5}
        feedLoaded
      />,
    );
    expect(screen.getByText('emptyFiltered')).toBeInTheDocument();
  });

  it('shows no-feed message when feed is not loaded', () => {
    render(
      <FilteredEpisodesPanel
        episodes={[]}
        totalCount={0}
        feedLoaded={false}
      />,
    );
    expect(screen.getByText('noFeedLoaded')).toBeInTheDocument();
  });
});
