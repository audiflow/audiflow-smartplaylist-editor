import { z } from 'zod';

// -- Enums --

export const sortFieldSchema = z.enum([
  'playlistNumber',
  'newestEpisodeDate',
  'progress',
  'alphabetical',
]);

export const sortOrderSchema = z.enum(['ascending', 'descending']);

export const contentTypeSchema = z.enum(['episodes', 'groups']);

export const yearHeaderModeSchema = z.enum([
  'none',
  'firstEpisode',
  'perEpisode',
]);

export const resolverTypeSchema = z.enum([
  'rss',
  'category',
  'year',
  'titleAppearanceOrder',
]);

// -- Sort types (discriminated unions) --

export const sortConditionSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('sortKeyGreaterThan'),
    value: z.number(),
  }),
]);

export const sortRuleSchema = z.object({
  field: sortFieldSchema,
  order: sortOrderSchema,
  condition: sortConditionSchema.optional(),
});

export const smartPlaylistSortSpecSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('simple'),
    field: sortFieldSchema,
    order: sortOrderSchema,
  }),
  z.object({
    type: z.literal('composite'),
    rules: z.array(sortRuleSchema),
  }),
]);

// -- Group definition --

export const groupDefSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  pattern: z.string().optional(),
  episodeYearHeaders: z.boolean().optional(),
  showDateRange: z.boolean().optional(),
});

// -- Extractors --

// Recursive type for title extractor with fallback chain
export type TitleExtractorInput = {
  source: string;
  pattern?: string | null;
  group?: number;
  template?: string | null;
  fallback?: TitleExtractorInput | null;
  fallbackValue?: string | null;
};

export const titleExtractorSchema: z.ZodType<TitleExtractorInput> = z.lazy(
  () =>
    z.object({
      source: z.string(),
      pattern: z.string().nullish(),
      group: z.number().nullish().transform((v) => v ?? 0),
      template: z.string().nullish(),
      fallback: titleExtractorSchema.nullish(),
      fallbackValue: z.string().nullish(),
    }),
);

export const episodeExtractorSchema = z.object({
  source: z.string(),
  pattern: z.string(),
  seasonGroup: z.number().nullish().transform((v) => v ?? 1),
  episodeGroup: z.number().nullish().transform((v) => v ?? 2),
  fallbackSeasonNumber: z.number().nullish(),
  fallbackEpisodePattern: z.string().nullish(),
  fallbackEpisodeCaptureGroup: z.number().nullish().transform((v) => v ?? 1),
});

export const episodeNumberExtractorSchema = z.object({
  pattern: z.string(),
  captureGroup: z.number().nullish().transform((v) => v ?? 1),
  fallbackToRss: z.boolean().nullish().transform((v) => v ?? true),
});

// -- Playlist definition --

export const playlistDefinitionSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  resolverType: z.string(),
  priority: z
    .number()
    .nullish()
    .transform((v) => v ?? 0),
  contentType: z.string().nullish(),
  yearHeaderMode: z.string().nullish(),
  episodeYearHeaders: z.boolean().nullish().transform((v) => v ?? false),
  showDateRange: z.boolean().nullish().transform((v) => v ?? false),
  titleFilter: z.string().nullish(),
  excludeFilter: z.string().nullish(),
  requireFilter: z.string().nullish(),
  nullSeasonGroupKey: z.number().nullish(),
  groups: z.array(groupDefSchema).nullish(),
  customSort: smartPlaylistSortSpecSchema.nullish(),
  titleExtractor: titleExtractorSchema.nullish(),
  episodeNumberExtractor: episodeNumberExtractorSchema.nullish(),
  smartPlaylistEpisodeExtractor: episodeExtractorSchema.nullish(),
});

// -- Pattern config --

export const patternConfigSchema = z.object({
  id: z.string(),
  podcastGuid: z.string().nullish(),
  feedUrls: z.array(z.string()).nullish(),
  yearGroupedEpisodes: z.boolean().nullish().transform((v) => v ?? false),
  playlists: z.array(playlistDefinitionSchema),
});

// -- Inferred types --

export type SortField = z.infer<typeof sortFieldSchema>;
export type SortOrder = z.infer<typeof sortOrderSchema>;
export type ContentType = z.infer<typeof contentTypeSchema>;
export type YearHeaderMode = z.infer<typeof yearHeaderModeSchema>;
export type ResolverType = z.infer<typeof resolverTypeSchema>;
export type SortCondition = z.infer<typeof sortConditionSchema>;
export type SortRule = z.infer<typeof sortRuleSchema>;
export type SmartPlaylistSortSpec = z.infer<typeof smartPlaylistSortSpecSchema>;
export type GroupDef = z.infer<typeof groupDefSchema>;
export type TitleExtractor = z.infer<typeof titleExtractorSchema>;
export type EpisodeExtractor = z.infer<typeof episodeExtractorSchema>;
export type EpisodeNumberExtractor = z.infer<
  typeof episodeNumberExtractorSchema
>;
export type PlaylistDefinition = z.infer<typeof playlistDefinitionSchema>;
export type PatternConfig = z.infer<typeof patternConfigSchema>;
