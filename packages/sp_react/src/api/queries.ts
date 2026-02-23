import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
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

export function useSavePlaylist() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: {
      patternId: string;
      playlistId: string;
      data: unknown;
    }) =>
      client.put<void>(
        `/api/configs/patterns/${params.patternId}/playlists/${params.playlistId}`,
        params.data,
      ),
    onSuccess: (_data, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['assembledConfig', variables.patternId],
      });
    },
  });
}

export function useSavePatternMeta() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { patternId: string; data: unknown }) =>
      client.put<void>(
        `/api/configs/patterns/${params.patternId}/meta`,
        params.data,
      ),
    onSuccess: (_data, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['assembledConfig', variables.patternId],
      });
      void queryClient.invalidateQueries({ queryKey: ['patterns'] });
    },
  });
}

export function useCreatePattern() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { data: unknown }) =>
      client.post<void>('/api/configs/patterns', params.data),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['patterns'] });
    },
  });
}

export function useDeletePlaylist() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { patternId: string; playlistId: string }) =>
      client.delete<void>(
        `/api/configs/patterns/${params.patternId}/playlists/${params.playlistId}`,
      ),
    onSuccess: (_data, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['assembledConfig', variables.patternId],
      });
    },
  });
}

export function useDeletePattern() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (patternId: string) =>
      client.delete<void>(`/api/configs/patterns/${patternId}`),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['patterns'] });
    },
  });
}
