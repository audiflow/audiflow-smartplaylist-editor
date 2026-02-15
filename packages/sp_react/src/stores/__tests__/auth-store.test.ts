import { describe, it, expect, beforeEach } from 'vitest';
import { useAuthStore } from '../auth-store';

describe('authStore', () => {
  beforeEach(() => {
    useAuthStore.setState({
      token: null,
      refreshToken: null,
    });
    localStorage.clear();
  });

  it('starts unauthenticated', () => {
    const state = useAuthStore.getState();
    expect(state.token).toBeNull();
    expect(state.isAuthenticated).toBe(false);
  });

  it('sets tokens and persists to localStorage', () => {
    useAuthStore.getState().setTokens('t', 'rt');
    const state = useAuthStore.getState();
    expect(state.token).toBe('t');
    expect(state.refreshToken).toBe('rt');
    expect(state.isAuthenticated).toBe(true);
    expect(localStorage.getItem('auth:token')).toBe('t');
    expect(localStorage.getItem('auth:refreshToken')).toBe('rt');
  });

  it('logs out and clears localStorage', () => {
    useAuthStore.getState().setTokens('t', 'rt');
    useAuthStore.getState().logout();
    const state = useAuthStore.getState();
    expect(state.token).toBeNull();
    expect(state.isAuthenticated).toBe(false);
    expect(localStorage.getItem('auth:token')).toBeNull();
  });

  it('loads tokens from localStorage on init', () => {
    localStorage.setItem('auth:token', 'saved-t');
    localStorage.setItem('auth:refreshToken', 'saved-rt');
    useAuthStore.getState().loadFromStorage();
    const state = useAuthStore.getState();
    expect(state.token).toBe('saved-t');
    expect(state.refreshToken).toBe('saved-rt');
  });
});
