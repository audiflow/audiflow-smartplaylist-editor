import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { Plus, Trash2 } from 'lucide-react';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Card, CardContent } from '@/components/ui/card.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';

interface EpisodeNumberExtractorFormProps {
  index: number;
}

export function EpisodeNumberExtractorForm({
  index,
}: EpisodeNumberExtractorFormProps) {
  const { register, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const extractor = watch(`playlists.${index}.episodeNumberExtractor`);
  const prefix = `playlists.${index}.episodeNumberExtractor` as const;

  if (!extractor) {
    return (
      <div className="space-y-2">
        <h4 className="text-sm font-medium">{t('episodeNumberExtractor')}</h4>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() =>
            setValue(`playlists.${index}.episodeNumberExtractor`, {
              pattern: '',
              captureGroup: 1,
              fallbackToRss: true,
            })
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
        <HintLabel hint="episodeNumberExtractor">
          {t('episodeNumberExtractor')}
        </HintLabel>
      </h4>

      <Card className="py-4">
        <CardContent className="space-y-3 px-4">
          <div className="flex justify-end">
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={() =>
                setValue(`playlists.${index}.episodeNumberExtractor`, null)
              }
            >
              <Trash2 className="h-4 w-4" />
              <span className="sr-only">{t('removeFallbackStep')}</span>
            </Button>
          </div>

          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`ep-num-ext-${index}-pattern`}
              hint="episodeNumberPattern"
            >
              {t('episodeNumberPattern')}
            </HintLabel>
            <Input
              id={`ep-num-ext-${index}-pattern`}
              {...register(`${prefix}.pattern`)}
              placeholder={t('placeholderRegex')}
            />
          </div>

          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`ep-num-ext-${index}-captureGroup`}
              hint="episodeNumberCaptureGroup"
            >
              {t('episodeNumberCaptureGroup')}
            </HintLabel>
            <Input
              id={`ep-num-ext-${index}-captureGroup`}
              type="number"
              {...register(`${prefix}.captureGroup`, { valueAsNumber: true })}
            />
          </div>

          <div className="flex items-center gap-2">
            <Checkbox
              id={`ep-num-ext-${index}-fallbackToRss`}
              checked={watch(`${prefix}.fallbackToRss`) ?? true}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.fallbackToRss`, !!checked)
              }
            />
            <HintLabel
              htmlFor={`ep-num-ext-${index}-fallbackToRss`}
              hint="episodeNumberFallbackToRss"
            >
              {t('episodeNumberFallbackToRss')}
            </HintLabel>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
