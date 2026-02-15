import { create } from 'zustand';

interface AuthState {
  token: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  setTokens: (token: string, refreshToken: string) => void;
  logout: () => void;
  loadFromStorage: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  token: null,
  refreshToken: null,
  isAuthenticated: false,

  setTokens: (token, refreshToken) => {
    localStorage.setItem('auth:token', token);
    localStorage.setItem('auth:refreshToken', refreshToken);
    set({ token, refreshToken, isAuthenticated: true });
  },

  logout: () => {
    localStorage.removeItem('auth:token');
    localStorage.removeItem('auth:refreshToken');
    set({ token: null, refreshToken: null, isAuthenticated: false });
  },

  loadFromStorage: () => {
    const token = localStorage.getItem('auth:token');
    const refreshToken = localStorage.getItem('auth:refreshToken');
    if (token && refreshToken) {
      set({ token, refreshToken, isAuthenticated: true });
    }
  },
}));
