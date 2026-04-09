import type { PatternSummary, PatternIdentifiers, FeedEpisode, PreviewResult } from '@/schemas/api-schema.ts';
import type { PatternConfig, PlaylistDefinition } from '@/schemas/config-schema.ts';

// -- Pattern summaries (browse page) --

export const PATTERN_SUMMARIES: PatternSummary[] = [
  {
    id: 'pattern-1',
    dataVersion: 1,
    displayName: 'Test Podcast Alpha',
    feedUrlHint: 'https://example.com/alpha/feed.xml',
    playlistCount: 2,
  },
  {
    id: 'pattern-2',
    dataVersion: 1,
    displayName: 'Test Podcast Beta',
    feedUrlHint: 'https://example.com/beta/feed.xml',
    playlistCount: 1,
  },
];

// -- Pattern identifiers (duplicate check) --

export const PATTERN_IDENTIFIERS: PatternIdentifiers[] = [
  {
    id: 'pattern-1',
    podcastGuid: 'guid-alpha-111',
    feedUrls: ['https://example.com/alpha/feed.xml'],
  },
  {
    id: 'pattern-2',
    podcastGuid: 'guid-beta-222',
    feedUrls: ['https://example.com/beta/feed.xml'],
  },
];

// -- Playlist definitions --

export const PLAYLIST_SEASON: PlaylistDefinition = {
  id: 'seasons',
  displayName: 'By Season',
  resolverType: 'seasonNumber',
  presentation: 'separate',
  priority: 0,
  prependSeasonNumber: false,
  groups: [
    {
      id: 'season-1',
      displayName: 'Season 1',
      pattern: '^S01',
    },
  ],
};

export const PLAYLIST_CATEGORY: PlaylistDefinition = {
  id: 'topics',
  displayName: 'By Topic',
  resolverType: 'titleClassifier',
  presentation: 'combined',
  priority: 1,
  prependSeasonNumber: false,
  groups: [
    {
      id: 'interviews',
      displayName: 'Interviews',
      pattern: 'interview',
    },
    {
      id: 'deep-dives',
      displayName: 'Deep Dives',
      pattern: 'deep.dive',
    },
  ],
};

// -- Full pattern config --

export const VALID_PATTERN_CONFIG: PatternConfig = {
  id: 'pattern-1',
  displayName: 'Test Podcast Alpha',
  podcastGuid: 'guid-alpha-111',
  feedUrls: ['https://example.com/alpha/feed.xml'],
  yearGroupedEpisodes: false,
  playlists: [PLAYLIST_SEASON, PLAYLIST_CATEGORY],
};

export const MINIMAL_PATTERN_CONFIG: PatternConfig = {
  id: 'pattern-minimal',
  displayName: '',
  feedUrls: [],
  yearGroupedEpisodes: false,
  playlists: [],
};

// -- Feed episodes --

export const FEED_EPISODES: FeedEpisode[] = Array.from({ length: 10 }, (_, i) => ({
  id: i + 1,
  title: `Episode ${i + 1}: Test Title ${i + 1}`,
  description: i % 3 === 0 ? null : `Description for episode ${i + 1}`,
  guid: `guid-ep-${i + 1}`,
  publishedAt: i % 4 === 0 ? null : `2025-0${(i % 9) + 1}-15T00:00:00Z`,
  seasonNumber: i % 5 === 0 ? null : Math.ceil((i + 1) / 3),
  episodeNumber: i + 1,
  imageUrl: i % 2 === 0 ? null : `https://example.com/ep${i + 1}.jpg`,
}));

// -- Preview result --

export const PREVIEW_RESULT: PreviewResult = {
  playlists: [
    {
      id: 'seasons',
      displayName: 'By Season',
      sortKey: 0,
      resolverType: 'seasonNumber',
      episodeCount: 7,
      yearBinding: 'none',
      groups: [
        {
          id: 'season-1',
          displayName: 'Season 1',
          sortKey: 1,
          episodeCount: 4,
          episodes: FEED_EPISODES.slice(0, 4).map((ep) => ({
            id: ep.id,
            title: ep.title,
            publishedAt: ep.publishedAt,
            seasonNumber: ep.seasonNumber,
            episodeNumber: ep.episodeNumber,
          })),
        },
        {
          id: 'season-2',
          displayName: 'Season 2',
          sortKey: 2,
          episodeCount: 3,
          episodes: FEED_EPISODES.slice(4, 7).map((ep) => ({
            id: ep.id,
            title: ep.title,
            publishedAt: ep.publishedAt,
            seasonNumber: ep.seasonNumber,
            episodeNumber: ep.episodeNumber,
          })),
        },
      ],
      claimedByOthers: [],
    },
  ],
  ungrouped: FEED_EPISODES.slice(7).map((ep) => ({
    id: ep.id,
    title: ep.title,
    publishedAt: ep.publishedAt,
    seasonNumber: ep.seasonNumber,
    episodeNumber: ep.episodeNumber,
  })),
  excluded: [],
};
