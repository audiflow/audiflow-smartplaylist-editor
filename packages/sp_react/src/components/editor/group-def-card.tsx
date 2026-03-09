import { useMemo } from 'react';
import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, EpisodeSortField, SortOrder, YearBinding } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Card, CardContent } from '@/components/ui/card.tsx';
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { EpisodeExtractorForm } from '@/components/editor/episode-extractor-form.tsx';
import { ChevronDown, ChevronUp, Trash2 } from 'lucide-react';

const EPISODE_SORT_FIELDS = ['publishedAt', 'episodeNumber', 'title'] as const;
const SORT_ORDERS = ['ascending', 'descending'] as const;

interface GroupDefCardProps {
  playlistIndex: number;
  groupIndex: number;
  isFirst: boolean;
  isLast: boolean;
  onMoveUp: () => void;
  onMoveDown: () => void;
  onRemove: () => void;
}

export function GroupDefCard({
  playlistIndex,
  groupIndex,
  isFirst,
  isLast,
  onMoveUp,
  onMoveDown,
  onRemove,
}: GroupDefCardProps) {
  const { register, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${playlistIndex}.groups.${groupIndex}` as const;

  const yearBinding = watch(`${prefix}.display.yearBinding`);
  const episodeSort = watch(`${prefix}.episodeList.sort` as any);
  const titleExtractor = watch(`${prefix}.episodeList.titleExtractor` as any);
  const episodeExtractor = watch(`${prefix}.episodeExtractor` as any);

  const expandedOverrides = useMemo(() => {
    const items: string[] = [];
    if (yearBinding != null) items.push('yearBinding');
    if (episodeSort != null) items.push('episodeSort');
    if (titleExtractor != null) items.push('titleExtractor');
    if (episodeExtractor != null) items.push('episodeExtractor');
    return items;
  }, [yearBinding, episodeSort, titleExtractor, episodeExtractor]);

  return (
    <Card className="py-4">
      <CardContent className="space-y-3 px-4">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium">
            {watch(`${prefix}.displayName`) || t('groupDisplayName')}
          </span>
          <div className="flex items-center gap-0.5">
            <Button
              variant="ghost"
              size="sm"
              type="button"
              disabled={isFirst}
              onClick={onMoveUp}
              aria-label={t('moveGroupUp')}
            >
              <ChevronUp className="h-4 w-4" />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              type="button"
              disabled={isLast}
              onClick={onMoveDown}
              aria-label={t('moveGroupDown')}
            >
              <ChevronDown className="h-4 w-4" />
            </Button>
            <Button variant="ghost" size="sm" type="button" onClick={onRemove}>
              <Trash2 className="h-4 w-4" />
              <span className="sr-only">{t('removeGroup')}</span>
            </Button>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <HintLabel htmlFor={`group-${playlistIndex}-${groupIndex}-id`} hint="groupId">
              {t('groupId')}
            </HintLabel>
            <Input
              id={`group-${playlistIndex}-${groupIndex}-id`}
              {...register(`${prefix}.id`)}
            />
          </div>

          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`group-${playlistIndex}-${groupIndex}-displayName`}
              hint="groupDisplayName"
            >
              {t('groupDisplayName')}
            </HintLabel>
            <Input
              id={`group-${playlistIndex}-${groupIndex}-displayName`}
              {...register(`${prefix}.displayName`)}
            />
          </div>
        </div>

        <div className="space-y-1.5">
          <HintLabel
            htmlFor={`group-${playlistIndex}-${groupIndex}-pattern`}
            hint="groupPattern"
          >
            {t('groupPattern')}
          </HintLabel>
          <Input
            id={`group-${playlistIndex}-${groupIndex}-pattern`}
            {...register(`${prefix}.pattern`)}
            placeholder={t('placeholderRegex')}
          />
        </div>

        <h5 className="text-xs font-medium text-muted-foreground">
          {t('displayOverrides')}
        </h5>

        <div className="flex gap-6">
          <div className="flex items-center gap-2">
            <Checkbox
              id={`group-${playlistIndex}-${groupIndex}-showYearHeaders`}
              checked={watch(`${prefix}.episodeList.showYearHeaders`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.episodeList.showYearHeaders`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel
              htmlFor={`group-${playlistIndex}-${groupIndex}-showYearHeaders`}
              hint="showYearHeaders"
            >
              {t('showYearHeaders')}
            </HintLabel>
          </div>

          <div className="flex items-center gap-2">
            <Checkbox
              id={`group-${playlistIndex}-${groupIndex}-showDateRange`}
              checked={watch(`${prefix}.display.showDateRange`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.display.showDateRange`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel
              htmlFor={`group-${playlistIndex}-${groupIndex}-showDateRange`}
              hint="showDateRange"
            >
              {t('showDateRange')}
            </HintLabel>
          </div>
        </div>

        <Accordion type="multiple" defaultValue={expandedOverrides} className="w-full">
          {/* Year Binding Override */}
          <AccordionItem value="yearBinding">
            <AccordionTrigger className="py-2 text-xs font-medium text-muted-foreground">
              <HintLabel hint="groupYearBinding">{t('groupYearBinding')}</HintLabel>
            </AccordionTrigger>
            <AccordionContent>
              <Select
                value={watch(`${prefix}.display.yearBinding`) ?? 'none'}
                onValueChange={(v) =>
                  setValue(
                    `${prefix}.display.yearBinding`,
                    v === 'none' ? undefined : (v as YearBinding),
                    { shouldDirty: true },
                  )
                }
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">{t('yearBinding_none')}</SelectItem>
                  <SelectItem value="pinToYear">{t('yearBinding_pinToYear')}</SelectItem>
                  <SelectItem value="splitByYear">{t('yearBinding_splitByYear')}</SelectItem>
                </SelectContent>
              </Select>
            </AccordionContent>
          </AccordionItem>

          {/* Episode Sort Override */}
          <AccordionItem value="episodeSort">
            <AccordionTrigger className="py-2 text-xs font-medium text-muted-foreground">
              <HintLabel hint="groupEpisodeSort">{t('groupEpisodeSort')}</HintLabel>
            </AccordionTrigger>
            <AccordionContent>
              <GroupEpisodeSortOverride prefix={prefix} />
            </AccordionContent>
          </AccordionItem>

          {/* Title Extractor Override */}
          <AccordionItem value="titleExtractor">
            <AccordionTrigger className="py-2 text-xs font-medium text-muted-foreground">
              <HintLabel hint="groupTitleExtractor">{t('groupTitleExtractor')}</HintLabel>
            </AccordionTrigger>
            <AccordionContent>
              <TitleExtractorForm
                fieldPath={`${prefix}.episodeList.titleExtractor`}
                idPrefix={`group-title-ext-${playlistIndex}-${groupIndex}`}
              />
            </AccordionContent>
          </AccordionItem>

          {/* Episode Extractor Override */}
          <AccordionItem value="episodeExtractor">
            <AccordionTrigger className="py-2 text-xs font-medium text-muted-foreground">
              <HintLabel hint="groupEpisodeExtractor">{t('groupEpisodeExtractor')}</HintLabel>
            </AccordionTrigger>
            <AccordionContent>
              <EpisodeExtractorForm
                fieldPath={`${prefix}.episodeExtractor`}
                idPrefix={`group-ep-ext-${playlistIndex}-${groupIndex}`}
              />
            </AccordionContent>
          </AccordionItem>
        </Accordion>
      </CardContent>
    </Card>
  );
}

function GroupEpisodeSortOverride({ prefix }: { prefix: string }) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const sort = watch(`${prefix}.episodeList.sort` as any);
  const isEnabled = sort != null;

  return (
    <div className="rounded-lg border border-border p-4 space-y-3">
      <div className="flex items-center justify-between">
        <HintLabel hint="groupEpisodeSort">{t('groupEpisodeSort')}</HintLabel>
        <Button
          type="button"
          variant={isEnabled ? 'default' : 'outline'}
          size="sm"
          onClick={() => {
            if (isEnabled) {
              setValue(`${prefix}.episodeList.sort` as any, undefined, { shouldDirty: true });
            } else {
              setValue(
                `${prefix}.episodeList.sort` as any,
                { field: 'publishedAt', order: 'ascending' },
                { shouldDirty: true },
              );
            }
          }}
        >
          {isEnabled ? t('sortEnabled') : t('sortDisabled')}
        </Button>
      </div>

      {isEnabled && (
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <HintLabel hint="episodeSortField">{t('episodeSortField')}</HintLabel>
            <Select
              value={sort?.field ?? 'publishedAt'}
              onValueChange={(val) =>
                setValue(`${prefix}.episodeList.sort.field` as any, val as EpisodeSortField, {
                  shouldDirty: true,
                })
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
                setValue(`${prefix}.episodeList.sort.order` as any, val as SortOrder, {
                  shouldDirty: true,
                })
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
  );
}
