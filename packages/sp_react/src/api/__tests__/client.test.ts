import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ApiClient } from '../client';

function mockFetch(responses: Array<{ status: number; body?: unknown }>) {
  let callIndex = 0;
  const fn: typeof globalThis.fetch = async () => {
    const resp = responses[callIndex++] ?? { status: 500 };
    return {
      status: resp.status,
      ok: 200 <= resp.status && resp.status < 300,
      json: async () => resp.body,
      text: async () => JSON.stringify(resp.body),
    } as Response;
  };
  return vi.fn(fn);
}

describe('ApiClient', () => {
  let client: ApiClient;

  beforeEach(() => {
    client = new ApiClient('http://localhost:8080');
  });

  it('sends GET with auth header', async () => {
    const fetchMock = mockFetch([{ status: 200, body: { ok: true } }]);
    globalThis.fetch = fetchMock;

    client.setToken('test-token');
    const result = await client.get<{ ok: boolean }>('/api/health');

    expect(result).toEqual({ ok: true });
    const call = fetchMock.mock.calls[0]!;
    const url = call[0];
    const opts = call[1]!;
    expect(url).toBe('http://localhost:8080/api/health');
    expect((opts.headers as Record<string, string>)['Authorization']).toBe('Bearer test-token');
  });

  it('sends POST with JSON body', async () => {
    const fetchMock = mockFetch([{ status: 200, body: { created: true } }]);
    globalThis.fetch = fetchMock;

    client.setToken('t');
    const result = await client.post<{ created: boolean }>('/api/data', { name: 'test' });

    expect(result).toEqual({ created: true });
    const call = fetchMock.mock.calls[0]!;
    const opts = call[1]!;
    expect(opts.method).toBe('POST');
    expect(JSON.parse(opts.body as string)).toEqual({ name: 'test' });
  });

  it('retries on 401 after successful refresh', async () => {
    const fetchMock = mockFetch([
      { status: 401 },
      { status: 200, body: { accessToken: 'new-t', refreshToken: 'new-rt' } },
      { status: 200, body: { data: 'success' } },
    ]);
    globalThis.fetch = fetchMock;

    client.setToken('old-t');
    client.setRefreshToken('old-rt');
    const result = await client.get<{ data: string }>('/api/test');

    expect(result).toEqual({ data: 'success' });
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });

  it('calls onUnauthorized when refresh fails', async () => {
    const fetchMock = mockFetch([
      { status: 401 },
      { status: 401 },
    ]);
    globalThis.fetch = fetchMock;

    const onUnauthorized = vi.fn();
    client.onUnauthorized = onUnauthorized;
    client.setToken('t');
    client.setRefreshToken('rt');

    await expect(client.get('/api/test')).rejects.toThrow();
    expect(onUnauthorized).toHaveBeenCalled();
  });

  it('deduplicates concurrent refresh attempts', async () => {
    let refreshCallCount = 0;
    const impl: typeof globalThis.fetch = async (input) => {
      const url = String(input);
      if (url.includes('/api/auth/refresh')) {
        refreshCallCount++;
        return {
          status: 200,
          ok: true,
          json: async () => ({ accessToken: 'new-t', refreshToken: 'new-rt' }),
        } as Response;
      }
      if (refreshCallCount === 0) {
        return { status: 401, ok: false, json: async () => ({}) } as Response;
      }
      return { status: 200, ok: true, json: async () => ({ ok: true }) } as Response;
    };
    const fetchMock = vi.fn(impl);
    globalThis.fetch = fetchMock;

    client.setToken('t');
    client.setRefreshToken('rt');

    await Promise.all([
      client.get('/api/a'),
      client.get('/api/b'),
    ]);

    expect(refreshCallCount).toBe(1);
  });
});
