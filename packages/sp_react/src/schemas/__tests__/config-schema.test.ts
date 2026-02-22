import { describe, expect, it } from 'vitest';
import {
  playlistDefinitionSchema,
  patternConfigSchema,
  smartPlaylistSortSpecSchema,
  groupDefSchema,
  titleExtractorSchema,
  episodeExtractorSchema,
} from '../config-schema';

describe('playlistDefinitionSchema', () => {
  it('parses minimal valid definition with defaults', () => {
    const input = {
      id: 'main',
      displayName: 'Main Episodes',
      resolverType: 'rss',
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.id).toBe('main');
    expect(result.displayName).toBe('Main Episodes');
    expect(result.resolverType).toBe('rss');
    expect(result.priority).toBe(0);
    expect(result.episodeYearHeaders).toBe(false);
    expect(result.showDateRange).toBe(false);
  });

  it('parses full definition with all optional fields', () => {
    const input = {
      id: 'bonus',
      displayName: 'Bonus Content',
      resolverType: 'category',
      priority: 5,
      contentType: 'groups',
      yearHeaderMode: 'firstEpisode',
      episodeYearHeaders: true,
      showDateRange: true,
      titleFilter: 'Bonus.*',
      excludeFilter: 'Trailer',
      requireFilter: 'Episode',
      nullSeasonGroupKey: 0,
      groups: [
        { id: 'g1', displayName: 'Group 1', pattern: 'pattern1' },
      ],
      customSort: {
        type: 'simple',
        field: 'playlistNumber',
        order: 'ascending',
      },
      titleExtractor: {
        source: 'title',
        pattern: '\\[(.+?)\\]',
        group: 1,
      },
      smartPlaylistEpisodeExtractor: {
        source: 'title',
        pattern: '\\[(\\d+)-(\\d+)\\]',
        seasonGroup: 1,
        episodeGroup: 2,
        fallbackToRss: true,
      },
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.id).toBe('bonus');
    expect(result.priority).toBe(5);
    expect(result.contentType).toBe('groups');
    expect(result.yearHeaderMode).toBe('firstEpisode');
    expect(result.episodeYearHeaders).toBe(true);
    expect(result.showDateRange).toBe(true);
    expect(result.titleFilter).toBe('Bonus.*');
    expect(result.excludeFilter).toBe('Trailer');
    expect(result.requireFilter).toBe('Episode');
    expect(result.nullSeasonGroupKey).toBe(0);
    expect(result.groups).toHaveLength(1);
    expect(result.customSort).toEqual({
      type: 'simple',
      field: 'playlistNumber',
      order: 'ascending',
    });
    expect(result.titleExtractor).toEqual({
      source: 'title',
      pattern: '\\[(.+?)\\]',
      group: 1,
    });
    expect(result.smartPlaylistEpisodeExtractor).toEqual({
      source: 'title',
      pattern: '\\[(\\d+)-(\\d+)\\]',
      seasonGroup: 1,
      episodeGroup: 2,
      fallbackEpisodeCaptureGroup: 1,
      fallbackToRss: true,
    });
  });

  it('treats null priority as 0 (JSON round-trip from NaN)', () => {
    const input = {
      id: 'main',
      displayName: 'Main Episodes',
      resolverType: 'rss',
      priority: null,
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.priority).toBe(0);
  });

  it('rejects missing required fields', () => {
    expect(() => playlistDefinitionSchema.parse({})).toThrow();
    expect(() =>
      playlistDefinitionSchema.parse({ id: 'x' }),
    ).toThrow();
    expect(() =>
      playlistDefinitionSchema.parse({ id: 'x', displayName: 'Y' }),
    ).toThrow();
  });
});

describe('patternConfigSchema', () => {
  it('parses minimal config with defaults', () => {
    const input = {
      id: 'podcast-abc',
      playlists: [],
    };
    const result = patternConfigSchema.parse(input);
    expect(result.id).toBe('podcast-abc');
    expect(result.yearGroupedEpisodes).toBe(false);
    expect(result.playlists).toEqual([]);
  });

  it('parses config with playlists and feedUrls', () => {
    const input = {
      id: 'podcast-abc',
      podcastGuid: 'guid-123',
      feedUrls: ['https://example.com/feed.xml'],
      yearGroupedEpisodes: true,
      playlists: [
        {
          id: 'main',
          displayName: 'Main',
          resolverType: 'rss',
        },
      ],
    };
    const result = patternConfigSchema.parse(input);
    expect(result.podcastGuid).toBe('guid-123');
    expect(result.feedUrls).toEqual(['https://example.com/feed.xml']);
    expect(result.yearGroupedEpisodes).toBe(true);
    expect(result.playlists).toHaveLength(1);
    expect(result.playlists[0].id).toBe('main');
  });
});

