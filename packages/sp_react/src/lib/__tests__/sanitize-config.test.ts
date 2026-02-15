import { describe, it, expect } from 'vitest';
import { sanitizeConfig } from '../sanitize-config';

describe('sanitizeConfig', () => {
  it('strips empty strings from filter fields', () => {
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

  it('passes through non-string primitives unchanged', () => {
    const config = {
      priority: 0,
      episodeYearHeaders: false,
      showDateRange: true,
      nullSeasonGroupKey: null,
    };

    const result = sanitizeConfig(config) as Record<string, unknown>;

    expect(result.priority).toBe(0);
    expect(result.episodeYearHeaders).toBe(false);
    expect(result.showDateRange).toBe(true);
    expect(result.nullSeasonGroupKey).toBeNull();
  });
});
