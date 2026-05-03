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

export const yearBindingSchema = z.enum(['none', 'pinToYear', 'splitByYear']);

export const resolverTypeValues = ['seasonNumber', 'year', 'titleDiscovery', 'titleClassifier'] as const;

export const resolverTypeSchema = z.enum(resolverTypeValues);

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

export const numberingExtractorSchema = z.object({
  source: z.string(),
  pattern: z.string(),
  seasonGroup: z.number().nullish(),
  episodeGroup: z.number().nullish().transform((v) => v ?? 2),
  fallbackSeasonNumber: z.number().nullish(),
  fallbackEpisodePattern: z.string().nullish(),
  fallbackEpisodeCaptureGroup: z.number().nullish().transform((v) => v ?? 1),
  fallbackToRss: z.boolean().nullish().transform((v) => v ?? false),
});

// -- Matcher --

export const matcherSchema = z.object({
  source: z.enum(['title', 'description']),
  pattern: z.string(),
});

// -- Group definition --

export const groupDefSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  pattern: matcherSchema.optional(),
  groupListing: z
    .object({
      yearBinding: yearBindingSchema.optional(),
    })
    .optional(),
  groupItem: z
    .object({
      showDateRange: z.boolean().optional(),
    })
    .optional(),
  episodeListing: z
    .object({
      showYearHeaders: z.boolean().optional(),
      sort: episodeSortRuleSchema.optional(),
    })
    .optional(),
  episodeItem: z
    .object({
      titleExtractor: titleExtractorSchema.optional(),
    })
    .optional(),
  numberingExtractor: numberingExtractorSchema.optional(),
});

// -- Selector config --

export const partitionByValues = ['seasonNumber', 'year'] as const;

export const partitionBySchema = z.enum(partitionByValues);

export const selectorConfigSchema = z.object({
  partitionBy: partitionBySchema.optional(),
  titleExtractor: titleExtractorSchema.nullish(),
});

// -- v5 grouping config --

export const groupingConfigSchema = z.object({
  by: resolverTypeSchema,
  numberingExtractor: numberingExtractorSchema.nullish(),
  staticClassifiers: z.array(groupDefSchema).nullish(),
});

// -- v5 groupItem config --

export const groupItemConfigSchema = z.object({
  showDateRange: z.boolean().optional(),
  pinToYear: z.boolean().optional(),
  prependSeasonNumber: z.boolean().optional(),
  titleExtractor: titleExtractorSchema.nullish(),
});

// -- v5 episodeItem config --

export const episodeItemConfigSchema = z.object({
  titleExtractor: titleExtractorSchema.nullish(),
});

// -- v5 groupListing config --

export const groupListingConfigSchema = z.object({
  yearBinding: yearBindingSchema.optional(),
  userSortable: z.boolean().optional(),
  sort: sortRuleSchema.optional(),
});

// -- v5 episodeListing config --

export const episodeListingConfigSchema = z.object({
  showYearHeaders: z.boolean().optional(),
  sort: episodeSortRuleSchema.optional(),
});

// -- Playlist definition --

export const playlistDefinitionSchema = z.object({
  id: z.string(),
  displayName: z.string(),
  selector: selectorConfigSchema.nullish(),
  priority: z.number(),
  episodeFilters: episodeFiltersSchema.nullish(),
  // v5 fields
  grouping: groupingConfigSchema,
  groupListing: groupListingConfigSchema.nullish(),
  groupItem: groupItemConfigSchema.nullish(),
  episodeListing: episodeListingConfigSchema.nullish(),
  episodeItem: episodeItemConfigSchema.nullish(),
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
export type YearBinding = z.infer<typeof yearBindingSchema>;
export type ResolverType = z.infer<typeof resolverTypeSchema>;
export type SortRule = z.infer<typeof sortRuleSchema>;
export type EpisodeSortRule = z.infer<typeof episodeSortRuleSchema>;
export type EpisodeFilterEntry = z.infer<typeof episodeFilterEntrySchema>;
export type EpisodeFilters = z.infer<typeof episodeFiltersSchema>;
export type GroupDef = z.infer<typeof groupDefSchema>;
export type Matcher = z.infer<typeof matcherSchema>;
export type TitleExtractor = z.infer<typeof titleExtractorSchema>;
export type NumberingExtractor = z.infer<typeof numberingExtractorSchema>;
export type PartitionBy = z.infer<typeof partitionBySchema>;
export type SelectorConfig = z.infer<typeof selectorConfigSchema>;
export type GroupingConfig = z.infer<typeof groupingConfigSchema>;
export type GroupItemConfig = z.infer<typeof groupItemConfigSchema>;
export type EpisodeItemConfig = z.infer<typeof episodeItemConfigSchema>;
export type GroupListingConfig = z.infer<typeof groupListingConfigSchema>;
export type EpisodeListingConfig = z.infer<typeof episodeListingConfigSchema>;
export type PlaylistDefinition = z.infer<typeof playlistDefinitionSchema>;
export type PatternConfig = z.infer<typeof patternConfigSchema>;
