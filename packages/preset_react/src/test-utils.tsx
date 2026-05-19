import type { ReactElement, ReactNode } from 'react';
import { render, type RenderOptions, type RenderResult } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ApiClientProvider } from '@/api/client-provider.tsx';
import { ApiClient } from '@/api/client.ts';

const TEST_BASE_URL = 'http://localhost:8080';

function createTestQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        gcTime: 0,
      },
      mutations: {
        retry: false,
      },
    },
  });
}

function createTestProviders(queryClient: QueryClient) {
  const client = new ApiClient(TEST_BASE_URL);

  return function TestProviders({ children }: { children: ReactNode }) {
    return (
      <QueryClientProvider client={queryClient}>
        <ApiClientProvider client={client}>
          {children}
        </ApiClientProvider>
      </QueryClientProvider>
    );
  };
}

export function renderWithProviders(
  ui: ReactElement,
  options?: Omit<RenderOptions, 'wrapper'> & { queryClient?: QueryClient },
): RenderResult & { queryClient: QueryClient } {
  const { queryClient: providedClient, ...renderOptions } = options ?? {};
  const queryClient = providedClient ?? createTestQueryClient();
  const wrapper = createTestProviders(queryClient);

  return {
    ...render(ui, { wrapper, ...renderOptions }),
    queryClient,
  };
}

export { createTestQueryClient, createTestProviders, TEST_BASE_URL };
