import { useEffect, useMemo, useState } from 'react';
import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PresetConfig, EpisodeSortField, SortOrder, YearBinding } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel, HintIcon } from '@/components/editor/hint-label.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { TriStateCheckbox } from '@/components/ui/tri-state-checkbox.tsx';
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
import { NumberingExtractorForm } from '@/components/editor/numbering-extractor-form.tsx';
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
  /** Called after the id field commits on blur so parents can migrate any
   *  references keyed on the old id (e.g. activeContext in the store). */
  onIdCommit?: (oldId: string, newId: string) => void;
}

export function GroupDefCard({
  playlistIndex,
  groupIndex,
  isFirst,
  isLast,
  onMoveUp,
  onMoveDown,
  onRemove,
  onIdCommit,
}: GroupDefCardProps) {
  const { register, watch, setValue } = useFormContext<PresetConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${playlistIndex}.grouping.staticClassifiers.${groupIndex}` as const;

  // The id field commits on blur rather than on change so that external lookups
  // keyed on the id (activeContext tracking, override maps) don't tear mid-typing.
  const committedId = watch(`${prefix}.id`) ?? '';
  const [idDraft, setIdDraft] = useState(committedId);
  useEffect(() => {
    setIdDraft(committedId);
  }, [committedId]);

  const yearBinding = watch(`${prefix}.groupListing.yearBinding`);
  const episodeSort = watch(`${prefix}.episodeListing.sort` as any);
  const titleExtractor = watch(`${prefix}.episodeItem.titleExtractor` as any);
  const numberingExtractor = watch(`${prefix}.numberingExtractor` as any);

  const expandedOverrides = useMemo(() => {
    const items: string[] = [];
    if (yearBinding != null) items.push('yearBinding');
    if (episodeSort != null) items.push('episodeSort');
    if (titleExtractor != null) items.push('titleExtractor');
    if (numberingExtractor != null) items.push('numberingExtractor');
    return items;
  }, [yearBinding, episodeSort, titleExtractor, numberingExtractor]);

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
              value={idDraft}
              onChange={(e) => setIdDraft(e.target.value)}
              onBlur={() => {
                if (idDraft === committedId) return;
                setValue(`${prefix}.id`, idDraft, { shouldDirty: true });
                onIdCommit?.(committedId, idDraft);
              }}
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
            htmlFor={`group-${playlistIndex}-${groupIndex}-pattern-pattern`}
            hint="groupPattern"
          >
            {t('groupPattern')}
          </HintLabel>
          <div className="grid grid-cols-[minmax(0,8rem)_1fr] gap-3">
            <Select
              value={watch(`${prefix}.pattern.source`) ?? 'title'}
              onValueChange={(val) => {
                const currentPattern = watch(`${prefix}.pattern.pattern`) ?? '';
                setValue(
                  `${prefix}.pattern`,
                  { source: val as 'title' | 'description', pattern: currentPattern },
                  { shouldDirty: true },
                );
              }}
            >
              <SelectTrigger
                id={`group-${playlistIndex}-${groupIndex}-pattern-source`}
                aria-label={t('titleExtractorSource')}
              >
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="title">{t('source_title')}</SelectItem>
                <SelectItem value="description">{t('source_description')}</SelectItem>
              </SelectContent>
            </Select>
            <Input
              id={`group-${playlistIndex}-${groupIndex}-pattern-pattern`}
              value={watch(`${prefix}.pattern.pattern`) ?? ''}
              onChange={(e) => {
                const currentSource = watch(`${prefix}.pattern.source`) ?? 'title';
                setValue(
                  `${prefix}.pattern`,
                  { source: currentSource, pattern: e.target.value },
                  { shouldDirty: true },
                );
              }}
              placeholder={t('placeholderRegex')}
            />
          </div>
        </div>

        <h5 className="text-xs font-medium text-muted-foreground">
          {t('displayOverrides')}
        </h5>

        <div className="flex gap-6">
          <div className="flex items-center gap-2">
            <Checkbox
              id={`group-${playlistIndex}-${groupIndex}-showYearHeaders`}
              checked={watch(`${prefix}.episodeListing.showYearHeaders`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.episodeListing.showYearHeaders`, !!checked, { shouldDirty: true })
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
              checked={watch(`${prefix}.groupItem.showDateRange`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.groupItem.showDateRange`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel
              htmlFor={`group-${playlistIndex}-${groupIndex}-showDateRange`}
              hint="showDateRange"
            >
              {t('showDateRange')}
            </HintLabel>
          </div>

          <div className="flex items-center gap-2">
            <TriStateCheckbox
              id={`group-${playlistIndex}-${groupIndex}-showThumbnail`}
              value={watch(`${prefix}.groupItem.showThumbnail`)}
              onChange={(next) =>
                setValue(`${prefix}.groupItem.showThumbnail`, next, { shouldDirty: true })
              }
              title={t('triStateHint')}
            />
            <HintLabel
              htmlFor={`group-${playlistIndex}-${groupIndex}-showThumbnail`}
              hint="showThumbnail"
            >
              {t('showThumbnail')}
            </HintLabel>
          </div>
        </div>

        <Accordion type="multiple" defaultValue={expandedOverrides} key={expandedOverrides.join(',')} className="w-full">
          {/* Year Binding Override */}
          <AccordionItem value="yearBinding">
            <AccordionTrigger className="py-2 text-xs font-medium text-muted-foreground">
              {t('groupYearBinding')} <HintIcon hint="groupYearBinding" />
            </AccordionTrigger>
            <AccordionContent>
              <Select
                value={watch(`${prefix}.groupListing.yearBinding`) ?? 'none'}
                onValueChange={(v) =>
                  setValue(
                    `${prefix}.groupListing.yearBinding`,
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
              {t('groupEpisodeSort')} <HintIcon hint="groupEpisodeSort" />
            </AccordionTrigger>
            <AccordionContent>
              <GroupEpisodeSortOverride prefix={prefix} />
            </AccordionContent>
          </AccordionItem>

          {/* Title Extractor Override */}
          <AccordionItem value="titleExtractor">
            <AccordionTrigger className="py-2 text-xs font-medium text-muted-foreground">
              {t('episodeTitleExtractor')} <HintIcon hint="groupTitleExtractor" />
            </AccordionTrigger>
            <AccordionContent>
              <TitleExtractorForm
                fieldPath={`${prefix}.episodeItem.titleExtractor`}
                idPrefix={`group-title-ext-${playlistIndex}-${groupIndex}`}
                labelKey="episodeTitleExtractor"
              />
            </AccordionContent>
          </AccordionItem>

          {/* Numbering Extractor Override */}
          <AccordionItem value="numberingExtractor">
            <AccordionTrigger className="py-2 text-xs font-medium text-muted-foreground">
              {t('groupNumberingExtractor')} <HintIcon hint="groupNumberingExtractor" />
            </AccordionTrigger>
            <AccordionContent>
              <NumberingExtractorForm
                fieldPath={`${prefix}.numberingExtractor`}
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
  const { watch, setValue } = useFormContext<PresetConfig>();
  const { t } = useTranslation('editor');

  const sort = watch(`${prefix}.episodeListing.sort` as any);
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
              setValue(`${prefix}.episodeListing.sort` as any, undefined, { shouldDirty: true });
            } else {
              setValue(
                `${prefix}.episodeListing.sort` as any,
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
                setValue(`${prefix}.episodeListing.sort.field` as any, val as EpisodeSortField, {
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
                setValue(`${prefix}.episodeListing.sort.order` as any, val as SortOrder, {
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