describe('smartPlaylistSortSpecSchema', () => {
  it('parses simple sort', () => {
    const input = {
      type: 'simple',
      field: 'playlistNumber',
      order: 'ascending',
    };
    const result = smartPlaylistSortSpecSchema.parse(input)!;
    expect(result.type).toBe('simple');
    if (result.type === 'simple') {
      expect(result.field).toBe('playlistNumber');
      expect(result.order).toBe('ascending');
    }
  });

  it('parses composite sort with condition', () => {
    const input = {
      type: 'composite',
      rules: [
        {
          field: 'newestEpisodeDate',
          order: 'descending',
          condition: {
            type: 'sortKeyGreaterThan',
            value: 10,
          },
        },
        {
          field: 'playlistNumber',
          order: 'ascending',
        },
      ],
    };
    const result = smartPlaylistSortSpecSchema.parse(input)!;
    expect(result.type).toBe('composite');
    if (result.type === 'composite') {
      expect(result.rules).toHaveLength(2);
      expect(result.rules[0].condition).toEqual({
        type: 'sortKeyGreaterThan',
        value: 10,
      });
      expect(result.rules[1].condition).toBeUndefined();
    }
  });

  it('parses composite sort with greaterThan condition', () => {
    const input = {
      type: 'composite',
      rules: [
        {
          field: 'playlistNumber',
          order: 'ascending',
          condition: {
            type: 'greaterThan',
            value: 5,
          },
        },
        {
          field: 'newestEpisodeDate',
          order: 'descending',
        },
      ],
    };
    const result = smartPlaylistSortSpecSchema.parse(input)!;
    expect(result.type).toBe('composite');
    if (result.type === 'composite') {
      expect(result.rules[0].condition).toEqual({
        type: 'greaterThan',
        value: 5,
      });
    }
  });

  it('rejects unknown sort type', () => {
    expect(() =>
      smartPlaylistSortSpecSchema.parse({
        type: 'unknown',
        field: 'playlistNumber',
        order: 'ascending',
      }),
    ).toThrow();
  });
});

describe('groupDefSchema', () => {
  it('parses minimal group definition', () => {
    const result = groupDefSchema.parse({
      id: 'main',
      displayName: 'Main',
    });
    expect(result.id).toBe('main');
    expect(result.displayName).toBe('Main');
    expect(result.pattern).toBeUndefined();
    expect(result.episodeYearHeaders).toBeUndefined();
    expect(result.showDateRange).toBeUndefined();
  });

  it('parses full group definition', () => {
    const result = groupDefSchema.parse({
      id: 'bonus',
      displayName: 'Bonus',
      pattern: 'Bonus.*',
      episodeYearHeaders: true,
      showDateRange: false,
    });
    expect(result.pattern).toBe('Bonus.*');
    expect(result.episodeYearHeaders).toBe(true);
    expect(result.showDateRange).toBe(false);
  });
});

describe('titleExtractorSchema', () => {
  it('parses minimal title extractor with defaults', () => {
    const result = titleExtractorSchema.parse({ source: 'title' });
    expect(result.source).toBe('title');
    expect(result.group).toBe(0);
  });

  it('parses title extractor with fallback (recursive)', () => {
    const input = {
      source: 'title',
      pattern: '\\[(.+?)\\]',
      group: 1,
      fallback: {
        source: 'seasonNumber',
        template: 'Season {value}',
      },
    };
    const result = titleExtractorSchema.parse(input);
    expect(result.fallback).toBeDefined();
    expect(result.fallback?.source).toBe('seasonNumber');
    expect(result.fallback?.template).toBe('Season {value}');
  });
});

describe('episodeExtractorSchema', () => {
  it('parses with defaults', () => {
    const result = episodeExtractorSchema.parse({
      source: 'title',
      pattern: '\\[(\\d+)-(\\d+)\\]',
    });
    expect(result.episodeGroup).toBe(2);
    expect(result.fallbackEpisodeCaptureGroup).toBe(1);
    expect(result.fallbackToRss).toBe(false);
  });

  it('parses with null seasonGroup (episode-only mode)', () => {
    const result = episodeExtractorSchema.parse({
      source: 'title',
      pattern: 'E(\\d+)',
      seasonGroup: null,
      episodeGroup: 1,
    });
    expect(result.seasonGroup).toBeNull();
    expect(result.episodeGroup).toBe(1);
  });

  it('parses with fallbackToRss enabled', () => {
    const result = episodeExtractorSchema.parse({
      source: 'title',
      pattern: 'E(\\d+)',
      fallbackToRss: true,
    });
    expect(result.fallbackToRss).toBe(true);
  });

  it('parses full extractor with fallback', () => {
    const result = episodeExtractorSchema.parse({
      source: 'title',
      pattern: '\\[(\\d+)-(\\d+)\\]',
      seasonGroup: 1,
      episodeGroup: 2,
      fallbackSeasonNumber: 0,
      fallbackEpisodePattern: '\\[bangai-hen#(\\d+)\\]',
      fallbackEpisodeCaptureGroup: 1,
      fallbackToRss: true,
    });
    expect(result.fallbackSeasonNumber).toBe(0);
    expect(result.fallbackEpisodePattern).toBe('\\[bangai-hen#(\\d+)\\]');
    expect(result.fallbackToRss).toBe(true);
  });
});
