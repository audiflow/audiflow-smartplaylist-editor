import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';

interface FileChangeEvent {
  type: 'created' | 'modified' | 'deleted';
  path: string;
}

/**
 * Subscribes to SSE file change events from the server
 * and invalidates relevant TanStack Query caches.
 */
export function useFileEvents(): void {
  const queryClient = useQueryClient();

  useEffect(() => {
    const baseUrl =
      (import.meta.env.VITE_API_BASE_URL as string) || 'http://localhost:8080';
    const source = new EventSource(`${baseUrl}/api/events`);

    source.onmessage = (event: MessageEvent) => {
      const change = JSON.parse(event.data as string) as FileChangeEvent;
      invalidateForChange(queryClient, change);
    };

    source.onerror = () => {
      // EventSource auto-reconnects on error
    };

    return () => source.close();
  }, [queryClient]);
}

function invalidateForChange(
  queryClient: ReturnType<typeof useQueryClient>,
  change: FileChangeEvent,
): void {
  const { path } = change;

  if (path === 'patterns/meta.json') {
    void queryClient.invalidateQueries({ queryKey: ['patterns'] });
    return;
  }

  const metaMatch = path.match(/^patterns\/([^/]+)\/meta\.json$/);
  if (metaMatch) {
    void queryClient.invalidateQueries({
      queryKey: ['assembledConfig', metaMatch[1]],
    });
    return;
  }

  const playlistMatch = path.match(
    /^patterns\/([^/]+)\/playlists\/[^/]+\.json$/,
  );
  if (playlistMatch) {
    void queryClient.invalidateQueries({
      queryKey: ['assembledConfig', playlistMatch[1]],
    });
    return;
  }
}

export type { FileChangeEvent };
