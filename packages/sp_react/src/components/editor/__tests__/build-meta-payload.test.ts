import { describe, it, expect } from 'vitest';
import {
  buildMetaPayload,
  buildCreatePatternPayload,
  type MetaPayloadSnapshot,
} from '../editor-layout.tsx';

/**
 * Regression coverage for the tri-state `showEpisodeThumbnail` round-trip.
 *
 * The server treats JSON `null` as "remove key from disk", so the client must
 * translate an undefined snapshot value into an explicit `null` payload.
 * Without this, cycling the toggle back to "unset" cannot reach the on-disk
 * absence and the field is permanently stuck at the last explicit value.
 */
describe('buildMetaPayload', () => {
  const baseSnapshot: MetaPayloadSnapshot = {
    displayName: 'P1',
    feedUrls: ['https://example.com/rss'],
    yearGroupedEpisodes: false,
    playlists: [{ id: 'one' }],
  };

  it('sends showEpisodeThumbnail=true when snapshot is true', () => {
    const out = buildMetaPayload(
      { ...baseSnapshot, showEpisodeThumbnail: true },
      'p1',
    );
    expect(out.showEpisodeThumbnail).toBe(true);
  });

  it('sends showEpisodeThumbnail=false when snapshot is false', () => {
    const out = buildMetaPayload(
      { ...baseSnapshot, showEpisodeThumbnail: false },
      'p1',
    );
    expect(out.showEpisodeThumbnail).toBe(false);
  });

  it('sends null when snapshot is undefined to clear on-disk value', () => {
    const out = buildMetaPayload(
      { ...baseSnapshot, showEpisodeThumbnail: undefined },
      'p1',
    );
    expect(out.showEpisodeThumbnail).toBeNull();
  });

  it('forces id to the route-derived value', () => {
    const out = buildMetaPayload(baseSnapshot, 'route-id');
    expect(out.id).toBe('route-id');
  });

  it('flattens playlists to an ID array', () => {
    const out = buildMetaPayload(
      { ...baseSnapshot, playlists: [{ id: 'a' }, { id: 'b' }] },
      'p1',
    );
    expect(out.playlists).toEqual(['a', 'b']);
  });
});

describe('buildCreatePatternPayload', () => {
  const baseSnapshot: MetaPayloadSnapshot = {
    displayName: 'P1',
    feedUrls: ['https://example.com/rss'],
    yearGroupedEpisodes: false,
    playlists: [{ id: 'one' }],
  };

  it('nests the meta payload and propagates tri-state null', () => {
    const out = buildCreatePatternPayload(
      { ...baseSnapshot, showEpisodeThumbnail: undefined },
      'new-id',
    );
    expect(out.id).toBe('new-id');
    expect(out.meta.id).toBe('new-id');
    expect(out.meta.showEpisodeThumbnail).toBeNull();
  });

  it('propagates an explicit false through the meta payload', () => {
    const out = buildCreatePatternPayload(
      { ...baseSnapshot, showEpisodeThumbnail: false },
      'new-id',
    );
    expect(out.meta.showEpisodeThumbnail).toBe(false);
  });
});
