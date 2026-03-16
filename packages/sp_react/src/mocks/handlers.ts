import { http, HttpResponse } from 'msw';
import {
  PATTERN_SUMMARIES,
  PATTERN_IDENTIFIERS,
  VALID_PATTERN_CONFIG,
  FEED_EPISODES,
  PREVIEW_RESULT,
  PLAYLIST_SEASON,
} from './fixtures.ts';

const BASE = 'http://localhost:8080';

export const handlers = [
  // -- Pattern browsing --
  http.get(`${BASE}/api/configs/patterns`, () =>
    HttpResponse.json(PATTERN_SUMMARIES),
  ),

  http.get(`${BASE}/api/configs/patterns/identifiers`, () =>
    HttpResponse.json(PATTERN_IDENTIFIERS),
  ),

  // -- Pattern CRUD --
  http.get(`${BASE}/api/configs/patterns/:id`, ({ params }) =>
    HttpResponse.json({
      dataVersion: 1,
      id: params.id,
      podcastGuid: VALID_PATTERN_CONFIG.podcastGuid,
      feedUrls: VALID_PATTERN_CONFIG.feedUrls,
      yearGroupedEpisodes: false,
      playlists: ['seasons', 'topics'],
    }),
  ),

  http.get(`${BASE}/api/configs/patterns/:id/assembled`, () =>
    HttpResponse.json(VALID_PATTERN_CONFIG),
  ),

  http.post(`${BASE}/api/configs/patterns`, () =>
    HttpResponse.json(null, { status: 201 }),
  ),

  http.delete(`${BASE}/api/configs/patterns/:id`, () =>
    HttpResponse.json(null),
  ),

  http.put(`${BASE}/api/configs/patterns/:id/meta`, () =>
    HttpResponse.json(null),
  ),

  // -- Playlist CRUD --
  http.get(`${BASE}/api/configs/patterns/:id/playlists/:pid`, () =>
    HttpResponse.json(PLAYLIST_SEASON),
  ),

  http.put(`${BASE}/api/configs/patterns/:id/playlists/:pid`, () =>
    HttpResponse.json(null),
  ),

  http.delete(`${BASE}/api/configs/patterns/:id/playlists/:pid`, () =>
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
];
