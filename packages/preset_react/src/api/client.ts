import i18n from '@/lib/i18n.ts';

export class ApiClient {
  private readonly baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  async get<T>(path: string): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
      }),
    );
  }

  async post<T>(path: string, body?: unknown): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: body !== undefined ? JSON.stringify(body) : undefined,
      }),
    );
  }

  async put<T>(path: string, body?: unknown): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: body !== undefined ? JSON.stringify(body) : undefined,
      }),
    );
  }

  async delete<T>(path: string): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
      }),
    );
  }

  private async send<T>(request: () => Promise<Response>): Promise<T> {
    const response = await request();
    if (!response.ok) {
      const text = await response.text();
      throw new Error(i18n.t('httpError', { status: response.status, text }));
    }
    return response.json() as Promise<T>;
  }
}
