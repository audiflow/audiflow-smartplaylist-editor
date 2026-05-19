export const PREVIEW_FIELDS = {
  playlistDisplayName: 'playlist-header',
  filtersRequire: 'filters-require',
  filtersExclude: 'filters-exclude',
  groupingBy: 'group-list',
  partitionBy: 'partition-entries',
  selectorTitleExtractor: 'partition-entries',
  groupListingSort: 'group-list-order',
  groupListingYearBinding: 'group-year-sections',
  groupItemShowDateRange: 'group-card-date-range',
  groupItemPrependSeasonNumber: 'group-card-season-prefix',
  episodeListingSort: 'episode-order',
  episodeItemTitle: 'episode-title',
} as const;

export type PreviewFieldId = (typeof PREVIEW_FIELDS)[keyof typeof PREVIEW_FIELDS];
