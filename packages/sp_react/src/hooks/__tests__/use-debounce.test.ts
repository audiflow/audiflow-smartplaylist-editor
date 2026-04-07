import { describe, it, expect, vi } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useDebounce } from '../use-debounce.ts';

describe('useDebounce', () => {
  it('returns the initial value immediately', () => {
    const { result } = renderHook(() => useDebounce('hello', 300));
    expect(result.current).toBe('hello');
  });

  it('does not update before the delay', () => {
    vi.useFakeTimers();
    const { result, rerender } = renderHook(
      ({ value, delay }) => useDebounce(value, delay),
      { initialProps: { value: 'a', delay: 300 } },
    );

    rerender({ value: 'b', delay: 300 });
    act(() => vi.advanceTimersByTime(200));
    expect(result.current).toBe('a');

    vi.useRealTimers();
  });

  it('updates after the delay', () => {
    vi.useFakeTimers();
    const { result, rerender } = renderHook(
      ({ value, delay }) => useDebounce(value, delay),
      { initialProps: { value: 'a', delay: 300 } },
    );

    rerender({ value: 'b', delay: 300 });
    act(() => vi.advanceTimersByTime(300));
    expect(result.current).toBe('b');

    vi.useRealTimers();
  });

  it('resets the timer on rapid changes', () => {
    vi.useFakeTimers();
    const { result, rerender } = renderHook(
      ({ value, delay }) => useDebounce(value, delay),
      { initialProps: { value: 'a', delay: 300 } },
    );

    rerender({ value: 'b', delay: 300 });
    act(() => vi.advanceTimersByTime(100));
    rerender({ value: 'c', delay: 300 });
    act(() => vi.advanceTimersByTime(300));

    expect(result.current).toBe('c');

    vi.useRealTimers();
  });
});
