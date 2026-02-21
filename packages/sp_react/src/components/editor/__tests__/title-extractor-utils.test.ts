import { describe, it, expect } from 'vitest';
import { flattenChain, nestChain } from '../title-extractor-form.tsx';

describe('flattenChain / nestChain', () => {
  it('flattens a recursive chain into steps', () => {
    const chain = {
      source: 'title', pattern: '^(.+)', group: 1,
      fallback: { source: 'seasonNumber', group: 0, template: 'Season {value}' },
      fallbackValue: 'Unknown',
    };
    const steps = flattenChain(chain);
    expect(steps).toHaveLength(2);
    expect(steps[0].source).toBe('title');
    expect(steps[0].fallback).toBeUndefined();
    expect(steps[1].source).toBe('seasonNumber');
  });

  it('nests steps back into recursive structure', () => {
    const steps = [
      { source: 'title', pattern: '^(.+)', group: 1 },
      { source: 'seasonNumber', group: 0, template: 'Season {value}' },
    ];
    const nested = nestChain(steps, 'Unknown');
    expect(nested?.source).toBe('title');
    expect(nested?.fallbackValue).toBe('Unknown');
    expect(nested?.fallback?.source).toBe('seasonNumber');
    expect(nested?.fallback?.fallback).toBeNull();
  });

  it('returns null for empty steps', () => {
    expect(nestChain([])).toBeNull();
  });

  it('returns empty array for null extractor', () => {
    expect(flattenChain(null)).toEqual([]);
  });
});
