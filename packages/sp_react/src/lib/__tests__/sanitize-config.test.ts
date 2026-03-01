import { describe, it, expect } from 'vitest';
import { sanitizeConfig } from '../sanitize-config';

describe('sanitizeConfig', () => {
  it('removes keys with empty string values', () => {
    const config = {
      id: 'test',
      displayName: 'Test',
      resolverType: 'year',
      titleFilter: '',
      excludeFilter: '',
      requireFilter: '',
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.id).toBe('test');
    expect(result.displayName).toBe('Test');
    expect(result.resolverType).toBe('year');
    expect(result).not.toHaveProperty('titleFilter');
    expect(result).not.toHaveProperty('excludeFilter');
    expect(result).not.toHaveProperty('requireFilter');
  });

  it('removes keys with null values', () => {
    const config = {
      id: 'test',
      titleFilter: null,
      customSort: null,
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.id).toBe('test');
    expect(result).not.toHaveProperty('titleFilter');
    expect(result).not.toHaveProperty('customSort');
  });

  it('preserves non-empty strings', () => {
    const config = {
      id: 'test',
      titleFilter: '^\\d+',
      excludeFilter: 'bonus',
      requireFilter: 'main',
      contentType: 'groups',
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.titleFilter).toBe('^\\d+');
    expect(result.excludeFilter).toBe('bonus');
    expect(result.requireFilter).toBe('main');
    expect(result.contentType).toBe('groups');
  });

  it('handles nested playlists array', () => {
    const config = {
      id: 'pattern-1',
      playlists: [
        {
          id: 'pl-1',
          displayName: 'Main',
          resolverType: 'year',
          titleFilter: '',
          excludeFilter: 'bonus',
        },
        {
          id: 'pl-2',
          displayName: 'Bonus',
          resolverType: 'year',
          requireFilter: '',
        },
      ],
    };

    const result = sanitizeConfig(config) as {
      playlists: Record<string, unknown>[];
    };

    expect(result.playlists).toHaveLength(2);
    expect(result.playlists[0]).not.toHaveProperty('titleFilter');
    expect(result.playlists[0].excludeFilter).toBe('bonus');
    expect(result.playlists[1]).not.toHaveProperty('requireFilter');
  });

  it('strips customSort with empty rules array', () => {
    const config = {
      id: 'pl-1',
      displayName: 'Main',
      resolverType: 'year',
      customSort: { rules: [] },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result).not.toHaveProperty('customSort');
  });

  it('preserves customSort with non-empty rules', () => {
    const config = {
      id: 'pl-1',
      customSort: { rules: [{ field: 'playlistNumber', order: 'ascending' }] },
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.customSort).toEqual({
      rules: [{ field: 'playlistNumber', order: 'ascending' }],
    });
  });

  it('strips customSort inside nested playlists', () => {
    const config = {
      id: 'pattern-1',
      playlists: [
        { id: 'pl-1', customSort: { rules: [] } },
        { id: 'pl-2', customSort: { rules: [{ field: 'progress', order: 'descending' }] } },
      ],
    };

    const result = sanitizeConfig(config) as {
      playlists: Record<string, unknown>[];
    };

    expect(result.playlists[0]).not.toHaveProperty('customSort');
    expect(result.playlists[1].customSort).toEqual({
      rules: [{ field: 'progress', order: 'descending' }],
    });
  });

  it('passes through non-string primitives unchanged', () => {
    const config = {
      priority: 0,
      episodeYearHeaders: false,
      showDateRange: true,
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.priority).toBe(0);
    expect(result.episodeYearHeaders).toBe(false);
    expect(result.showDateRange).toBe(true);
  });
});
