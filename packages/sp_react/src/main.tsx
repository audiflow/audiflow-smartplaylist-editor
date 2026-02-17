import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createRouter, RouterProvider } from '@tanstack/react-router';
import { routeTree } from './routeTree.gen';
import { ApiClient } from './api/client.ts';
import { ApiClientProvider } from './api/client-provider.tsx';
import { useAuthStore } from './stores/auth-store.ts';
import './lib/i18n.ts';
import './index.css';

const API_BASE_URL =
  (import.meta.env.VITE_API_BASE_URL as string) || 'http://localhost:8080';

// --- OAuth token extraction from URL ---
const params = new URLSearchParams(window.location.search);
const urlToken = params.get('token');
const urlRefreshToken = params.get('refresh_token');

if (urlToken && urlRefreshToken) {
  useAuthStore.getState().setTokens(urlToken, urlRefreshToken);
  window.history.replaceState({}, '', window.location.pathname);
} else {
  useAuthStore.getState().loadFromStorage();
}

// --- API client setup ---
const apiClient = new ApiClient(API_BASE_URL);

// Sync initial tokens from auth store
const initialAuth = useAuthStore.getState();
if (initialAuth.token) apiClient.setToken(initialAuth.token);
if (initialAuth.refreshToken) apiClient.setRefreshToken(initialAuth.refreshToken);

// Keep API client tokens in sync with auth store changes
useAuthStore.subscribe((state) => {
  if (state.token) {
    apiClient.setToken(state.token);
  } else {
    apiClient.clearToken();
  }
  if (state.refreshToken) {
    apiClient.setRefreshToken(state.refreshToken);
  } else {
    apiClient.clearRefreshToken();
  }
});

apiClient.onTokensRefreshed = (accessToken, refreshToken) => {
  useAuthStore.getState().setTokens(accessToken, refreshToken);
};

apiClient.onUnauthorized = () => {
  useAuthStore.getState().logout();
};

// --- Router and QueryClient ---
const queryClient = new QueryClient();
const router = createRouter({ routeTree });

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <ApiClientProvider client={apiClient}>
        <RouterProvider router={router} />
      </ApiClientProvider>
    </QueryClientProvider>
  </StrictMode>,
);
