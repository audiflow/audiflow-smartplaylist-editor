import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ExtractionPreview } from '../extraction-preview.tsx';
import type { PreviewPlaylist } from '@/schemas/api-schema.ts';

const playlistWithEnrichedData: PreviewPlaylist = {
  id: 'playlist-1',
  displayName: 'Season 1',
  sortKey: 1,
  episodeCount: 2,
  claimedByOthers: [],
  groups: [
    {
      id: 'group-1',
      displayName: 'Group 1',
      sortKey: 1,
      episodeCount: 2,
      episodes: [
        {
          id: 101,
          title: 'S01E01 - The Beginning',
          publishedAt: '2024-01-01T00:00:00Z',
          seasonNumber: 1,
          episodeNumber: 1,
          extractedDisplayName: 'The Beginning',
        },
        {
          id: 102,
          title: 'S01E02 - Rising Action',
          publishedAt: '2024-01-08T00:00:00Z',
          seasonNumber: 1,
          episodeNumber: 2,
          extractedDisplayName: 'Rising Action',
        },
      ],
    },
  ],
};

const playlistWithNoEnrichment: PreviewPlaylist = {
  id: 'playlist-2',
  displayName: 'Plain Playlist',
  sortKey: 2,
  episodeCount: 2,
  claimedByOthers: [],
  groups: [
    {
      id: 'group-2',
      displayName: 'Group 2',
      sortKey: 1,
      episodeCount: 2,
      episodes: [
        {
          id: 201,
          title: 'Episode 1',
          publishedAt: null,
          seasonNumber: null,
          episodeNumber: null,
          extractedDisplayName: null,
        },
        {
          id: 202,
          title: 'Episode 2',
          publishedAt: null,
          seasonNumber: null,
          episodeNumber: null,
          extractedDisplayName: null,
        },
      ],
    },
  ],
};

describe('ExtractionPreview', () => {
  it('renders extraction table with enriched episode data', () => {
    render(<ExtractionPreview playlist={playlistWithEnrichedData} />);
    expect(screen.getByText('The Beginning')).toBeInTheDocument();
    expect(screen.getByText('Rising Action')).toBeInTheDocument();
  });

  it('renders nothing when no episodes have extraction data', () => {
    const { container } = render(<ExtractionPreview playlist={playlistWithNoEnrichment} />);
    expect(container.firstChild).toBeNull();
  });
});
