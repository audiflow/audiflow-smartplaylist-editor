import { describe, it, expect } from 'vitest';
import { sanitizeConfig, stripConditionalFields } from '../sanitize-config.ts';
import type { PatternConfig } from '@/schemas/config-schema.ts';

describe('sanitizeConfig', () => {
  it('removes keys with empty string values', () => {
    const config = {
      id: 'test',
      displayName: 'Test',
      grouping: { by: 'year' },
      episodeFilters: {
        require: [{ title: '' }],
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.id).toBe('test');
    expect(result.displayName).toBe('Test');
    expect(result).not.toHaveProperty('episodeFilters');
  });

  it('strips empty arrays', () => {
    const config = {
      id: 'test',
      episodeFilters: {
        require: [],
        exclude: [],
      },
      episodeListing: {
        sort: null,
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.id).toBe('test');
    expect(result).not.toHaveProperty('episodeFilters');
    expect(result).not.toHaveProperty('episodeListing');
  });

  it('removes keys with null values', () => {
    const config = {
      id: 'test',
      groupListing: null,
      episodeListing: null,
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.id).toBe('test');
    expect(result).not.toHaveProperty('groupListing');
    expect(result).not.toHaveProperty('episodeListing');
  });

  it('preserves non-empty strings', () => {
    const config = {
      id: 'test',
      grouping: { by: 'year' },
      episodeFilters: {
        require: [{ title: '^\\d+' }],
        exclude: [{ title: 'bonus' }],
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.episodeFilters).toBeDefined();
  });

  it('handles nested playlists array', () => {
    const config = {
      id: 'pattern-1',
      playlists: [
        {
          id: 'pl-1',
          displayName: 'Main',
          grouping: { by: 'year' },
        },
        {
          id: 'pl-2',
          displayName: 'Bonus',
          grouping: { by: 'titleClassifier' },
        },
      ],
    };

    const result = sanitizeConfig(config) as {
      playlists: Record<string, unknown>[];
    };

    expect(result.playlists).toHaveLength(2);
  });

  it('strips nested objects with only empty values', () => {
    const config = {
      id: 'pl-1',
      groupListing: {
        sort: null,
        yearBinding: '',
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.groupListing).toBeUndefined();
    expect('groupListing' in result).toBe(false);
  });

  it('preserves groupListing with non-empty sort', () => {
    const config = {
      id: 'pl-1',
      groupListing: {
        sort: { field: 'playlistNumber', order: 'ascending' },
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.groupListing).toEqual({
      sort: { field: 'playlistNumber', order: 'ascending' },
    });
  });

  it('passes through non-string primitives unchanged', () => {
    const config = {
      priority: 0,
      groupItem: {
        showDateRange: true,
        prependSeasonNumber: false,
      },
      groupListing: {
        userSortable: false,
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.priority).toBe(0);
    const groupItem = result.groupItem as Record<string, unknown>;
    expect(groupItem.showDateRange).toBe(true);
    expect(groupItem.prependSeasonNumber).toBe(false);
    const groupListing = result.groupListing as Record<string, unknown>;
    expect(groupListing.userSortable).toBe(false);
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
        grouping: { by: 'seasonNumber' },
        priority: 0,
        ...overrides,
      },
    ],
  };
}

describe('stripConditionalFields', () => {
  it('keeps numberingExtractor and groupItem.titleExtractor for seasonNumber', () => {
    const config = makeConfig({
      grouping: {
        by: 'seasonNumber',
        numberingExtractor: { source: 'title', pattern: '(\\d+)', seasonGroup: 0, episodeGroup: 1 },
      },
      groupItem: {
        titleExtractor: { source: 'title', pattern: '(.+)', template: '${1}' },
      },
    });

    const result = stripConditionalFields(config);
    const pl = result.playlists[0];

    expect(pl.grouping.numberingExtractor).toBeDefined();
    expect(pl.groupItem?.titleExtractor).toBeDefined();
  });

  it('strips numberingExtractor but keeps groupItem.titleExtractor for year resolver', () => {
    const config = makeConfig({
      grouping: {
        by: 'year',
        numberingExtractor: { source: 'title', pattern: '(\\d+)', seasonGroup: 0, episodeGroup: 1 },
      },
      groupItem: {
        titleExtractor: { source: 'title', pattern: '(.+)', template: '${1}' },
      },
    });

    const result = stripConditionalFields(config);
    const pl = result.playlists[0];

    expect(pl.grouping.numberingExtractor).toBeUndefined();
    expect(pl.groupItem?.titleExtractor).toBeDefined();
  });

  it('keeps titleExtractor and staticClassifiers but strips numberingExtractor for titleDiscovery', () => {
    const config = makeConfig({
      grouping: {
        by: 'titleDiscovery',
        numberingExtractor: { source: 'title', pattern: '(\\d+)', seasonGroup: 0, episodeGroup: 1 },
        staticClassifiers: [{ id: 'g1', displayName: 'Group 1', pattern: { source: 'title', pattern: '.*' } }],
      },
      groupItem: {
        titleExtractor: { source: 'title', pattern: '(.+)', template: '${1}' },
      },
    });

    const result = stripConditionalFields(config);
    const pl = result.playlists[0];

    expect(pl.grouping.numberingExtractor).toBeUndefined();
    expect(pl.groupItem?.titleExtractor).toBeDefined();
    expect(pl.grouping.staticClassifiers).toHaveLength(1);
  });

  it('keeps staticClassifiers only for titleClassifier', () => {
    const config = makeConfig({
      grouping: {
        by: 'titleClassifier',
        staticClassifiers: [{ id: 'g1', displayName: 'Group 1', pattern: { source: 'title', pattern: '.*' } }],
      },
    });

    const result = stripConditionalFields(config);

    expect(result.playlists[0].grouping.staticClassifiers).toHaveLength(1);
  });

  it('strips staticClassifiers for non-titleClassifier resolvers', () => {
    const config = makeConfig({
      grouping: {
        by: 'seasonNumber',
        staticClassifiers: [{ id: 'g1', displayName: 'Group 1', pattern: { source: 'title', pattern: '.*' } }],
      },
    });

    const result = stripConditionalFields(config);

    expect(result.playlists[0].grouping.staticClassifiers).toBeUndefined();
  });

  it('strips groupItem.prependSeasonNumber for non-seasonNumber resolvers', () => {
    const config = makeConfig({
      grouping: { by: 'titleClassifier' },
      groupItem: { prependSeasonNumber: true, showDateRange: false },
    });

    const result = stripConditionalFields(config);

    expect(result.playlists[0].groupItem?.prependSeasonNumber).toBeUndefined();
    // Unrelated groupItem fields survive.
    expect(result.playlists[0].groupItem?.showDateRange).toBe(false);
  });

  it('keeps groupItem.prependSeasonNumber for seasonNumber resolvers', () => {
    const config = makeConfig({
      grouping: { by: 'seasonNumber' },
      groupItem: { prependSeasonNumber: true },
    });

    const result = stripConditionalFields(config);

    expect(result.playlists[0].groupItem?.prependSeasonNumber).toBe(true);
  });

  it('drops matcher objects that are missing the pattern string', () => {
    const config = makeConfig({
      grouping: {
        by: 'titleClassifier',
        staticClassifiers: [
          // Half-built matcher: user picked a source but has not typed a regex yet.
          { id: 'g1', displayName: 'Group 1', pattern: { source: 'description', pattern: '' } },
          // Fully valid matcher.
          { id: 'g2', displayName: 'Group 2', pattern: { source: 'title', pattern: 'foo' } },
        ],
      },
    });

    const result = stripConditionalFields(config);
    const classifiers = result.playlists[0].grouping.staticClassifiers!;
    expect(classifiers).toHaveLength(2);
    // Half-built matcher becomes a catch-all (pattern key removed).
    expect(classifiers[0].pattern).toBeUndefined();
    // Valid matcher is preserved as-is.
    expect(classifiers[1].pattern).toEqual({ source: 'title', pattern: 'foo' });
  });

  it('does not mutate the original config', () => {
    const config = makeConfig({
      grouping: {
        by: 'year',
        numberingExtractor: { source: 'title', pattern: '(\\d+)', seasonGroup: 0, episodeGroup: 1 },
        staticClassifiers: [{ id: 'g1', displayName: 'Group 1', pattern: { source: 'title', pattern: '.*' } }],
      },
    });

    stripConditionalFields(config);

    expect(config.playlists[0].grouping.numberingExtractor).toBeDefined();
    expect(config.playlists[0].grouping.staticClassifiers).toHaveLength(1);
  });
});
