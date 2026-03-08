import { describe, it, expect } from 'vitest';
import { sanitizeConfig } from '../sanitize-config';

describe('sanitizeConfig', () => {
  it('removes keys with empty string values', () => {
    const config = {
      id: 'test',
      displayName: 'Test',
      resolverType: 'year',
      playlistStructure: 'grouped',
      episodeFilters: {
        require: [{ title: '' }],
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.id).toBe('test');
    expect(result.displayName).toBe('Test');
    expect(result.resolverType).toBe('year');
    expect(result.playlistStructure).toBe('grouped');
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
      playlistStructure: 'grouped',
      episodeFilters: {
        require: [{ title: '^\\d+' }],
        exclude: [{ title: 'bonus' }],
      },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.playlistStructure).toBe('grouped');
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
          playlistStructure: 'grouped',
        },
        {
          id: 'pl-2',
          displayName: 'Bonus',
          resolverType: 'year',
          playlistStructure: 'split',
        },
      ],
    };

    const result = sanitizeConfig(config) as {
      playlists: Record<string, unknown>[];
    };

    expect(result.playlists).toHaveLength(2);
    expect(result.playlists[0].playlistStructure).toBe('grouped');
    expect(result.playlists[1].playlistStructure).toBe('split');
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
