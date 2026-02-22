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

  it('sends GET and parses JSON response', async () => {
    const fetchMock = mockFetch([{ status: 200, body: { ok: true } }]);
    globalThis.fetch = fetchMock;

    const result = await client.get<{ ok: boolean }>('/api/health');

    expect(result).toEqual({ ok: true });
    const call = fetchMock.mock.calls[0]!;
    const url = call[0];
    const opts = call[1]!;
    expect(url).toBe('http://localhost:8080/api/health');
    expect(opts.method).toBe('GET');
    expect((opts.headers as Record<string, string>)['Content-Type']).toBe('application/json');
  });

  it('sends POST with JSON body', async () => {
    const fetchMock = mockFetch([{ status: 200, body: { created: true } }]);
    globalThis.fetch = fetchMock;

    const result = await client.post<{ created: boolean }>('/api/data', { name: 'test' });

    expect(result).toEqual({ created: true });
    const call = fetchMock.mock.calls[0]!;
    const opts = call[1]!;
    expect(opts.method).toBe('POST');
    expect(JSON.parse(opts.body as string)).toEqual({ name: 'test' });
  });

  it('sends PUT with JSON body', async () => {
    const fetchMock = mockFetch([{ status: 200, body: { updated: true } }]);
    globalThis.fetch = fetchMock;

    const result = await client.put<{ updated: boolean }>('/api/data/1', { name: 'updated' });

    expect(result).toEqual({ updated: true });
    const call = fetchMock.mock.calls[0]!;
    const opts = call[1]!;
    expect(opts.method).toBe('PUT');
    expect(JSON.parse(opts.body as string)).toEqual({ name: 'updated' });
  });

  it('sends DELETE request', async () => {
    const fetchMock = mockFetch([{ status: 200, body: { deleted: true } }]);
    globalThis.fetch = fetchMock;

    const result = await client.delete<{ deleted: boolean }>('/api/data/1');

    expect(result).toEqual({ deleted: true });
    const call = fetchMock.mock.calls[0]!;
    const opts = call[1]!;
    expect(opts.method).toBe('DELETE');
  });

  it('throws on non-ok response', async () => {
    const fetchMock = mockFetch([{ status: 500, body: 'Internal Server Error' }]);
    globalThis.fetch = fetchMock;

    await expect(client.get('/api/fail')).rejects.toThrow();
  });

  it('sends POST without body when body is undefined', async () => {
    const fetchMock = mockFetch([{ status: 200, body: { ok: true } }]);
    globalThis.fetch = fetchMock;

    await client.post('/api/action');

    const call = fetchMock.mock.calls[0]!;
    const opts = call[1]!;
    expect(opts.body).toBeUndefined();
  });
});
