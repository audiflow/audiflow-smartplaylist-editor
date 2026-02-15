import { z } from 'zod';

// -- Pattern browsing --

export const patternSummarySchema = z.object({
  id: z.string(),
  version: z.number(),
  displayName: z.string(),
  feedUrlHint: z.string(),
  playlistCount: z.number(),
});

export const patternMetaSchema = z.object({
  version: z.number(),
  id: z.string(),
  podcastGuid: z.string().optional(),
  feedUrls: z.array(z.string()),
  yearGroupedEpisodes: z.boolean().default(false),
  playlists: z.array(z.string()),
});

// -- Feed episodes --

export const feedEpisodeSchema = z.object({
  id: z.number(),
  title: z.string(),
  description: z.string().nullish(),
  guid: z.string().nullish(),
  publishedAt: z.string().nullish(),
  seasonNumber: z.number().nullish(),
  episodeNumber: z.number().nullish(),
  imageUrl: z.string().nullish(),
});

// -- Preview --

export const previewEpisodeSchema = z.object({
  id: z.number(),
  title: z.string(),
  seasonNumber: z.number().nullish(),
  episodeNumber: z.number().nullish(),
});

export const previewGroupSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  sortKey: z.union([z.string(), z.number()]),
  episodeCount: z.number(),
  episodes: z.array(previewEpisodeSchema),
});

export const claimedEpisodeSchema = z.object({
  id: z.number(),
  title: z.string(),
  seasonNumber: z.number().nullish(),
  episodeNumber: z.number().nullish(),
  claimedBy: z.string(),
});

export const playlistDebugSchema = z.object({
  filterMatched: z.number(),
  episodeCount: z.number(),
  claimedByOthersCount: z.number(),
});

export const previewPlaylistSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  sortKey: z.union([z.string(), z.number()]),
  resolverType: z.string().nullish(),
  episodeCount: z.number(),
  groups: z.array(previewGroupSchema).optional(),
  claimedByOthers: z.array(claimedEpisodeSchema).optional().default([]),
  debug: playlistDebugSchema.optional(),
});

export const previewDebugSchema = z.object({
  totalEpisodes: z.number(),
  groupedEpisodes: z.number(),
  ungroupedEpisodes: z.number(),
});

export const previewResultSchema = z.object({
  playlists: z.array(previewPlaylistSchema),
  ungrouped: z.array(previewEpisodeSchema),
  resolverType: z.string().nullish(),
  debug: previewDebugSchema.optional(),
});

// -- Auth --

export const tokenResponseSchema = z.object({
  accessToken: z.string(),
  refreshToken: z.string(),
});

// -- API keys --

export const apiKeySchema = z.object({
  id: z.string(),
  name: z.string(),
  maskedKey: z.string(),
  createdAt: z.string(),
});

export const generatedKeySchema = z.object({
  key: z.string(),
  metadata: apiKeySchema,
});

// -- Submit --

export const submitResponseSchema = z.object({
  prUrl: z.string(),
  branch: z.string(),
});

// -- Inferred types --

export type PatternSummary = z.infer<typeof patternSummarySchema>;
export type PatternMeta = z.infer<typeof patternMetaSchema>;
export type FeedEpisode = z.infer<typeof feedEpisodeSchema>;
export type PreviewEpisode = z.infer<typeof previewEpisodeSchema>;
export type PreviewGroup = z.infer<typeof previewGroupSchema>;
export type PreviewPlaylist = z.infer<typeof previewPlaylistSchema>;
export type ClaimedEpisode = z.infer<typeof claimedEpisodeSchema>;
export type PlaylistDebug = z.infer<typeof playlistDebugSchema>;
export type PreviewDebug = z.infer<typeof previewDebugSchema>;
export type PreviewResult = z.infer<typeof previewResultSchema>;
export type TokenResponse = z.infer<typeof tokenResponseSchema>;
export type ApiKey = z.infer<typeof apiKeySchema>;
export type GeneratedKey = z.infer<typeof generatedKeySchema>;
export type SubmitResponse = z.infer<typeof submitResponseSchema>;
