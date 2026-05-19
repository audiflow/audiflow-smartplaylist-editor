import { useMemo, useEffect } from 'react';
import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PresetConfig } from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { useFeed } from '@/api/queries.ts';
import { Button } from '@/components/ui/button.tsx';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs.tsx';
import { Accordion, AccordionItem, AccordionTrigger, AccordionContent } from '@/components/ui/accordion.tsx';
import { BasicSettingsTab } from '@/components/editor/tabs/basic-settings-tab.tsx';
import { EpisodeFilterTab } from '@/components/editor/tabs/episode-filter-tab.tsx';
import { OrganizeTab } from '@/components/editor/tabs/organize-tab.tsx';
import { DisplaySettingsTab } from '@/components/editor/tabs/display-settings-tab.tsx';
import { Trash2 } from 'lucide-react';

interface PlaylistFormProps {
  index: number;
  playlistCount: number;
  onRemove: () => void;
  isNewConfig?: boolean;
}

const EMPTY_TITLES: readonly string[] = [];

const TAB_TO_REGION: Record<string, string | null> = {
  basic: 'playlist-header',
  filters: 'filters',
  organize: 'group-list',
  display: 'group-list',
};

function ErrorDot({ visible, label }: { visible: boolean; label: string }) {
  if (!visible) return null;
  return (
    <>
      <span className="ml-1 inline-block h-2 w-2 rounded-full bg-destructive" aria-hidden="true" />
      <span className="sr-only">{label}</span>
    </>
  );
}

export function PlaylistForm({ index, playlistCount, onRemove, isNewConfig }: PlaylistFormProps) {
  const { t } = useTranslation('editor');
  const { formState } = useFormContext<PresetConfig>();

  const feedUrl = useEditorStore((s) => s.feedUrl);
  const setActivePreviewRegion = useEditorStore((s) => s.setActivePreviewRegion);
  const defaultTab = isNewConfig ? 'basic' : 'organize';

  useEffect(() => {
    setActivePreviewRegion(TAB_TO_REGION[defaultTab] ?? null);
    return () => setActivePreviewRegion(null);
  }, [setActivePreviewRegion, defaultTab]);

  const feedQuery = useFeed(feedUrl || null);
  const episodeTitles = useMemo(
    () => feedQuery.data?.map((ep) => ep.title) ?? EMPTY_TITLES,
    [feedQuery.data],
  );

  const errors = formState.errors.playlists?.[index];
  const hasBasicError = !!(errors?.id || errors?.displayName);
  const hasFilterError = !!errors?.episodeFilters;
  const hasOrganizeError = !!(errors?.grouping || errors?.selector?.partitionBy);
  const hasDisplayError = !!(
    errors?.selector?.titleExtractor
    || errors?.groupListing
    || errors?.groupItem
    || errors?.episodeListing
    || errors?.episodeItem
  );

  return (
    <div className="space-y-4">
      <Tabs defaultValue={defaultTab} onValueChange={(v) => setActivePreviewRegion(TAB_TO_REGION[v] ?? null)}>
        <TabsList className="w-full">
          <TabsTrigger value="basic">
            {t('tab.basicSettings')}
            <ErrorDot visible={hasBasicError} label={t('tab.hasErrors')} />
          </TabsTrigger>
          <TabsTrigger value="filters">
            {t('tab.episodeFilters')}
            <ErrorDot visible={hasFilterError} label={t('tab.hasErrors')} />
          </TabsTrigger>
          <TabsTrigger value="organize">
            {t('tab.organize')}
            <ErrorDot visible={hasOrganizeError} label={t('tab.hasErrors')} />
          </TabsTrigger>
          <TabsTrigger value="display">
            {t('tab.displaySettings')}
            <ErrorDot visible={hasDisplayError} label={t('tab.hasErrors')} />
          </TabsTrigger>
        </TabsList>

        <TabsContent value="basic">
          <BasicSettingsTab index={index} />
        </TabsContent>
        <TabsContent value="filters">
          <EpisodeFilterTab index={index} episodeTitles={episodeTitles} />
        </TabsContent>
        <TabsContent value="organize">
          <OrganizeTab index={index} playlistCount={playlistCount} />
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
