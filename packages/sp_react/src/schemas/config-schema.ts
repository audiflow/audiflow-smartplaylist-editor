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

export const presentationSchema = z.enum(['separate', 'combined']);

export const yearBindingSchema = z.enum(['none', 'pinToYear', 'splitByYear']);

// Legacy v3 resolver type strings mapped to v4 equivalents.
const legacyResolverTypeMap: Record<string, string> = {
  rss: 'seasonNumber',
  category: 'titleClassifier',
  titleAppearanceOrder: 'titleDiscovery',
};

export const resolverTypeValues = ['seasonNumber', 'year', 'titleDiscovery', 'titleClassifier'] as const;

export const resolverTypeSchema = z.preprocess(
  (val) => {
    if (typeof val === 'string' && Object.hasOwn(legacyResolverTypeMap, val)) {
      return legacyResolverTypeMap[val];
    }
    return val;
  },
  z.enum(resolverTypeValues),
);

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

// Legacy v3 presentation value strings mapped to v4 equivalents.
const legacyPresentationMap: Record<string, string> = {
  grouped: 'combined',
  split: 'separate',
};

// Migrate legacy v3 keys and values to v4 equivalents.
// - `episodeExtractor` -> `numberingExtractor`
// - `playlistStructure` -> `presentation` (with value mapping)
function migrateLegacyKeys(val: unknown): unknown {
  if (val == null || typeof val !== 'object' || Array.isArray(val)) return val;
  const obj = val as Record<string, unknown>;
  let result: Record<string, unknown> = { ...obj };

  // Migrate episodeExtractor -> numberingExtractor
  if ('episodeExtractor' in result && !('numberingExtractor' in result)) {
    const { episodeExtractor, ...rest } = result;
    result = { ...rest, numberingExtractor: episodeExtractor };
  }

  // Migrate playlistStructure -> presentation (with value mapping)
  if ('playlistStructure' in result && !('presentation' in result)) {
    const { playlistStructure, ...rest } = result;
    const mapped =
      typeof playlistStructure === 'string' && Object.hasOwn(legacyPresentationMap, playlistStructure)
        ? legacyPresentationMap[playlistStructure]
        : playlistStructure;
    result = { ...rest, presentation: mapped };
  }

  // Normalize legacy presentation values even when key is already `presentation`
  // (e.g., backend may return `presentation: "grouped"` after alias deserialization)
  if ('presentation' in result && typeof result.presentation === 'string' && Object.hasOwn(legacyPresentationMap, result.presentation)) {
    result = { ...result, presentation: legacyPresentationMap[result.presentation] };
  }

  return result;
}

// -- Group definition --

export const groupDefSchema = z.preprocess(
  migrateLegacyKeys,
  z.object({
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
    numberingExtractor: numberingExtractorSchema.optional(),
  }),
);

// -- Selector config --

export const partitionByValues = ['group', 'seasonNumber', 'year'] as const;

export const partitionBySchema = z.enum(partitionByValues);

export const selectorConfigSchema = z.object({
  partitionBy: partitionBySchema.optional(),
  titleExtractor: titleExtractorSchema.nullish(),
});

// -- Playlist definition --

export const playlistDefinitionSchema = z.preprocess(
  migrateLegacyKeys,
  z.object({
    id: z.string(),
    displayName: z.string(),
    resolverType: resolverTypeSchema,
    presentation: presentationSchema.nullish(),
    selector: selectorConfigSchema.nullish(),
    priority: z
      .number()
      .nullish()
      .transform((v) => v ?? 0),
    episodeFilters: episodeFiltersSchema.nullish(),
    prependSeasonNumber: z.boolean().default(false),
    groups: z.array(groupDefSchema).nullish(),
    groupList: groupListSettingsSchema.nullish(),
    episodeList: episodeListSettingsSchema.nullish(),
    titleExtractor: titleExtractorSchema.nullish(),
    numberingExtractor: numberingExtractorSchema.nullish(),
  }),
);

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
export type Presentation = z.infer<typeof presentationSchema>;
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
export type NumberingExtractor = z.infer<typeof numberingExtractorSchema>;
export type PartitionBy = z.infer<typeof partitionBySchema>;
export type SelectorConfig = z.infer<typeof selectorConfigSchema>;
export type PlaylistDefinition = z.infer<typeof playlistDefinitionSchema>;
export type PatternConfig = z.infer<typeof patternConfigSchema>;
