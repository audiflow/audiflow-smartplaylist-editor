import { http, HttpResponse } from 'msw';
import { TEST_BASE_URL } from '@/test-utils.tsx';
import {
  PRESET_SUMMARIES,
  PRESET_IDENTIFIERS,
  VALID_PRESET_CONFIG,
  FEED_EPISODES,
  PREVIEW_RESULT,
  PLAYLIST_SEASON,
} from './fixtures.ts';

const BASE = TEST_BASE_URL;

export const handlers = [
  // -- Pattern browsing --
  http.get(`${BASE}/api/configs/presets`, () =>
    HttpResponse.json(PRESET_SUMMARIES),
  ),

  http.get(`${BASE}/api/configs/presets/identifiers`, () =>
    HttpResponse.json(PRESET_IDENTIFIERS),
  ),

  // -- Pattern CRUD --
  http.get(`${BASE}/api/configs/presets/:id`, ({ params }) =>
    HttpResponse.json({
      dataVersion: 1,
      id: params.id,
      podcastGuid: VALID_PRESET_CONFIG.podcastGuid,
      feedUrls: VALID_PRESET_CONFIG.feedUrls,
      yearGroupedEpisodes: false,
      playlists: ['seasons', 'topics'],
    }),
  ),

  http.get(`${BASE}/api/configs/presets/:id/assembled`, () =>
    HttpResponse.json(VALID_PRESET_CONFIG),
  ),

  http.post(`${BASE}/api/configs/presets`, () =>
    HttpResponse.json(null, { status: 201 }),
  ),

  http.delete(`${BASE}/api/configs/presets/:id`, () =>
    HttpResponse.json(null),
  ),

  http.put(`${BASE}/api/configs/presets/:id/meta`, () =>
    HttpResponse.json(null),
  ),

  // -- Playlist CRUD --
  http.get(`${BASE}/api/configs/presets/:id/playlists/:pid`, () =>
    HttpResponse.json(PLAYLIST_SEASON),
  ),

  http.put(`${BASE}/api/configs/presets/:id/playlists/:pid`, () =>
    HttpResponse.json(null),
  ),

  http.delete(`${BASE}/api/configs/presets/:id/playlists/:pid`, () =>
    HttpResponse.json(null),
  ),

  // -- Feed --
  http.get(`${BASE}/api/feeds`, () =>
    HttpResponse.json({ episodes: FEED_EPISODES }),
  ),

  // -- Preview & validation --
  http.post(`${BASE}/api/configs/preview`, () =>
    HttpResponse.json(PREVIEW_RESULT),
  ),

  http.post(`${BASE}/api/configs/validate`, () =>
    HttpResponse.json({ valid: true }),
  ),

  // -- Podcast search --
  http.get(`${BASE}/api/podcasts/search`, ({ request }) => {
    const url = new URL(request.url);
    const term = url.searchParams.get('term');
    if (!term) {
      return HttpResponse.json({ error: 'Missing required query parameter: term' }, { status: 400 });
    }
    return HttpResponse.json({
      resultCount: 1,
      results: [
        {
          trackName: `Test Podcast for ${term}`,
          artistName: 'Test Author',
          artworkUrl100: 'https://example.com/art.jpg',
          feedUrl: 'https://example.com/feed.xml',
          trackCount: 100,
          primaryGenreName: 'Technology',
        },
      ],
    });
  }),
];
