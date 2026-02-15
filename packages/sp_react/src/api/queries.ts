import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useApiClient } from './client-context.ts';
import type {
  PatternSummary,
  FeedEpisode,
  PreviewResult,
  ApiKey,
  SubmitResponse,
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
    mutationFn: (params: { config: unknown; episodes: unknown[] }) =>
      client.post<PreviewResult>('/api/configs/preview', params),
  });
}

export function useSubmitPr() {
  const client = useApiClient();
  return useMutation({
    mutationFn: (params: {
      patternId: string;
      playlist: unknown;
      patternMeta?: unknown;
      isNewPattern?: boolean;
    }) => client.post<SubmitResponse>('/api/configs/submit', params),
  });
}

export function useApiKeys() {
  const client = useApiClient();
  return useQuery({
    queryKey: ['apiKeys'],
    queryFn: () => client.get<{ keys: ApiKey[] }>('/api/keys'),
  });
}

export function useGenerateKey() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { name: string }) =>
      client.post<{ key: string; metadata: ApiKey }>('/api/keys', params),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['apiKeys'] });
    },
  });
}

export function useRevokeKey() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => client.delete<void>(`/api/keys/${id}`),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['apiKeys'] });
    },
  });
}
