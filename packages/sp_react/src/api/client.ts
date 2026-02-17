import i18n from '@/lib/i18n.ts';

export class ApiClient {
  private readonly baseUrl: string;
  private token: string | null = null;
  private refreshToken_: string | null = null;
  private refreshPromise: Promise<boolean> | null = null;

  onUnauthorized?: () => void;
  onTokensRefreshed?: (accessToken: string, refreshToken: string) => void;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  setToken(token: string): void {
    this.token = token;
  }

  clearToken(): void {
    this.token = null;
  }

  setRefreshToken(token: string): void {
    this.refreshToken_ = token;
  }

  clearRefreshToken(): void {
    this.refreshToken_ = null;
  }

  get hasToken(): boolean {
    return this.token !== null;
  }

  async get<T>(path: string): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'GET',
        headers: this.buildHeaders(),
      }),
    );
  }

  async post<T>(path: string, body?: unknown): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'POST',
        headers: this.buildHeaders(),
        body: body !== undefined ? JSON.stringify(body) : undefined,
      }),
    );
  }

  async put<T>(path: string, body?: unknown): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'PUT',
        headers: this.buildHeaders(),
        body: body !== undefined ? JSON.stringify(body) : undefined,
      }),
    );
  }

  async delete<T>(path: string): Promise<T> {
    return this.send<T>(() =>
      fetch(`${this.baseUrl}${path}`, {
        method: 'DELETE',
        headers: this.buildHeaders(),
      }),
    );
  }

  private async send<T>(request: () => Promise<Response>): Promise<T> {
    const response = await request();

    if (response.status !== 401) {
      if (!response.ok) {
        const text = await response.text();
        throw new Error(i18n.t('httpError', { status: response.status, text }));
      }
      return response.json() as Promise<T>;
    }

    if (!this.refreshToken_) {
      this.token = null;
      this.onUnauthorized?.();
      throw new Error(i18n.t('unauthorized'));
    }

    const refreshed = await this.tryRefresh();

    if (!refreshed) {
      this.token = null;
      this.refreshToken_ = null;
      this.onUnauthorized?.();
      throw new Error(i18n.t('unauthorized'));
    }

    const retryResponse = await request();
    if (!retryResponse.ok) {
      const text = await retryResponse.text();
      throw new Error(i18n.t('httpError', { status: retryResponse.status, text }));
    }
    return retryResponse.json() as Promise<T>;
  }

  private async tryRefresh(): Promise<boolean> {
    if (this.refreshPromise) return this.refreshPromise;

    this.refreshPromise = (async () => {
      try {
        const response = await fetch(`${this.baseUrl}/api/auth/refresh`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ refreshToken: this.refreshToken_ }),
        });

        if (response.status !== 200) return false;

        const body = (await response.json()) as {
          accessToken: string;
          refreshToken: string;
        };
        this.token = body.accessToken;
        this.refreshToken_ = body.refreshToken;
        this.onTokensRefreshed?.(body.accessToken, body.refreshToken);
        return true;
      } catch {
        return false;
      } finally {
        this.refreshPromise = null;
      }
    })();

    return this.refreshPromise;
  }

  private buildHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    return headers;
  }
}
