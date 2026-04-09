import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, EpisodeSortField, SortOrder } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { Button } from '@/components/ui/button.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';

const EPISODE_SORT_FIELDS = ['publishedAt', 'episodeNumber', 'title'] as const;
const SORT_ORDERS = ['ascending', 'descending'] as const;

interface EpisodeListTabProps {
  index: number;
}

export function EpisodeListTab({ index }: EpisodeListTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const sort = watch(`${prefix}.episodeList.sort`);
  const isSortEnabled = sort != null;

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.episodeList" />

      <div className="rounded-lg border border-border p-4 space-y-3">
        <div className="flex items-center justify-between">
          <HintLabel hint="episodeListSort">{t('episodeListSort')}</HintLabel>
          <Button
            type="button"
            variant={isSortEnabled ? 'default' : 'outline'}
            size="sm"
            onClick={() => {
              if (isSortEnabled) {
                setValue(`${prefix}.episodeList.sort`, undefined, { shouldDirty: true });
              } else {
                setValue(
                  `${prefix}.episodeList.sort`,
                  { field: 'publishedAt', order: 'ascending' },
                  { shouldDirty: true },
                );
              }
            }}
          >
            {isSortEnabled ? t('sortEnabled') : t('sortDisabled')}
          </Button>
        </div>

        {isSortEnabled && (
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <HintLabel hint="episodeSortField">{t('episodeSortField')}</HintLabel>
              <Select
                value={sort?.field ?? 'publishedAt'}
                onValueChange={(val) =>
                  setValue(`${prefix}.episodeList.sort.field`, val as EpisodeSortField, { shouldDirty: true })
                }
              >
                <SelectTrigger className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {EPISODE_SORT_FIELDS.map((f) => (
                    <SelectItem key={f} value={f}>
                      {t(`episodeSortField_${f}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <HintLabel hint="episodeSortOrder">{t('episodeSortOrder')}</HintLabel>
              <Select
                value={sort?.order ?? 'ascending'}
                onValueChange={(val) =>
                  setValue(`${prefix}.episodeList.sort.order`, val as SortOrder, { shouldDirty: true })
                }
              >
                <SelectTrigger className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {SORT_ORDERS.map((o) => (
                    <SelectItem key={o} value={o}>
                      {t(`sortOrder_${o}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        )}
      </div>

      <InteractionNote i18nKey="interactionNote.episodeList.titleExtractorChain" />

      <TitleExtractorForm
        fieldPath={`playlists.${index}.episodeList.titleExtractor`}
        idPrefix={`ep-list-title-ext-${index}`}
      />
    </div>
  );
}
