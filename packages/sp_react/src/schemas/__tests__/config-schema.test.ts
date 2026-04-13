import { describe, expect, it } from 'vitest';
import {
  playlistDefinitionSchema,
  patternConfigSchema,
  groupDefSchema,
  titleExtractorSchema,
  numberingExtractorSchema,
  resolverTypeSchema,
  sortRuleSchema,
  episodeSortRuleSchema,
  episodeFiltersSchema,
  groupListingConfigSchema,
  episodeListingConfigSchema,
} from '../config-schema';

describe('playlistDefinitionSchema', () => {
  it('parses minimal valid v5 definition with required priority', () => {
    const input = {
      id: 'main',
      displayName: 'Main Episodes',
      grouping: { by: 'seasonNumber' },
      priority: 0,
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.id).toBe('main');
    expect(result.displayName).toBe('Main Episodes');
    expect(result.grouping.by).toBe('seasonNumber');
    expect(result.priority).toBe(0);
  });

  it('parses full v5 definition with all optional fields', () => {
    const input = {
      id: 'bonus',
      displayName: 'Bonus Content',
      grouping: {
        by: 'titleClassifier',
        staticClassifiers: [
          { id: 'g1', displayName: 'Group 1', pattern: 'pattern1' },
        ],
      },
      priority: 5,
      episodeFilters: {
        require: [{ title: 'Episode' }],
        exclude: [{ title: 'Trailer' }],
      },
      groupListing: {
        yearBinding: 'pinToYear',
        userSortable: false,
        sort: { field: 'playlistNumber', order: 'ascending' },
      },
      episodeListing: {
        showYearHeaders: true,
        sort: { field: 'publishedAt', order: 'descending' },
      },
      groupItem: {
        showDateRange: true,
        prependSeasonNumber: true,
        titleExtractor: {
          source: 'title',
          pattern: '\\[(.+?)\\]',
          group: 1,
        },
      },
      episodeItem: {
        titleExtractor: {
          source: 'title',
          pattern: '#\\d+ (.+)',
          group: 1,
        },
      },
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.id).toBe('bonus');
    expect(result.priority).toBe(5);
    expect(result.grouping.by).toBe('titleClassifier');
    expect(result.grouping.staticClassifiers).toHaveLength(1);
    expect(result.episodeFilters).toEqual({
      require: [{ title: 'Episode' }],
      exclude: [{ title: 'Trailer' }],
    });
    expect(result.groupListing).toEqual({
      yearBinding: 'pinToYear',
      userSortable: false,
      sort: { field: 'playlistNumber', order: 'ascending' },
    });
    expect(result.episodeListing).toEqual({
      showYearHeaders: true,
      sort: { field: 'publishedAt', order: 'descending' },
    });
    expect(result.groupItem?.showDateRange).toBe(true);
    expect(result.groupItem?.prependSeasonNumber).toBe(true);
    expect(result.episodeItem?.titleExtractor?.pattern).toBe('#\\d+ (.+)');
  });

  it('rejects missing priority', () => {
    const input = {
      id: 'main',
      displayName: 'Main Episodes',
      grouping: { by: 'seasonNumber' },
    };
    expect(() => playlistDefinitionSchema.parse(input)).toThrow();
  });

  it('rejects missing required fields', () => {
    expect(() => playlistDefinitionSchema.parse({})).toThrow();
    expect(() =>
      playlistDefinitionSchema.parse({ id: 'x' }),
    ).toThrow();
  });

  it('rejects definition without grouping', () => {
    expect(() =>
      playlistDefinitionSchema.parse({ id: 'x', displayName: 'Y' }),
    ).toThrow();
  });

  it('parses v5 definition with numberingExtractor in grouping', () => {
    const input = {
      id: 'regular',
      displayName: 'Regular Series',
      priority: 0,
      grouping: {
        by: 'seasonNumber',
        numberingExtractor: {
          source: 'title',
          pattern: '\\[(\\d+)-(\\d+)\\]',
          seasonGroup: 1,
          episodeGroup: 2,
          fallbackToRss: true,
        },
      },
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.grouping.by).toBe('seasonNumber');
    expect(result.grouping.numberingExtractor?.seasonGroup).toBe(1);
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
          priority: 0,
          grouping: { by: 'seasonNumber' },
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

describe('sortRuleSchema', () => {
  it('parses valid sort rule', () => {
    const result = sortRuleSchema.parse({
      field: 'playlistNumber',
      order: 'ascending',
    });
    expect(result.field).toBe('playlistNumber');
    expect(result.order).toBe('ascending');
  });

  it('rejects invalid field', () => {
    expect(() =>
      sortRuleSchema.parse({ field: 'progress', order: 'ascending' }),
    ).toThrow();
  });
});

describe('episodeSortRuleSchema', () => {
  it('parses valid episode sort rule', () => {
    const result = episodeSortRuleSchema.parse({
      field: 'publishedAt',
      order: 'descending',
    });
    expect(result.field).toBe('publishedAt');
    expect(result.order).toBe('descending');
  });

  it('parses episodeNumber field', () => {
    const result = episodeSortRuleSchema.parse({
      field: 'episodeNumber',
      order: 'ascending',
    });
    expect(result.field).toBe('episodeNumber');
  });
});

describe('episodeFiltersSchema', () => {
  it('parses filters with require and exclude', () => {
    const result = episodeFiltersSchema.parse({
      require: [{ title: 'Episode' }],
      exclude: [{ description: 'ad' }],
    });
    expect(result.require).toHaveLength(1);
    expect(result.exclude).toHaveLength(1);
  });

  it('parses empty filters', () => {
    const result = episodeFiltersSchema.parse({});
    expect(result.require).toBeUndefined();
    expect(result.exclude).toBeUndefined();
  });
});

describe('groupListingConfigSchema', () => {
  it('parses with all fields', () => {
    const result = groupListingConfigSchema.parse({
      yearBinding: 'pinToYear',
      userSortable: false,
      sort: { field: 'newestEpisodeDate', order: 'descending' },
    });
    expect(result.yearBinding).toBe('pinToYear');
    expect(result.userSortable).toBe(false);
    expect(result.sort?.field).toBe('newestEpisodeDate');
  });
});

describe('episodeListingConfigSchema', () => {
  it('parses with all fields', () => {
    const result = episodeListingConfigSchema.parse({
      showYearHeaders: true,
      sort: { field: 'episodeNumber', order: 'ascending' },
    });
    expect(result.showYearHeaders).toBe(true);
    expect(result.sort?.field).toBe('episodeNumber');
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
    expect(result.groupListing).toBeUndefined();
    expect(result.groupItem).toBeUndefined();
    expect(result.episodeListing).toBeUndefined();
    expect(result.episodeItem).toBeUndefined();
    expect(result.numberingExtractor).toBeUndefined();
  });

  it('parses full group definition with nested objects', () => {
    const result = groupDefSchema.parse({
      id: 'bonus',
      displayName: 'Bonus',
      pattern: 'Bonus.*',
      groupListing: {
        yearBinding: 'splitByYear',
      },
      groupItem: {
        showDateRange: true,
      },
      episodeListing: {
        showYearHeaders: true,
        sort: { field: 'publishedAt', order: 'descending' },
      },
      numberingExtractor: {
        source: 'title',
        pattern: 'E(\\d+)',
        episodeGroup: 1,
      },
    });
    expect(result.pattern).toBe('Bonus.*');
    expect(result.groupItem?.showDateRange).toBe(true);
    expect(result.groupListing?.yearBinding).toBe('splitByYear');
    expect(result.episodeListing?.showYearHeaders).toBe(true);
    expect(result.episodeListing?.sort?.field).toBe('publishedAt');
    expect(result.numberingExtractor?.source).toBe('title');
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

describe('numberingExtractorSchema', () => {
  it('parses with defaults', () => {
    const result = numberingExtractorSchema.parse({
      source: 'title',
      pattern: '\\[(\\d+)-(\\d+)\\]',
    });
    expect(result.episodeGroup).toBe(2);
    expect(result.fallbackEpisodeCaptureGroup).toBe(1);
    expect(result.fallbackToRss).toBe(false);
  });

  it('parses with null seasonGroup (episode-only mode)', () => {
    const result = numberingExtractorSchema.parse({
      source: 'title',
      pattern: 'E(\\d+)',
      seasonGroup: null,
      episodeGroup: 1,
    });
    expect(result.seasonGroup).toBeNull();
    expect(result.episodeGroup).toBe(1);
  });

  it('parses with fallbackToRss enabled', () => {
    const result = numberingExtractorSchema.parse({
      source: 'title',
      pattern: 'E(\\d+)',
      fallbackToRss: true,
    });
    expect(result.fallbackToRss).toBe(true);
  });

  it('parses full extractor with fallback', () => {
    const result = numberingExtractorSchema.parse({
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

describe('resolverTypeSchema', () => {
  it('accepts v5 values', () => {
    expect(resolverTypeSchema.parse('seasonNumber')).toBe('seasonNumber');
    expect(resolverTypeSchema.parse('titleClassifier')).toBe('titleClassifier');
    expect(resolverTypeSchema.parse('titleDiscovery')).toBe('titleDiscovery');
    expect(resolverTypeSchema.parse('year')).toBe('year');
  });

  // The published JSON schema and the Rust resolver still accept the v3
  // aliases; the React parser must accept them too so legacy configs keep
  // loading until they are migrated.
  it('accepts deprecated v3 aliases', () => {
    expect(resolverTypeSchema.parse('rss')).toBe('rss');
    expect(resolverTypeSchema.parse('category')).toBe('category');
    expect(resolverTypeSchema.parse('titleAppearanceOrder')).toBe('titleAppearanceOrder');
  });

  it('rejects invalid values', () => {
    expect(() => resolverTypeSchema.parse('invalid')).toThrow();
  });
});
