import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook } from '@testing-library/react';
import type { QueryClient } from '@tanstack/react-query';
import { createTestQueryClient, createTestProviders, TEST_BASE_URL } from '@/test-utils.tsx';
import { useFileEvents } from '../use-file-events';

type MessageHandler = ((event: MessageEvent) => void) | null;
type ErrorHandler = (() => void) | null;

class MockEventSource {
  static instances: MockEventSource[] = [];
  url: string;
  onmessage: MessageHandler = null;
  onerror: ErrorHandler = null;
  close = vi.fn();

  constructor(url: string) {
    this.url = url;
    MockEventSource.instances.push(this);
  }

  simulateMessage(data: object): void {
    this.onmessage?.(
      new MessageEvent('message', { data: JSON.stringify(data) }),
    );
  }
}

describe('useFileEvents', () => {
  let queryClient: QueryClient;
  let wrapper: ReturnType<typeof createTestProviders>;

  beforeEach(() => {
    queryClient = createTestQueryClient();
    wrapper = createTestProviders(queryClient);
    vi.stubGlobal('EventSource', MockEventSource);
  });

  afterEach(() => {
    MockEventSource.instances = [];
    vi.unstubAllGlobals();
  });

  function latestSource(): MockEventSource {
    const instances = MockEventSource.instances;
    expect(0 < instances.length).toBe(true);
    return instances[instances.length - 1]!;
  }

  it('opens EventSource with the correct URL', () => {
    renderHook(() => useFileEvents(), { wrapper });

    const source = latestSource();
    expect(source.url).toBe(`${TEST_BASE_URL}/api/events`);
  });

  it('closes EventSource on unmount', () => {
    const { unmount } = renderHook(() => useFileEvents(), { wrapper });
    const source = latestSource();

    expect(source.close).not.toHaveBeenCalled();
    unmount();
    expect(source.close).toHaveBeenCalledOnce();
  });

  it('invalidates patterns query when patterns/meta.json changes', () => {
    const spy = vi.spyOn(queryClient, 'invalidateQueries');
    renderHook(() => useFileEvents(), { wrapper });

    latestSource().simulateMessage({
      type: 'modified',
      path: 'patterns/meta.json',
    });

    expect(spy).toHaveBeenCalledOnce();
    expect(spy).toHaveBeenCalledWith({ queryKey: ['patterns'] });
  });

  it('invalidates assembledConfig query when a pattern meta.json changes', () => {
    const spy = vi.spyOn(queryClient, 'invalidateQueries');
    renderHook(() => useFileEvents(), { wrapper });

    latestSource().simulateMessage({
      type: 'modified',
      path: 'patterns/my-podcast/meta.json',
    });

    expect(spy).toHaveBeenCalledOnce();
    expect(spy).toHaveBeenCalledWith({
      queryKey: ['assembledConfig', 'my-podcast'],
    });
  });

  it('invalidates assembledConfig query when a playlist file changes', () => {
    const spy = vi.spyOn(queryClient, 'invalidateQueries');
    renderHook(() => useFileEvents(), { wrapper });

    latestSource().simulateMessage({
      type: 'created',
      path: 'patterns/my-podcast/playlists/seasons.json',
    });

    expect(spy).toHaveBeenCalledOnce();
    expect(spy).toHaveBeenCalledWith({
      queryKey: ['assembledConfig', 'my-podcast'],
    });
  });

  it('does not invalidate any queries for an unrecognized path', () => {
    const spy = vi.spyOn(queryClient, 'invalidateQueries');
    renderHook(() => useFileEvents(), { wrapper });

    latestSource().simulateMessage({
      type: 'modified',
      path: 'some/random/file.txt',
    });

    expect(spy).not.toHaveBeenCalled();
  });

  it('handles multiple messages independently', () => {
    const spy = vi.spyOn(queryClient, 'invalidateQueries');
    renderHook(() => useFileEvents(), { wrapper });

    const source = latestSource();

    source.simulateMessage({
      type: 'modified',
      path: 'patterns/meta.json',
    });
    source.simulateMessage({
      type: 'modified',
      path: 'patterns/pod-a/playlists/list.json',
    });

    expect(spy).toHaveBeenCalledTimes(2);
    expect(spy).toHaveBeenCalledWith({ queryKey: ['patterns'] });
    expect(spy).toHaveBeenCalledWith({
      queryKey: ['assembledConfig', 'pod-a'],
    });
  });

  it('does not throw when onerror fires', () => {
    renderHook(() => useFileEvents(), { wrapper });

    const source = latestSource();
    expect(() => source.onerror?.()).not.toThrow();
  });
});
