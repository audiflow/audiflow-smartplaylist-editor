import { describe, it, expect } from 'vitest';
import { merge } from '../json-merge';

describe('merge', () => {
  it('returns latest when no user changes', () => {
    const base = { a: 1, b: 2 };
    const latest = { a: 1, b: 3 };
    const modified = { a: 1, b: 2 };
    expect(merge({ base, latest, modified })).toEqual({ a: 1, b: 3 });
  });

  it('preserves user changes', () => {
    const base = { a: 1, b: 2 };
    const latest = { a: 1, b: 2 };
    const modified = { a: 1, b: 99 };
    expect(merge({ base, latest, modified })).toEqual({ a: 1, b: 99 });
  });

  it('user change wins over upstream change', () => {
    const base = { a: 1 };
    const latest = { a: 2 };
    const modified = { a: 3 };
    expect(merge({ base, latest, modified })).toEqual({ a: 3 });
  });

  it('user removal wins', () => {
    const base = { a: 1, b: 2 };
    const latest = { a: 1, b: 2 };
    const modified = { a: 1 };
    expect(merge({ base, latest, modified })).toEqual({ a: 1 });
  });

  it('upstream adds new key untouched by user', () => {
    const base = { a: 1 };
    const latest = { a: 1, b: 2 };
    const modified = { a: 1 };
    expect(merge({ base, latest, modified })).toEqual({ a: 1, b: 2 });
  });

  it('merges nested maps recursively', () => {
    const base = { nested: { a: 1, b: 2 } };
    const latest = { nested: { a: 1, b: 3 } };
    const modified = { nested: { a: 99, b: 2 } };
    expect(merge({ base, latest, modified })).toEqual({
      nested: { a: 99, b: 3 },
    });
  });

  it('merges id-based arrays', () => {
    const base = {
      items: [
        { id: 'a', v: 1 },
        { id: 'b', v: 2 },
      ],
    };
    const latest = {
      items: [
        { id: 'a', v: 1 },
        { id: 'b', v: 3 },
      ],
    };
    const modified = {
      items: [
        { id: 'a', v: 99 },
        { id: 'b', v: 2 },
      ],
    };
    const result = merge({ base, latest, modified });
    expect(result).toEqual({
      items: [
        { id: 'a', v: 99 },
        { id: 'b', v: 3 },
      ],
    });
  });

  it('merges index-based arrays', () => {
    const base = { tags: ['a', 'b'] };
    const latest = { tags: ['a', 'c'] };
    const modified = { tags: ['x', 'b'] };
    const result = merge({ base, latest, modified });
    expect(result).toEqual({ tags: ['x', 'c'] });
  });
});
