import { useQuery, useMutation } from '@tanstack/react-query';
import { useApiClient } from './client-context.ts';
import type {
  PatternSummary,
  FeedEpisode,
  PreviewResult,
} from '../schemas/api-schema.ts';
import type { PatternConfig } from '../schemas/config-schema.ts';

export function usePatterns() {
  const client = useApiClient();
  return useQuery({
    queryKey: ['patterns'],
    queryFn: () => client.get<PatternSummary[]>('/api/configs/patterns'),
  });
}

export function useAssembledConfig(id: string | null) {
  const client = useApiClient();
  return useQuery({
    queryKey: ['assembledConfig', id],
    queryFn: () =>
      client.get<PatternConfig>(
        `/api/configs/patterns/${id}/assembled`,
      ),
    enabled: !!id,
  });
}

export function useFeed(url: string | null) {
  const client = useApiClient();
  return useQuery({
    queryKey: ['feed', url],
    queryFn: async () => {
      const res = await client.get<{ episodes: FeedEpisode[] }>(
        `/api/feeds?url=${encodeURIComponent(url!)}`,
      );
      return res.episodes;
    },
    enabled: !!url,
    staleTime: 15 * 60 * 1000,
  });
}

export function usePreviewMutation() {
  const client = useApiClient();
  return useMutation({
    mutationFn: (params: { config: unknown; feedUrl: string }) =>
      client.post<PreviewResult>('/api/configs/preview', params),
  });
}
