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
import { DebugInfoStats } from '@/components/preview/debug-info-panel.tsx';
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
  const playlistId = useWatch({ control: useFormContext<PatternConfig>().control, name: `playlists.${index}.id` as const });
  const previewPlaylist = previewData?.playlists.find((p) => p.id === playlistId) ?? null;
  const ungroupedEpisodes = previewData?.ungrouped ?? [];
  const excludedEpisodes = previewData?.excluded ?? [];
  const globalDebug = previewData?.debug;
  const { t } = useTranslation('editor');
  const { t: tp } = useTranslation('preview');
  const { control } = useFormContext<PatternConfig>();
  const { feedUrl } = useEditorStore();
  const feedQuery = useFeed(feedUrl || null);

  const prependSeasonNumber = useWatch({ control, name: `playlists.${index}.prependSeasonNumber` as const }) ?? false;
  const yearBinding = (useWatch({ control, name: `playlists.${index}.groupList.yearBinding` as const }) ?? 'none') as YearBinding;
  const groupDefs = useWatch({ control, name: `playlists.${index}.groups` as const });
  const defaultSortField = useWatch({ control, name: `playlists.${index}.episodeList.sort.field` as const });
  const defaultSortOrder = useWatch({ control, name: `playlists.${index}.episodeList.sort.order` as const });

  // Retain previous preview data to avoid unmount/remount flicker during updates.
  const lastPreviewRef = useRef<{
    playlist: PreviewPlaylist;
    ungrouped: PreviewEpisode[];
    excluded: PreviewEpisode[];
    debug: PreviewDebug | undefined;
  } | null>(null);

  if (previewPlaylist) {
    lastPreviewRef.current = {
      playlist: previewPlaylist,
      ungrouped: ungroupedEpisodes,
      excluded: excludedEpisodes,
      debug: globalDebug,
    };
  }

  const stablePreview = lastPreviewRef.current;

  // Default to 'filtered' then auto-switch to 'preview' once preview data arrives.
  const [activePreviewTab, setActivePreviewTab] = useState('filtered');
  const hasAutoSwitchedRef = useRef(false);

  useEffect(() => {
    if (hasAutoSwitchedRef.current) return;
    if (previewPlaylist) {
      hasAutoSwitchedRef.current = true;
      setActivePreviewTab('preview');
    }
  }, [previewPlaylist]);
  const groupYearBindingOverrides = useMemo(() => {
    const map = new Map<string, YearBinding>();
    if (!groupDefs) return map;
    for (const g of groupDefs) {
      const override = g?.display?.yearBinding as YearBinding | undefined;
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
        const sort = g?.episodeList?.sort;
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
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Config side */}
        <div className="space-y-4 lg:sticky lg:top-20 lg:h-[calc(100dvh-5.5rem)] lg:overflow-y-auto">
          <PlaylistForm index={index} playlistCount={playlistCount} onRemove={onRemove} isNewConfig={isNewConfig} />
        </div>

        {/* Preview side */}
        <div className="rounded-lg border bg-muted/30 p-4 space-y-3 lg:sticky lg:top-20 lg:h-[calc(100dvh-5.5rem)] lg:overflow-y-auto">
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
              <LiveFilteredEpisodes index={index} feedEpisodes={feedQuery.data ?? []} />
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
                  {sp.debug && (
                    <div className="border rounded-md px-3 py-1.5 mb-3">
                      <DebugInfoStats debug={sp.debug} />
                    </div>
                  )}
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
                    <TabsContent value="ungrouped">
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
    </div>
  );
}

// Isolated component so useWatch on episodeFilters doesn't re-render the whole tree.
function LiveFilteredEpisodes({
  index,
  feedEpisodes,
}: {
  index: number;
  feedEpisodes: readonly FeedEpisode[];
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
    />
  );
}
