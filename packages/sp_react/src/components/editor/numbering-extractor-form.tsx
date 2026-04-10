import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { Plus, Trash2 } from 'lucide-react';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Card, CardContent } from '@/components/ui/card.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';

const SOURCE_OPTIONS = ['title', 'description'] as const;

interface NumberingExtractorFormProps {
  fieldPath: string;
  idPrefix: string;
}

export function NumberingExtractorForm({ fieldPath, idPrefix }: NumberingExtractorFormProps) {
  const { register, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const extractor = watch(fieldPath as any);

  if (!extractor) {
    return (
      <div className="space-y-2">
        <h4 className="text-sm font-medium">{t('numberingExtractor')}</h4>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() =>
            setValue(fieldPath as any, {
              source: 'title',
              pattern: '',
              seasonGroup: 1,
              episodeGroup: 2,
              fallbackEpisodeCaptureGroup: 1,
              fallbackToRss: false,
            }, { shouldDirty: true })
          }
        >
          <Plus className="mr-2 h-4 w-4" />
          {t('add')}
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <h4 className="text-sm font-medium">
        <HintLabel hint="numberingExtractor">{t('numberingExtractor')}</HintLabel>
      </h4>

      <Card className="py-4">
        <CardContent className="space-y-3 px-4">
          <div className="flex justify-end">
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={() =>
                setValue(
                  fieldPath as any,
                  null,
                  { shouldDirty: true },
                )
              }
            >
              <Trash2 className="h-4 w-4" />
              <span className="sr-only">{t('removeFallbackStep')}</span>
            </Button>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <HintLabel
                htmlFor={`${idPrefix}-source`}
                hint="numberingExtractorSource"
              >
                {t('numberingExtractorSource')}
              </HintLabel>
              <Select
                value={watch(`${fieldPath}.source` as any) ?? 'title'}
                onValueChange={(val) => setValue(`${fieldPath}.source` as any, val, { shouldDirty: true })}
              >
                <SelectTrigger id={`${idPrefix}-source`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {SOURCE_OPTIONS.map((src) => (
                    <SelectItem key={src} value={src}>
                      {t(`source_${src}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <HintLabel
                htmlFor={`${idPrefix}-pattern`}
                hint="numberingExtractorPattern"
              >
                {t('numberingExtractorPattern')}
              </HintLabel>
              <Input
                id={`${idPrefix}-pattern`}
                {...register(`${fieldPath}.pattern` as any)}
                placeholder={t('placeholderRegex')}
              />
            </div>

            <div className="space-y-1.5">
              <HintLabel
                htmlFor={`${idPrefix}-seasonGroup`}
                hint="numberingExtractorSeasonGroup"
              >
                {t('numberingExtractorSeasonGroup')}
              </HintLabel>
              <Input
                id={`${idPrefix}-seasonGroup`}
                type="number" className="w-24"
                {...register(`${fieldPath}.seasonGroup` as any, {
                  setValueAs: (v) =>
                    v === '' || v === null || v === undefined
                      ? null
                      : Number(v),
                })}
              />
            </div>

            <div className="space-y-1.5">
              <HintLabel
                htmlFor={`${idPrefix}-episodeGroup`}
                hint="numberingExtractorEpisodeGroup"
              >
                {t('numberingExtractorEpisodeGroup')}
              </HintLabel>
              <Input
                id={`${idPrefix}-episodeGroup`}
                type="number" className="w-24"
                {...register(`${fieldPath}.episodeGroup` as any, {
                  setValueAs: (v) =>
                    v === '' || v === null || v === undefined
                      ? null
                      : Number(v),
                })}
              />
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Checkbox
              id={`${idPrefix}-fallbackToRss`}
              checked={watch(`${fieldPath}.fallbackToRss` as any) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${fieldPath}.fallbackToRss` as any, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel
              htmlFor={`${idPrefix}-fallbackToRss`}
              hint="numberingExtractorFallbackToRss"
            >
              {t('numberingExtractorFallbackToRss')}
            </HintLabel>
          </div>

          <div className="space-y-3 border-t pt-3">
            <p className="text-xs text-muted-foreground font-medium">
              {t('numberingExtractorFallbackSeason')}
            </p>

            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <HintLabel
                  htmlFor={`${idPrefix}-fallbackSeasonNumber`}
                  hint="numberingExtractorFallbackSeason"
                >
                  {t('numberingExtractorFallbackSeason')}
                </HintLabel>
                <Input
                  id={`${idPrefix}-fallbackSeasonNumber`}
                  type="number" className="w-24"
                  {...register(`${fieldPath}.fallbackSeasonNumber` as any, {
                    setValueAs: (v) =>
                      v === '' || v === null || v === undefined
                        ? null
                        : Number(v),
                  })}
                />
              </div>

              <div className="space-y-1.5">
                <HintLabel
                  htmlFor={`${idPrefix}-fallbackEpisodeCaptureGroup`}
                  hint="numberingExtractorFallbackCaptureGroup"
                >
                  {t('numberingExtractorFallbackCaptureGroup')}
                </HintLabel>
                <Input
                  id={`${idPrefix}-fallbackEpisodeCaptureGroup`}
                  type="number" className="w-24"
                  {...register(`${fieldPath}.fallbackEpisodeCaptureGroup` as any, {
                    setValueAs: (v) =>
                      v === '' || v === null || v === undefined
                        ? null
                        : Number(v),
                  })}
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <HintLabel
                htmlFor={`${idPrefix}-fallbackEpisodePattern`}
                hint="numberingExtractorFallbackPattern"
              >
                {t('numberingExtractorFallbackPattern')}
              </HintLabel>
              <Input
                id={`${idPrefix}-fallbackEpisodePattern`}
                {...register(`${fieldPath}.fallbackEpisodePattern` as any)}
                placeholder={t('placeholderRegex')}
              />
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
