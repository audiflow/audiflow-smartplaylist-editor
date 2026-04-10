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
  groupListSettingsSchema,
  episodeListSettingsSchema,
} from '../config-schema';

describe('playlistDefinitionSchema', () => {
  it('parses minimal valid definition with defaults', () => {
    const input = {
      id: 'main',
      displayName: 'Main Episodes',
      resolverType: 'seasonNumber',
      presentation: 'combined',
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.id).toBe('main');
    expect(result.displayName).toBe('Main Episodes');
    expect(result.resolverType).toBe('seasonNumber');
    expect(result.presentation).toBe('combined');
    expect(result.priority).toBe(0);
    expect(result.prependSeasonNumber).toBe(false);
  });

  it('parses full definition with all optional fields', () => {
    const input = {
      id: 'bonus',
      displayName: 'Bonus Content',
      resolverType: 'titleClassifier',
      presentation: 'combined',
      priority: 5,
      prependSeasonNumber: true,
      episodeFilters: {
        require: [{ title: 'Episode' }],
        exclude: [{ title: 'Trailer' }],
      },
      groups: [
        { id: 'g1', displayName: 'Group 1', pattern: 'pattern1' },
      ],
      groupList: {
        yearBinding: 'pinToYear',
        userSortable: false,
        showDateRange: true,
        sort: { field: 'playlistNumber', order: 'ascending' },
      },
      episodeList: {
        showYearHeaders: true,
        sort: { field: 'publishedAt', order: 'descending' },
      },
      titleExtractor: {
        source: 'title',
        pattern: '\\[(.+?)\\]',
        group: 1,
      },
      numberingExtractor: {
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
    expect(result.presentation).toBe('combined');
    expect(result.prependSeasonNumber).toBe(true);
    expect(result.episodeFilters).toEqual({
      require: [{ title: 'Episode' }],
      exclude: [{ title: 'Trailer' }],
    });
    expect(result.groups).toHaveLength(1);
    expect(result.groupList).toEqual({
      yearBinding: 'pinToYear',
      userSortable: false,
      showDateRange: true,
      sort: { field: 'playlistNumber', order: 'ascending' },
    });
    expect(result.episodeList).toEqual({
      showYearHeaders: true,
      sort: { field: 'publishedAt', order: 'descending' },
    });
    expect(result.titleExtractor).toEqual({
      source: 'title',
      pattern: '\\[(.+?)\\]',
      group: 1,
    });
    expect(result.numberingExtractor).toEqual({
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
      resolverType: 'seasonNumber',
      presentation: 'separate',
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
          resolverType: 'seasonNumber',
          presentation: 'combined',
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

describe('groupListSettingsSchema', () => {
  it('parses with all fields', () => {
    const result = groupListSettingsSchema.parse({
      yearBinding: 'pinToYear',
      userSortable: false,
      showDateRange: true,
      sort: { field: 'newestEpisodeDate', order: 'descending' },
    });
    expect(result.yearBinding).toBe('pinToYear');
    expect(result.userSortable).toBe(false);
    expect(result.showDateRange).toBe(true);
    expect(result.sort?.field).toBe('newestEpisodeDate');
  });
});

describe('episodeListSettingsSchema', () => {
  it('parses with all fields', () => {
    const result = episodeListSettingsSchema.parse({
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
    expect(result.display).toBeUndefined();
    expect(result.episodeList).toBeUndefined();
    expect(result.numberingExtractor).toBeUndefined();
  });

  it('parses full group definition with nested objects', () => {
    const result = groupDefSchema.parse({
      id: 'bonus',
      displayName: 'Bonus',
      pattern: 'Bonus.*',
      display: {
        showDateRange: true,
        yearBinding: 'splitByYear',
      },
      episodeList: {
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
    expect(result.display?.showDateRange).toBe(true);
    expect(result.display?.yearBinding).toBe('splitByYear');
    expect(result.episodeList?.showYearHeaders).toBe(true);
    expect(result.episodeList?.sort?.field).toBe('publishedAt');
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

describe('resolverTypeSchema (legacy v3 migration)', () => {
  it('normalizes legacy "rss" to "seasonNumber"', () => {
    expect(resolverTypeSchema.parse('rss')).toBe('seasonNumber');
  });

  it('normalizes legacy "category" to "titleClassifier"', () => {
    expect(resolverTypeSchema.parse('category')).toBe('titleClassifier');
  });

  it('normalizes legacy "titleAppearanceOrder" to "titleDiscovery"', () => {
    expect(resolverTypeSchema.parse('titleAppearanceOrder')).toBe('titleDiscovery');
  });

  it('passes through v4 values unchanged', () => {
    expect(resolverTypeSchema.parse('seasonNumber')).toBe('seasonNumber');
    expect(resolverTypeSchema.parse('titleClassifier')).toBe('titleClassifier');
    expect(resolverTypeSchema.parse('titleDiscovery')).toBe('titleDiscovery');
    expect(resolverTypeSchema.parse('year')).toBe('year');
  });
});

describe('migrateLegacyKeys (playlistStructure -> presentation)', () => {
  it('migrates playlistStructure "grouped" to presentation "combined"', () => {
    const input = {
      id: 'test',
      displayName: 'Test',
      resolverType: 'seasonNumber',
      playlistStructure: 'grouped',
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.presentation).toBe('combined');
    expect((result as Record<string, unknown>)['playlistStructure']).toBeUndefined();
  });

  it('migrates playlistStructure "split" to presentation "separate"', () => {
    const input = {
      id: 'test',
      displayName: 'Test',
      resolverType: 'seasonNumber',
      playlistStructure: 'split',
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.presentation).toBe('separate');
  });

  it('preserves existing presentation (no double-migration)', () => {
    const input = {
      id: 'test',
      displayName: 'Test',
      resolverType: 'seasonNumber',
      presentation: 'combined',
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.presentation).toBe('combined');
  });

  it('normalizes legacy value "grouped" even when key is already "presentation"', () => {
    const input = {
      id: 'test',
      displayName: 'Test',
      resolverType: 'seasonNumber',
      presentation: 'grouped',
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.presentation).toBe('combined');
  });

  it('normalizes legacy value "split" even when key is already "presentation"', () => {
    const input = {
      id: 'test',
      displayName: 'Test',
      resolverType: 'seasonNumber',
      presentation: 'split',
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.presentation).toBe('separate');
  });
});

describe('migrateLegacyKeys (episodeExtractor -> numberingExtractor)', () => {
  it('migrates episodeExtractor at playlist level', () => {
    const input = {
      id: 'test',
      displayName: 'Test',
      resolverType: 'seasonNumber',
      presentation: 'separate',
      episodeExtractor: {
        source: 'title',
        pattern: '\\[(\\d+)-(\\d+)\\]',
      },
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.numberingExtractor).toBeDefined();
    expect(result.numberingExtractor?.source).toBe('title');
    expect((result as Record<string, unknown>)['episodeExtractor']).toBeUndefined();
  });

  it('migrates episodeExtractor at group level', () => {
    const input = {
      id: 'g1',
      displayName: 'Group 1',
      episodeExtractor: {
        source: 'title',
        pattern: 'E(\\d+)',
        episodeGroup: 1,
      },
    };
    const result = groupDefSchema.parse(input);
    expect(result.numberingExtractor).toBeDefined();
    expect(result.numberingExtractor?.source).toBe('title');
    expect((result as Record<string, unknown>)['episodeExtractor']).toBeUndefined();
  });

  it('preserves existing numberingExtractor (no double-migration)', () => {
    const input = {
      id: 'test',
      displayName: 'Test',
      resolverType: 'seasonNumber',
      presentation: 'separate',
      numberingExtractor: {
        source: 'title',
        pattern: 'S(\\d+)E(\\d+)',
      },
    };
    const result = playlistDefinitionSchema.parse(input);
    expect(result.numberingExtractor?.pattern).toBe('S(\\d+)E(\\d+)');
  });
});
