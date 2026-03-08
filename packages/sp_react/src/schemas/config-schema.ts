import { z } from 'zod';

// -- Enums --

export const sortFieldSchema = z.enum([
  'playlistNumber',
  'newestEpisodeDate',
  'alphabetical',
]);

export const episodeSortFieldSchema = z.enum([
  'publishedAt',
  'episodeNumber',
  'title',
]);

export const sortOrderSchema = z.enum(['ascending', 'descending']);

export const playlistStructureSchema = z.enum(['split', 'grouped']);

export const yearBindingSchema = z.enum(['none', 'pinToYear', 'splitByYear']);

export const resolverTypeSchema = z.enum([
  'rss',
  'category',
  'year',
  'titleAppearanceOrder',
]);

// -- Sort types --

export const sortRuleSchema = z.object({
  field: sortFieldSchema,
  order: sortOrderSchema,
});

export const episodeSortRuleSchema = z.object({
  field: episodeSortFieldSchema,
  order: sortOrderSchema,
});

// -- Episode filters --

export const episodeFilterEntrySchema = z.object({
  title: z.string().optional(),
  description: z.string().optional(),
});

export const episodeFiltersSchema = z.object({
  require: z.array(episodeFilterEntrySchema).optional(),
  exclude: z.array(episodeFilterEntrySchema).optional(),
});

// -- Settings --

export const groupListSettingsSchema = z.object({
  yearBinding: yearBindingSchema.optional(),
  userSortable: z.boolean().default(true).optional(),
  showDateRange: z.boolean().default(false).optional(),
  sort: sortRuleSchema.optional(),
});

export const episodeListSettingsSchema = z.object({
  showYearHeaders: z.boolean().default(false).optional(),
  sort: episodeSortRuleSchema.optional(),
  titleExtractor: z.lazy(() => titleExtractorSchema).optional(),
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
  seasonGroup: z.number().nullish(),
  episodeGroup: z.number().nullish().transform((v) => v ?? 2),
  fallbackSeasonNumber: z.number().nullish(),
  fallbackEpisodePattern: z.string().nullish(),
  fallbackEpisodeCaptureGroup: z.number().nullish().transform((v) => v ?? 1),
  fallbackToRss: z.boolean().nullish().transform((v) => v ?? false),
});

// -- Group definition --

export const groupDefSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  pattern: z.string().optional(),
  display: z
    .object({
      showDateRange: z.boolean().optional(),
      yearBinding: yearBindingSchema.optional(),
    })
    .optional(),
  episodeList: z
    .object({
      showYearHeaders: z.boolean().optional(),
      sort: episodeSortRuleSchema.optional(),
      titleExtractor: titleExtractorSchema.optional(),
    })
    .optional(),
  episodeExtractor: episodeExtractorSchema.optional(),
});

// -- Playlist definition --

export const playlistDefinitionSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  resolverType: z.string(),
  playlistStructure: z.string(),
  priority: z
    .number()
    .nullish()
    .transform((v) => v ?? 0),
  episodeFilters: episodeFiltersSchema.nullish(),
  prependSeasonNumber: z.boolean().default(false),
  nullSeasonGroupKey: z.number().nullish(),
  groups: z.array(groupDefSchema).nullish(),
  groupList: groupListSettingsSchema.nullish(),
  episodeList: episodeListSettingsSchema.nullish(),
  titleExtractor: titleExtractorSchema.nullish(),
  episodeExtractor: episodeExtractorSchema.nullish(),
});

// -- Pattern config --

export const patternConfigSchema = z.object({
  id: z.string(),
  displayName: z.string().nullish().transform((v) => v ?? ''),
  podcastGuid: z.string().nullish(),
  feedUrls: z.array(z.string()).nullish(),
  yearGroupedEpisodes: z.boolean().nullish().transform((v) => v ?? false),
  playlists: z.array(playlistDefinitionSchema),
});

// -- Inferred types --

export type SortField = z.infer<typeof sortFieldSchema>;
export type EpisodeSortField = z.infer<typeof episodeSortFieldSchema>;
export type SortOrder = z.infer<typeof sortOrderSchema>;
export type PlaylistStructure = z.infer<typeof playlistStructureSchema>;
export type YearBinding = z.infer<typeof yearBindingSchema>;
export type ResolverType = z.infer<typeof resolverTypeSchema>;
export type SortRule = z.infer<typeof sortRuleSchema>;
export type EpisodeSortRule = z.infer<typeof episodeSortRuleSchema>;
export type EpisodeFilterEntry = z.infer<typeof episodeFilterEntrySchema>;
export type EpisodeFilters = z.infer<typeof episodeFiltersSchema>;
export type GroupListSettings = z.infer<typeof groupListSettingsSchema>;
export type EpisodeListSettings = z.infer<typeof episodeListSettingsSchema>;
export type GroupDef = z.infer<typeof groupDefSchema>;
export type TitleExtractor = z.infer<typeof titleExtractorSchema>;
export type EpisodeExtractor = z.infer<typeof episodeExtractorSchema>;
export type PlaylistDefinition = z.infer<typeof playlistDefinitionSchema>;
export type PatternConfig = z.infer<typeof patternConfigSchema>;
