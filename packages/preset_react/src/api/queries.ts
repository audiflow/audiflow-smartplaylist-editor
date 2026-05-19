import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useApiClient } from './client-context.ts';
import type {
  PresetSummary,
  PresetIdentifiers,
  FeedEpisode,
  PreviewResult,
  PodcastSearchResponse,
} from '../schemas/api-schema.ts';
import type { PresetConfig } from '../schemas/config-schema.ts';

export function usePresets() {
  const client = useApiClient();
  return useQuery({
    queryKey: ['presets'],
    queryFn: () => client.get<PresetSummary[]>('/api/configs/presets'),
  });
}

export function usePresetIdentifiers() {
  const client = useApiClient();
  return useQuery({
    queryKey: ['presetIdentifiers'],
    queryFn: () =>
      client.get<PresetIdentifiers[]>(
        '/api/configs/presets/identifiers',
      ),
    staleTime: 60 * 1000,
  });
}

export function useAssembledConfig(id: string | null) {
  const client = useApiClient();
  return useQuery({
    queryKey: ['assembledConfig', id],
    queryFn: () =>
      client.get<PresetConfig>(
        `/api/configs/presets/${id}/assembled`,
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
      presetId: string;
      playlistId: string;
      data: unknown;
    }) =>
      client.put<void>(
        `/api/configs/presets/${params.presetId}/playlists/${params.playlistId}`,
        params.data,
      ),
    onSuccess: (_data, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['assembledConfig', variables.presetId],
      });
    },
  });
}

export function useSavePresetMeta() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { presetId: string; data: unknown }) =>
      client.put<void>(
        `/api/configs/presets/${params.presetId}/meta`,
        params.data,
      ),
    onSuccess: (_data, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['assembledConfig', variables.presetId],
      });
      void queryClient.invalidateQueries({ queryKey: ['presets'] });
      void queryClient.invalidateQueries({ queryKey: ['presetIdentifiers'] });
    },
  });
}

export function useCreatePreset() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { data: unknown }) =>
      client.post<void>('/api/configs/presets', params.data),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['presets'] });
      void queryClient.invalidateQueries({ queryKey: ['presetIdentifiers'] });
    },
  });
}

export function useDerivePatternId() {
  const client = useApiClient();
  return useMutation({
    mutationFn: (params: {
      podcastGuid?: string | null;
      feedUrls?: string[] | null;
    }) =>
      client.post<{ id: string; source: string }>(
        '/api/configs/derive-pattern-id',
        {
          podcastGuid: params.podcastGuid ?? null,
          feedUrls: params.feedUrls ?? [],
        },
      ),
  });
}

export function useDeletePlaylist() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: { presetId: string; playlistId: string }) =>
      client.delete<void>(
        `/api/configs/presets/${params.presetId}/playlists/${params.playlistId}`,
      ),
    onSuccess: (_data, variables) => {
      void queryClient.invalidateQueries({
        queryKey: ['assembledConfig', variables.presetId],
      });
    },
  });
}

export function useSearchPodcasts(term: string) {
  const client = useApiClient();
  const trimmed = term.trim();
  return useQuery({
    queryKey: ['podcastSearch', trimmed],
    queryFn: () =>
      client.get<PodcastSearchResponse>(
        `/api/podcasts/search?term=${encodeURIComponent(trimmed)}&limit=25`,
      ),
    enabled: 0 < trimmed.length,
    staleTime: 5 * 60 * 1000,
  });
}

export function useDeletePreset() {
  const client = useApiClient();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (presetId: string) =>
      client.delete<void>(`/api/configs/presets/${presetId}`),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['presets'] });
      void queryClient.invalidateQueries({ queryKey: ['presetIdentifiers'] });
    },
  });
}
