import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ApiClientContext } from '@/api/client-context.ts';
import { ApiClient } from '@/api/client.ts';
import { FeedViewer } from '../feed-viewer.tsx';

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  });
  const apiClient = new ApiClient('http://localhost:0');
  return function Wrapper({ children }: { children: React.ReactNode }) {
    return (
      <ApiClientContext.Provider value={apiClient}>
        <QueryClientProvider client={queryClient}>
          {children}
        </QueryClientProvider>
      </ApiClientContext.Provider>
    );
  };
}

describe('FeedViewer', () => {
  it('renders feed URL input', () => {
    render(<FeedViewer />, { wrapper: createWrapper() });
    expect(screen.getByLabelText('Feed URL')).toBeInTheDocument();
  });

  it('renders load button', () => {
    render(<FeedViewer />, { wrapper: createWrapper() });
    expect(screen.getByRole('button', { name: /load/i })).toBeInTheDocument();
  });

  it('populates input from initialUrl prop', () => {
    const url = 'https://example.com/feed.xml';
    render(<FeedViewer initialUrl={url} />, { wrapper: createWrapper() });
    expect(screen.getByLabelText('Feed URL')).toHaveValue(url);
  });

  it('renders page heading', () => {
    render(<FeedViewer />, { wrapper: createWrapper() });
    expect(
      screen.getByRole('heading', { name: /feed viewer/i }),
    ).toBeInTheDocument();
  });
});
