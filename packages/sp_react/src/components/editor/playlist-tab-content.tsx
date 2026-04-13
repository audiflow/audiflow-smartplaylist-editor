import { useState, useRef, useEffect, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { useFormContext, useWatch } from 'react-hook-form';
import type {
  PreviewPlaylist,
  PreviewEpisode,
  PreviewDebug,
  FeedEpisode,
} from '@/schemas/api-schema.ts';
import type { PatternConfig, YearBinding } from '@/schemas/config-schema.ts';
import type { EpisodeSortRule } from '@/components/preview/episode-sort-utils.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { useFeed } from '@/api/queries.ts';
import { filterEpisodes } from '@/lib/episode-filter.ts';
import { PlaylistForm } from '@/components/editor/playlist-form.tsx';
import { UngroupedEpisodesPanel } from '@/components/preview/ungrouped-episodes-panel.tsx';
import { FilteredEpisodesPanel } from '@/components/preview/filtered-episodes-panel.tsx';
import { PlaylistTree } from '@/components/preview/playlist-tree.tsx';
import {
  Tabs,
  TabsList,
  TabsTrigger,
  TabsContent,
} from '@/components/ui/tabs.tsx';
import { Badge } from '@/components/ui/badge.tsx';
import { HighlightLayer } from '@/components/editor/preview/highlight-layer.tsx';

interface PlaylistTabContentProps {
  index: number;
  playlistCount: number;
  onRemove: () => void;
  isNewConfig?: boolean;
}

export function PlaylistTabContent({
  index,
  playlistCount,
  onRemove,
  isNewConfig,
}: PlaylistTabContentProps) {
  // Read preview data from Zustand store (isolated re-renders)
  const previewData = useEditorStore((s) => s.previewData);
  const resetActiveGroupContext = useEditorStore((s) => s.resetActiveGroupContext);
  const playlistId = useWatch({ control: useFormContext<PatternConfig>().control, name: `playlists.${index}.id` as const });
  const previewPlaylist = previewData?.playlists.find((p) => p.id === playlistId) ?? null;
  const ungroupedEpisodes = previewData?.ungrouped ?? [];
  const excludedEpisodes = previewData?.excluded ?? [];
  const globalDebug = previewData?.debug;
  const { t } = useTranslation('editor');
  const { t: tp } = useTranslation('preview');
  const { control } = useFormContext<PatternConfig>();
  const feedUrl = useEditorStore((s) => s.feedUrl);
  const feedQuery = useFeed(feedUrl || null);

  const playlistDisplayName = useWatch({ control, name: `playlists.${index}.displayName` as const }) ?? '';
  const prependSeasonNumber = useWatch({ control, name: `playlists.${index}.groupItem.prependSeasonNumber` as const }) ?? false;
  const yearBinding = (useWatch({ control, name: `playlists.${index}.groupListing.yearBinding` as const }) ?? 'none') as YearBinding;
  const groupDefs = useWatch({ control, name: `playlists.${index}.grouping.staticClassifiers` as const });
  const defaultSortField = useWatch({ control, name: `playlists.${index}.episodeListing.sort.field` as const });
  const defaultSortOrder = useWatch({ control, name: `playlists.${index}.episodeListing.sort.order` as const });

  // Retain previous preview data to avoid unmount/remount flicker during updates.
  // Reset when playlistId changes so stale data from a different playlist is not shown.
  const lastPreviewRef = useRef<{
    playlistId: string;
    playlist: PreviewPlaylist;
    ungrouped: PreviewEpisode[];
    excluded: PreviewEpisode[];
    debug: PreviewDebug | undefined;
  } | null>(null);

  if (previewPlaylist) {
    lastPreviewRef.current = {
      playlistId,
      playlist: previewPlaylist,
      ungrouped: ungroupedEpisodes,
      excluded: excludedEpisodes,
      debug: globalDebug,
    };
  } else if (lastPreviewRef.current && lastPreviewRef.current.playlistId !== playlistId) {
    lastPreviewRef.current = null;
  }

  const stablePreview = lastPreviewRef.current;

  // New configs: start on 'filtered', auto-switch to 'preview' once data arrives.
  // Existing configs: start directly on 'preview'.
  const [activePreviewTab, setActivePreviewTab] = useState(
    isNewConfig ? 'filtered' : 'preview',
  );
  const hasAutoSwitchedRef = useRef(!isNewConfig);

  useEffect(() => {
    if (hasAutoSwitchedRef.current) return;
    if (previewPlaylist) {
      hasAutoSwitchedRef.current = true;
      setActivePreviewTab('preview');
    }
  }, [previewPlaylist]);

  // Reset the active group context when leaving this playlist so returning
  // always starts at "all groups" rather than a stale group id.
  useEffect(() => {
    return () => {
      if (playlistId) resetActiveGroupContext(playlistId);
    };
  }, [playlistId, resetActiveGroupContext]);
  const groupYearBindingOverrides = useMemo(() => {
    const map = new Map<string, YearBinding>();
    if (!groupDefs) return map;
    for (const g of groupDefs) {
      const override = g?.groupListing?.yearBinding as YearBinding | undefined;
      if (override !== undefined && g?.id) {
        map.set(g.id, override);
      }
    }
    return map;
  }, [groupDefs]);
  const episodeSortRules = useMemo(() => {
    const map = new Map<string, EpisodeSortRule>();
    if (defaultSortField && defaultSortOrder) {
      map.set('_default', { field: defaultSortField, order: defaultSortOrder });
    }
    if (groupDefs) {
      for (const g of groupDefs) {
        const sort = g?.episodeListing?.sort;
        if (sort?.field && sort?.order && g?.id) {
          map.set(g.id, { field: sort.field, order: sort.order });
        }
      }
    }
    return map;
  }, [defaultSortField, defaultSortOrder, groupDefs]);

  const sp = stablePreview;
  const stableUngroupedCount = sp?.ungrouped.length ?? 0;
  const stableExcludedCount = sp?.excluded.length ?? 0;

  return (
    <div className="pt-2">
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_460px]">
        {/* Config side */}
        <div className="space-y-4 lg:sticky lg:top-20 lg:h-[calc(100dvh-5.5rem)] lg:overflow-y-auto">
          <PlaylistForm index={index} playlistCount={playlistCount} onRemove={onRemove} isNewConfig={isNewConfig} />
        </div>

        {/* Preview side */}
        <HighlightLayer>
          <div
            className="rounded-lg border bg-muted/30 p-4 space-y-3 lg:sticky lg:top-20 lg:h-[calc(100dvh-5.5rem)] lg:overflow-y-auto"
            data-preview-root
          >
            <div className="mx-auto w-full max-w-[420px]">
              {playlistDisplayName && (
                <header
                  data-preview-region="playlist-header"
                  className="sticky -top-4 z-20 -mx-4 mb-3 border-b bg-background/95 px-4 py-3 backdrop-blur-sm"
                >
                  <h2 className="text-base font-semibold truncate">{playlistDisplayName}</h2>
                </header>
              )}
              <Tabs value={activePreviewTab} onValueChange={setActivePreviewTab}>
                <TabsList>
                  <TabsTrigger value="filtered">
                    {tp('tabFiltered')}
                  </TabsTrigger>
                  <TabsTrigger value="excluded">
                    {tp('tabExcluded')}
                    {0 < stableExcludedCount && (
                      <Badge variant="secondary" className="ml-1.5">
                        {stableExcludedCount}
                      </Badge>
                    )}
                  </TabsTrigger>
                  <TabsTrigger value="preview">
                    {tp('tabPreview')}
                    {sp && (
                      <Badge variant="secondary" className="ml-1.5">
                        {sp.playlist.episodeCount}
                      </Badge>
                    )}
                  </TabsTrigger>
                </TabsList>
                <TabsContent value="filtered">
                  <LiveFilteredEpisodes
                    index={index}
                    feedEpisodes={feedQuery.data ?? []}
                    feedState={feedQuery.data != null ? 'success' : feedQuery.isLoading ? 'loading' : feedQuery.isError ? 'error' : 'idle'}
                  />
                </TabsContent>
                <TabsContent value="excluded">
                  {sp ? (
                    0 < stableExcludedCount ? (
                      <UngroupedEpisodesPanel episodes={sp.excluded} />
                    ) : (
                      <p className="text-sm text-muted-foreground py-4 text-center">
                        {tp('emptyExcluded')}
                      </p>
                    )
                  ) : (
                    <p className="text-sm text-muted-foreground py-4 text-center">
                      {t('tabPreviewEmpty')}
                    </p>
                  )}
                </TabsContent>
                <TabsContent value="preview">
                  {sp ? (
                    <>
                      <Tabs defaultValue="groups">
                        <TabsList>
                          <TabsTrigger value="groups">
                            {tp('tabGroups')}
                            <Badge variant="secondary" className="ml-1.5">
                              {sp.playlist.episodeCount}
                            </Badge>
                          </TabsTrigger>
                          <TabsTrigger value="ungrouped">
                            {tp('tabUngrouped')}
                            {0 < stableUngroupedCount && (
                              <Badge variant="secondary" className="ml-1.5">
                                {stableUngroupedCount}
                              </Badge>
                            )}
                          </TabsTrigger>
                        </TabsList>
                        <TabsContent value="groups">
                          <PlaylistTree playlists={[sp.playlist]} prependSeasonNumber={prependSeasonNumber} yearBinding={yearBinding} groupYearBindingOverrides={groupYearBindingOverrides} episodeSortRules={episodeSortRules} />
                        </TabsContent>
                        <TabsContent value="ungrouped" data-preview-region="ungrouped">
                          {0 < stableUngroupedCount ? (
                            <UngroupedEpisodesPanel episodes={sp.ungrouped} />
                          ) : (
                            <p className="text-sm text-muted-foreground py-4 text-center">
                              {tp('emptyUngrouped')}
                            </p>
                          )}
                        </TabsContent>
                      </Tabs>
                    </>
                  ) : (
                    <p className="text-sm text-muted-foreground py-4 text-center">
                      {t('tabPreviewEmpty')}
                    </p>
                  )}
                </TabsContent>
              </Tabs>
            </div>
          </div>
        </HighlightLayer>
      </div>
    </div>
  );
}

// Isolated component so useWatch on episodeFilters doesn't re-render the whole tree.
type FeedState = 'idle' | 'loading' | 'error' | 'success';

function LiveFilteredEpisodes({
  index,
  feedEpisodes,
  feedState,
}: {
  index: number;
  feedEpisodes: readonly FeedEpisode[];
  feedState: FeedState;
}) {
  const { control } = useFormContext<PatternConfig>();
  const episodeFilters = useWatch({ control, name: `playlists.${index}.episodeFilters` as const });

  const filtered = useMemo(
    () => filterEpisodes(feedEpisodes, episodeFilters ?? undefined),
    [feedEpisodes, episodeFilters],
  );

  return (
    <FilteredEpisodesPanel
      episodes={filtered}
      totalCount={feedEpisodes.length}
      feedState={feedState}
    />
  );
}
