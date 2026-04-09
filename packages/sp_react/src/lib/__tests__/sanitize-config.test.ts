import { describe, it, expect } from 'vitest';
import { sanitizeConfig, stripConditionalFields } from '../sanitize-config';
import type { PatternConfig } from '@/schemas/config-schema';

describe('sanitizeConfig', () => {
  it('removes keys with empty string values', () => {
    const config = {
      id: 'test',
      displayName: 'Test',
      resolverType: 'year',
      presentation: 'combined',
      episodeFilters: {
        require: [{ title: '' }],
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.id).toBe('test');
    expect(result.displayName).toBe('Test');
    expect(result.resolverType).toBe('year');
    expect(result.presentation).toBe('combined');
    expect(result).not.toHaveProperty('episodeFilters');
  });

  it('strips empty arrays', () => {
    const config = {
      id: 'test',
      episodeFilters: {
        require: [],
        exclude: [],
      },
      episodeList: {
        sort: null,
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.id).toBe('test');
    expect(result).not.toHaveProperty('episodeFilters');
    expect(result).not.toHaveProperty('episodeList');
  });

  it('removes keys with null values', () => {
    const config = {
      id: 'test',
      groupList: null,
      episodeList: null,
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.id).toBe('test');
    expect(result).not.toHaveProperty('groupList');
    expect(result).not.toHaveProperty('episodeList');
  });

  it('preserves non-empty strings', () => {
    const config = {
      id: 'test',
      presentation: 'combined',
      episodeFilters: {
        require: [{ title: '^\\d+' }],
        exclude: [{ title: 'bonus' }],
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.presentation).toBe('combined');
    expect(result.episodeFilters).toBeDefined();
  });

  it('handles nested playlists array', () => {
    const config = {
      id: 'pattern-1',
      playlists: [
        {
          id: 'pl-1',
          displayName: 'Main',
          resolverType: 'year',
          presentation: 'combined',
        },
        {
          id: 'pl-2',
          displayName: 'Bonus',
          resolverType: 'year',
          presentation: 'separate',
        },
      ],
    };

    const result = sanitizeConfig(config) as {
      playlists: Record<string, unknown>[];
    };

    expect(result.playlists).toHaveLength(2);
    expect(result.playlists[0].presentation).toBe('combined');
    expect(result.playlists[1].presentation).toBe('separate');
  });

  it('strips nested objects with only empty values', () => {
    const config = {
      id: 'pl-1',
      groupList: {
        sort: null,
        yearBinding: '',
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    // groupList becomes empty after stripping all values, so the key is removed entirely
    expect(result.groupList).toBeUndefined();
    expect('groupList' in result).toBe(false);
  });

  it('preserves groupList with non-empty sort', () => {
    const config = {
      id: 'pl-1',
      groupList: {
        sort: { field: 'playlistNumber', order: 'ascending' },
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.groupList).toEqual({
      sort: { field: 'playlistNumber', order: 'ascending' },
    });
  });

  it('passes through non-string primitives unchanged', () => {
    const config = {
      priority: 0,
      prependSeasonNumber: false,
      groupList: {
        showDateRange: true,
        userSortable: false,
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.priority).toBe(0);
    expect(result.prependSeasonNumber).toBe(false);
    const groupList = result.groupList as Record<string, unknown>;
    expect(groupList.showDateRange).toBe(true);
    expect(groupList.userSortable).toBe(false);
  });
});

function makeConfig(
  overrides: Partial<PatternConfig['playlists'][number]>,
): PatternConfig {
  return {
    id: 'test-pattern',
    displayName: 'Test',
    yearGroupedEpisodes: false,
    playlists: [
      {
        id: 'pl-1',
        displayName: 'Main',
        resolverType: 'seasonNumber',
        presentation: 'combined',
        priority: 0,
        prependSeasonNumber: false,
        groups: [],
        ...overrides,
      },
    ],
  };
}

describe('stripConditionalFields', () => {
  it('keeps numberingExtractor and titleExtractor for seasonNumber', () => {
    const config = makeConfig({
      resolverType: 'seasonNumber',
      numberingExtractor: { source: 'title', pattern: '(\\d+)', seasonGroup: 0, episodeGroup: 1 },
      titleExtractor: { source: 'title', pattern: '(.+)', group: 1 },
    });

    const result = stripConditionalFields(config);
    const pl = result.playlists[0];

    expect(pl.numberingExtractor).toBeDefined();
    expect(pl.titleExtractor).toBeDefined();
  });

  it('strips numberingExtractor and nullSeasonGroupKey for year resolver', () => {
    const config = makeConfig({
      resolverType: 'year',
      numberingExtractor: { source: 'title', pattern: '(\\d+)', seasonGroup: 0, episodeGroup: 1 },
      nullSeasonGroupKey: 0,
      titleExtractor: { source: 'title', pattern: '(.+)', group: 1 },
    });

    const result = stripConditionalFields(config);
    const pl = result.playlists[0];

    expect(pl.numberingExtractor).toBeUndefined();
    expect(pl.nullSeasonGroupKey).toBeUndefined();
    expect(pl.titleExtractor).toBeUndefined();
  });

  it('keeps titleExtractor and groups but strips numberingExtractor for titleDiscovery', () => {
    const config = makeConfig({
      resolverType: 'titleDiscovery',
      numberingExtractor: { source: 'title', pattern: '(\\d+)', seasonGroup: 0, episodeGroup: 1 },
      titleExtractor: { source: 'title', pattern: '(.+)', group: 1 },
      groups: [{ id: 'g1', displayName: 'Group 1', pattern: '.*' }],
    });

    const result = stripConditionalFields(config);
    const pl = result.playlists[0];

    expect(pl.numberingExtractor).toBeUndefined();
    expect(pl.titleExtractor).toBeDefined();
    expect(pl.groups).toHaveLength(1);
  });

  it('keeps groups only for titleClassifier', () => {
    const config = makeConfig({
      resolverType: 'titleClassifier',
      groups: [{ id: 'g1', displayName: 'Group 1', pattern: '.*' }],
    });

    const result = stripConditionalFields(config);

    expect(result.playlists[0].groups).toHaveLength(1);
  });

  it('strips groups for non-titleClassifier resolvers', () => {
    const config = makeConfig({
      resolverType: 'seasonNumber',
      groups: [{ id: 'g1', displayName: 'Group 1', pattern: '.*' }],
    });

    const result = stripConditionalFields(config);

    expect(result.playlists[0].groups).toBeUndefined();
  });

  it('does not mutate the original config', () => {
    const config = makeConfig({
      resolverType: 'year',
      numberingExtractor: { source: 'title', pattern: '(\\d+)', seasonGroup: 0, episodeGroup: 1 },
      groups: [{ id: 'g1', displayName: 'Group 1', pattern: '.*' }],
    });

    stripConditionalFields(config);

    expect(config.playlists[0].numberingExtractor).toBeDefined();
    expect(config.playlists[0].groups).toHaveLength(1);
  });
});
