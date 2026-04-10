import { describe, it, expect } from 'vitest';
import { filterEpisodes } from '../episode-filter.ts';
import type { FeedEpisode } from '@/schemas/api-schema.ts';

function episode(id: number, title: string, description?: string): FeedEpisode {
  return { id, title, description: description ?? null, guid: null, publishedAt: null, seasonNumber: null, episodeNumber: null, imageUrl: null };
}

describe('filterEpisodes', () => {
  const episodes: FeedEpisode[] = [
    episode(1, 'Season 1 Episode 1', 'A great start'),
    episode(2, 'Season 1 Episode 2', 'Continues'),
    episode(3, 'Bonus: Behind the scenes', 'Extra content'),
    episode(4, 'Season 2 Episode 1', 'New season'),
    episode(5, 'Preview: Coming soon', 'Teaser'),
  ];

  it('returns all episodes when no filters are set', () => {
    const result = filterEpisodes(episodes, {});
    expect(result).toHaveLength(5);
  });

  it('returns all episodes when filters are undefined', () => {
    const result = filterEpisodes(episodes, undefined);
    expect(result).toHaveLength(5);
  });

  it('applies require filter on title (AND across entries)', () => {
    const result = filterEpisodes(episodes, {
      require: [{ title: 'Season 1' }],
    });
    expect(result.map((e) => e.id)).toEqual([1, 2]);
  });

  it('applies exclude filter on title (OR across entries)', () => {
    const result = filterEpisodes(episodes, {
      exclude: [{ title: 'Bonus' }, { title: 'Preview' }],
    });
    expect(result.map((e) => e.id)).toEqual([1, 2, 4]);
  });

  it('applies require then exclude', () => {
    const result = filterEpisodes(episodes, {
      require: [{ title: 'Season' }],
      exclude: [{ title: 'Season 2' }],
    });
    expect(result.map((e) => e.id)).toEqual([1, 2]);
  });

  it('matches description field', () => {
    const result = filterEpisodes(episodes, {
      require: [{ description: 'Extra' }],
    });
    expect(result.map((e) => e.id)).toEqual([3]);
  });

  it('treats require entry with both title and description as AND', () => {
    const result = filterEpisodes(episodes, {
      require: [{ title: 'Season 1', description: 'great' }],
    });
    expect(result.map((e) => e.id)).toEqual([1]);
  });

  it('treats invalid regex as no-op (matches server behavior)', () => {
    const result = filterEpisodes(episodes, {
      require: [{ title: '[invalid' }],
    });
    // Invalid regex compiles to null; entry matches everything (server parity)
    expect(result).toHaveLength(5);
  });

  it('applies require entries with AND semantics across multiple entries', () => {
    const result = filterEpisodes(episodes, {
      require: [{ title: 'Season' }, { title: 'Episode 1' }],
    });
    // Must match BOTH: "Season" AND "Episode 1"
    expect(result.map((e) => e.id)).toEqual([1, 4]);
  });

  it('does not exclude all episodes when exclude entry has only invalid regex', () => {
    const result = filterEpisodes(episodes, {
      exclude: [{ title: '[invalid' }],
    });
    // Invalid regex compiles to null; all-null entry is dropped to prevent
    // accidental "exclude-all" behavior during editing.
    expect(result).toHaveLength(5);
  });

  it('applies exclude entry with mixed valid and invalid regex fields', () => {
    const result = filterEpisodes(episodes, {
      exclude: [{ title: '[invalid', description: 'Extra' }],
    });
    // title compiles to null (invalid), description compiles to /Extra/i.
    // Entry has at least one valid field, so it is kept. Episode 3 ("Extra
    // content") matches the description regex and gets excluded.
    expect(result.map((e) => e.id)).toEqual([1, 2, 4, 5]);
  });

  it('does not exclude when all exclude entries have only invalid regexes', () => {
    const result = filterEpisodes(episodes, {
      exclude: [{ title: '[bad' }, { description: '(unclosed' }],
    });
    // Both entries compile to all-null and are dropped.
    expect(result).toHaveLength(5);
  });
});
