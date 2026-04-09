import { useState, useRef, useEffect, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { useFormContext, useWatch } from 'react-hook-form';
import type {
  PreviewPlaylist,
  PreviewEpisode,
  PreviewDebug,
} from '@/schemas/api-schema.ts';
import type { PatternConfig, YearBinding } from '@/schemas/config-schema.ts';
import type { EpisodeSortRule } from '@/components/preview/episode-sort-utils.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { useFeed } from '@/api/queries.ts';
import { filterEpisodes } from '@/lib/episode-filter.ts';
import { PlaylistForm } from '@/components/editor/playlist-form.tsx';
import { DebugInfoStats } from '@/components/preview/debug-info-panel.tsx';
import { ClaimedEpisodesSection } from '@/components/preview/claimed-episodes-section.tsx';
import { UngroupedEpisodesPanel } from '@/components/preview/ungrouped-episodes-panel.tsx';
import { FilteredEpisodesPanel } from '@/components/preview/filtered-episodes-panel.tsx';
import { PlaylistTree } from '@/components/preview/playlist-tree.tsx';
import { ExtractionPreview } from '@/components/preview/extraction-preview.tsx';
import {
  Tabs,
  TabsList,
  TabsTrigger,
  TabsContent,
} from '@/components/ui/tabs.tsx';
import { Badge } from '@/components/ui/badge.tsx';

interface PlaylistTabContentProps {
  index: number;
  previewPlaylist: PreviewPlaylist | null;
  ungroupedEpisodes: PreviewEpisode[];
  excludedEpisodes: PreviewEpisode[];
  globalDebug: PreviewDebug | undefined;
  playlistCount: number;
  onRemove: () => void;
}

export function PlaylistTabContent({
  index,
  previewPlaylist,
  ungroupedEpisodes,
  excludedEpisodes,
  globalDebug,
  playlistCount,
  onRemove,
}: PlaylistTabContentProps) {
  const { t } = useTranslation('editor');
  const { t: tp } = useTranslation('preview');
  const { watch, control } = useFormContext<PatternConfig>();
  const { feedUrl } = useEditorStore();
  const feedQuery = useFeed(feedUrl || null);

  const episodeFilters = useWatch({ control, name: `playlists.${index}.episodeFilters` as const });
  const prependSeasonNumber = watch(`playlists.${index}.prependSeasonNumber`) ?? false;
  const yearBinding = (watch(`playlists.${index}.groupList.yearBinding`) ?? 'none') as YearBinding;
  const groupDefs = watch(`playlists.${index}.groups`);
  const defaultSortField = watch(`playlists.${index}.episodeList.sort.field`);
  const defaultSortOrder = watch(`playlists.${index}.episodeList.sort.order`);

  const feedEpisodes = feedQuery.data ?? [];
  const filteredEpisodes = useMemo(
    () => filterEpisodes(feedEpisodes, episodeFilters ?? undefined),
    [feedEpisodes, episodeFilters],
  );

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

  const claimedCount = previewPlaylist?.claimedByOthers?.length ?? 0;
  const ungroupedCount = ungroupedEpisodes.length;
  const excludedCount = excludedEpisodes.length;
  const showClaimedTab = 2 <= playlistCount;

  return (
    <div className="pt-2">
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Config side */}
        <div className="space-y-4 lg:sticky lg:top-20 lg:h-[calc(100dvh-5.5rem)] lg:overflow-y-auto">
          <PlaylistForm index={index} onRemove={onRemove} />
        </div>

        {/* Preview side */}
        <div className="rounded-lg border bg-muted/30 p-4 space-y-3 lg:sticky lg:top-20 lg:h-[calc(100dvh-5.5rem)] lg:overflow-y-auto">
          <Tabs value={activePreviewTab} onValueChange={setActivePreviewTab}>
            <TabsList>
              <TabsTrigger value="filtered">
                {tp('tabFiltered')}
                {0 < filteredEpisodes.length && (
                  <Badge variant="secondary" className="ml-1.5">
                    {filteredEpisodes.length}
                  </Badge>
                )}
              </TabsTrigger>
              <TabsTrigger value="preview">
                {tp('tabPreview')}
                {previewPlaylist && (
                  <Badge variant="secondary" className="ml-1.5">
                    {previewPlaylist.episodeCount}
                  </Badge>
                )}
              </TabsTrigger>
            </TabsList>
            <TabsContent value="filtered">
              <FilteredEpisodesPanel
                episodes={filteredEpisodes}
                totalCount={feedEpisodes.length}
              />
            </TabsContent>
            <TabsContent value="preview">
              {previewPlaylist ? (
                <>
                  {globalDebug && (
                    <div className="border rounded-md px-3 py-1.5 mb-3">
                      <DebugInfoStats debug={globalDebug} />
                    </div>
                  )}
                  <Tabs defaultValue="groups">
                    <TabsList>
                      <TabsTrigger value="groups">
                        {tp('tabGroups')}
                        <Badge variant="secondary" className="ml-1.5">
                          {previewPlaylist.episodeCount}
                        </Badge>
                      </TabsTrigger>
                      <TabsTrigger value="ungrouped">
                        {tp('tabUngrouped')}
                        {0 < ungroupedCount && (
                          <Badge variant="secondary" className="ml-1.5">
                            {ungroupedCount}
                          </Badge>
                        )}
                      </TabsTrigger>
                      <TabsTrigger value="excluded">
                        {tp('tabExcluded')}
                        {0 < excludedCount && (
                          <Badge variant="secondary" className="ml-1.5">
                            {excludedCount}
                          </Badge>
                        )}
                      </TabsTrigger>
                      <TabsTrigger value="extraction">
                        {tp('tabExtraction')}
                      </TabsTrigger>
                      {showClaimedTab && (
                        <TabsTrigger value="claimed">
                          {tp('tabClaimed')}
                          {0 < claimedCount && (
                            <Badge variant="secondary" className="ml-1.5">
                              {claimedCount}
                            </Badge>
                          )}
                        </TabsTrigger>
                      )}
                    </TabsList>
                    <TabsContent value="groups">
                      <PlaylistTree playlists={[previewPlaylist]} prependSeasonNumber={prependSeasonNumber} yearBinding={yearBinding} groupYearBindingOverrides={groupYearBindingOverrides} episodeSortRules={episodeSortRules} />
                    </TabsContent>
                    <TabsContent value="ungrouped">
                      {0 < ungroupedCount ? (
                        <UngroupedEpisodesPanel episodes={ungroupedEpisodes} />
                      ) : (
                        <p className="text-sm text-muted-foreground py-4 text-center">
                          {tp('emptyUngrouped')}
                        </p>
                      )}
                    </TabsContent>
                    <TabsContent value="excluded">
                      {0 < excludedCount ? (
                        <UngroupedEpisodesPanel episodes={excludedEpisodes} />
                      ) : (
                        <p className="text-sm text-muted-foreground py-4 text-center">
                          {tp('emptyExcluded')}
                        </p>
                      )}
                    </TabsContent>
                    <TabsContent value="extraction">
                      <ExtractionPreview playlist={previewPlaylist} />
                    </TabsContent>
                    {showClaimedTab && (
                      <TabsContent value="claimed">
                        {0 < claimedCount ? (
                          <ClaimedEpisodesSection
                            episodes={previewPlaylist.claimedByOthers ?? []}
                          />
                        ) : (
                          <p className="text-sm text-muted-foreground py-4 text-center">
                            {tp('emptyClaimed')}
                          </p>
                        )}
                      </TabsContent>
                    )}
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
