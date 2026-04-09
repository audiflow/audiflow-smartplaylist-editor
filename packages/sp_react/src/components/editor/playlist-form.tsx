import { useMemo } from 'react';
import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { useFeed } from '@/api/queries.ts';
import { Button } from '@/components/ui/button.tsx';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs.tsx';
import { Accordion, AccordionItem, AccordionTrigger, AccordionContent } from '@/components/ui/accordion.tsx';
import { BasicSettingsTab } from '@/components/editor/tabs/basic-settings-tab.tsx';
import { EpisodeFilterTab } from '@/components/editor/tabs/episode-filter-tab.tsx';
import { EpisodeListTab } from '@/components/editor/tabs/episode-list-tab.tsx';
import { ResolverTab } from '@/components/editor/tabs/resolver-tab.tsx';
import { DisplaySettingsTab } from '@/components/editor/tabs/display-settings-tab.tsx';
import { Trash2 } from 'lucide-react';

interface PlaylistFormProps {
  index: number;
  playlistCount: number;
  onRemove: () => void;
}

const EMPTY_TITLES: readonly string[] = [];

function ErrorDot({ visible }: { visible: boolean }) {
  if (!visible) return null;
  return (
    <span className="ml-1 inline-block h-2 w-2 rounded-full bg-destructive" aria-hidden="true" />
  );
}

export function PlaylistForm({ index, playlistCount, onRemove }: PlaylistFormProps) {
  const { t } = useTranslation('editor');
  const { formState } = useFormContext<PatternConfig>();

  const feedUrl = useEditorStore((s) => s.feedUrl);
  const feedQuery = useFeed(feedUrl || null);
  const episodeTitles = useMemo(
    () => feedQuery.data?.map((ep) => ep.title) ?? EMPTY_TITLES,
    [feedQuery.data],
  );

  const errors = formState.errors.playlists?.[index];
  const hasBasicError = !!(errors?.id || errors?.displayName);
  const hasFilterError = !!errors?.episodeFilters;
  const hasEpisodeListError = !!(errors?.episodeList?.sort || errors?.episodeList?.titleExtractor);
  const hasResolverError = !!(errors?.resolverType || errors?.presentation || errors?.numberingExtractor || errors?.titleExtractor);
  const hasDisplayError = !!(errors?.prependSeasonNumber || errors?.episodeList?.showYearHeaders || errors?.groupList?.yearBinding || errors?.groupList?.showDateRange || errors?.groupList?.userSortable);

  return (
    <div className="space-y-4">
      <Tabs defaultValue="basic">
        <TabsList className="w-full">
          <TabsTrigger value="basic">
            {t('tab.basicSettings')}
            <ErrorDot visible={hasBasicError} />
          </TabsTrigger>
          <TabsTrigger value="filters">
            {t('tab.episodeFilters')}
            <ErrorDot visible={hasFilterError} />
          </TabsTrigger>
          <TabsTrigger value="episode-list">
            {t('tab.episodeList')}
            <ErrorDot visible={hasEpisodeListError} />
          </TabsTrigger>
          <TabsTrigger value="resolver">
            {t('tab.resolver')}
            <ErrorDot visible={hasResolverError} />
          </TabsTrigger>
          <TabsTrigger value="display">
            {t('tab.displaySettings')}
            <ErrorDot visible={hasDisplayError} />
          </TabsTrigger>
        </TabsList>

        <TabsContent value="basic">
          <BasicSettingsTab index={index} />
        </TabsContent>
        <TabsContent value="filters">
          <EpisodeFilterTab index={index} episodeTitles={episodeTitles} />
        </TabsContent>
        <TabsContent value="episode-list">
          <EpisodeListTab index={index} />
        </TabsContent>
        <TabsContent value="resolver">
          <ResolverTab index={index} playlistCount={playlistCount} />
        </TabsContent>
        <TabsContent value="display">
          <DisplaySettingsTab index={index} />
        </TabsContent>
      </Tabs>

      <Accordion type="single" collapsible className="mt-8">
        <AccordionItem value="danger-zone" className="border-destructive/30">
          <AccordionTrigger className="text-sm text-destructive hover:text-destructive">
            {t('dangerZone')}
          </AccordionTrigger>
          <AccordionContent>
            <div className="flex justify-end pt-2">
              <Button variant="destructive" size="sm" type="button" onClick={onRemove}>
                <Trash2 className="mr-2 h-4 w-4" />
                {t('removePlaylist')}
              </Button>
            </div>
          </AccordionContent>
        </AccordionItem>
      </Accordion>
    </div>
  );
}
