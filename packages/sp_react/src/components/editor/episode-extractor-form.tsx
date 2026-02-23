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

interface EpisodeExtractorFormProps {
  index: number;
}

export function EpisodeExtractorForm({ index }: EpisodeExtractorFormProps) {
  const { register, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const extractor = watch(`playlists.${index}.smartPlaylistEpisodeExtractor`);
  const prefix = `playlists.${index}.smartPlaylistEpisodeExtractor` as const;

  if (!extractor) {
    return (
      <div className="space-y-2">
        <h4 className="text-sm font-medium">{t('episodeExtractor')}</h4>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() =>
            setValue(`playlists.${index}.smartPlaylistEpisodeExtractor`, {
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
        <HintLabel hint="episodeExtractor">{t('episodeExtractor')}</HintLabel>
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
                  `playlists.${index}.smartPlaylistEpisodeExtractor`,
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
                htmlFor={`ep-ext-${index}-source`}
                hint="episodeExtractorSource"
              >
                {t('episodeExtractorSource')}
              </HintLabel>
              <Select
                value={watch(`${prefix}.source`) ?? 'title'}
                onValueChange={(val) => setValue(`${prefix}.source`, val, { shouldDirty: true })}
              >
                <SelectTrigger id={`ep-ext-${index}-source`}>
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
                htmlFor={`ep-ext-${index}-pattern`}
                hint="episodeExtractorPattern"
              >
                {t('episodeExtractorPattern')}
              </HintLabel>
              <Input
                id={`ep-ext-${index}-pattern`}
                {...register(`${prefix}.pattern`)}
                placeholder={t('placeholderRegex')}
              />
            </div>

            <div className="space-y-1.5">
              <HintLabel
                htmlFor={`ep-ext-${index}-seasonGroup`}
                hint="episodeExtractorSeasonGroup"
              >
                {t('episodeExtractorSeasonGroup')}
              </HintLabel>
              <Input
                id={`ep-ext-${index}-seasonGroup`}
                type="number"
                {...register(`${prefix}.seasonGroup`, {
                  setValueAs: (v) =>
                    v === '' || v === null || v === undefined
                      ? null
                      : Number(v),
                })}
              />
            </div>

            <div className="space-y-1.5">
              <HintLabel
                htmlFor={`ep-ext-${index}-episodeGroup`}
                hint="episodeExtractorEpisodeGroup"
              >
                {t('episodeExtractorEpisodeGroup')}
              </HintLabel>
              <Input
                id={`ep-ext-${index}-episodeGroup`}
                type="number"
                {...register(`${prefix}.episodeGroup`, { valueAsNumber: true })}
              />
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Checkbox
              id={`ep-ext-${index}-fallbackToRss`}
              checked={watch(`${prefix}.fallbackToRss`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.fallbackToRss`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel
              htmlFor={`ep-ext-${index}-fallbackToRss`}
              hint="episodeExtractorFallbackToRss"
            >
              {t('episodeExtractorFallbackToRss')}
            </HintLabel>
          </div>

          <div className="space-y-3 border-t pt-3">
            <p className="text-xs text-muted-foreground font-medium">
              {t('episodeExtractorFallbackSeason')}
            </p>

            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <HintLabel
                  htmlFor={`ep-ext-${index}-fallbackSeasonNumber`}
                  hint="episodeExtractorFallbackSeason"
                >
                  {t('episodeExtractorFallbackSeason')}
                </HintLabel>
                <Input
                  id={`ep-ext-${index}-fallbackSeasonNumber`}
                  type="number"
                  {...register(`${prefix}.fallbackSeasonNumber`, {
                    setValueAs: (v) =>
                      v === '' || v === null || v === undefined
                        ? null
                        : Number(v),
                  })}
                />
              </div>

              <div className="space-y-1.5">
                <HintLabel
                  htmlFor={`ep-ext-${index}-fallbackEpisodeCaptureGroup`}
                  hint="episodeExtractorFallbackCaptureGroup"
                >
                  {t('episodeExtractorFallbackCaptureGroup')}
                </HintLabel>
                <Input
                  id={`ep-ext-${index}-fallbackEpisodeCaptureGroup`}
                  type="number"
                  {...register(`${prefix}.fallbackEpisodeCaptureGroup`, {
                    valueAsNumber: true,
                  })}
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <HintLabel
                htmlFor={`ep-ext-${index}-fallbackEpisodePattern`}
                hint="episodeExtractorFallbackPattern"
              >
                {t('episodeExtractorFallbackPattern')}
              </HintLabel>
              <Input
                id={`ep-ext-${index}-fallbackEpisodePattern`}
                {...register(`${prefix}.fallbackEpisodePattern`)}
                placeholder={t('placeholderRegex')}
              />
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
