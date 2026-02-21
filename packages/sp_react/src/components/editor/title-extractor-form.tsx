import { useCallback, useMemo } from 'react';
import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { Trash2, Plus } from 'lucide-react';
import type { PatternConfig, TitleExtractor } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Card, CardContent } from '@/components/ui/card.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';

// -- Utility functions (exported for testing) --

export function flattenChain(
  extractor: TitleExtractor | null | undefined,
): TitleExtractor[] {
  if (!extractor) return [];
  const steps: TitleExtractor[] = [];
  let current: TitleExtractor | null | undefined = extractor;
  while (current) {
    steps.push({ ...current, fallback: undefined });
    current = current.fallback;
  }
  return steps;
}

export function nestChain(
  steps: TitleExtractor[],
  fallbackValue?: string | null,
): TitleExtractor | null {
  if (steps.length === 0) return null;
  let result: TitleExtractor | null = null;
  for (let i = steps.length - 1; 0 <= i; i--) {
    result = {
      ...steps[i],
      fallback: result,
      fallbackValue: i === 0 ? fallbackValue : undefined,
    };
  }
  return result;
}

const SOURCE_OPTIONS = [
  'title',
  'description',
  'seasonNumber',
  'episodeNumber',
] as const;

interface TitleExtractorFormProps {
  index: number;
}

export function TitleExtractorForm({ index }: TitleExtractorFormProps) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const resolverType = watch(`playlists.${index}.resolverType`);
  const extractor = watch(`playlists.${index}.titleExtractor`);
  const steps = useMemo(() => flattenChain(extractor), [extractor]);
  const fallbackValue = extractor?.fallbackValue ?? null;

  const applySteps = useCallback(
    (nextSteps: TitleExtractor[], nextFallbackValue?: string | null) => {
      setValue(
        `playlists.${index}.titleExtractor`,
        nestChain(nextSteps, nextFallbackValue ?? fallbackValue),
      );
    },
    [index, setValue, fallbackValue],
  );

  const handleAdd = useCallback(() => {
    const newStep: TitleExtractor = { source: 'title', group: 0 };
    applySteps([...steps, newStep], fallbackValue);
  }, [steps, applySteps, fallbackValue]);

  const handleRemove = useCallback(
    (stepIndex: number) => {
      if (stepIndex === 0 && steps.length === 1) {
        setValue(`playlists.${index}.titleExtractor`, null);
        return;
      }
      const nextSteps = steps.filter((_, i) => i !== stepIndex);
      applySteps(nextSteps, fallbackValue);
    },
    [steps, applySteps, fallbackValue, index, setValue],
  );

  const updateStep = useCallback(
    (stepIndex: number, patch: Partial<TitleExtractor>) => {
      const nextSteps = steps.map((step, i) =>
        i === stepIndex ? { ...step, ...patch } : step,
      );
      applySteps(nextSteps, fallbackValue);
    },
    [steps, applySteps, fallbackValue],
  );

  const handleFallbackValueChange = useCallback(
    (value: string) => {
      setValue(
        `playlists.${index}.titleExtractor`,
        nestChain(steps, value || null),
      );
    },
    [steps, index, setValue],
  );

  if (resolverType === 'category') {
    return (
      <div className="space-y-2">
        <h4 className="text-sm font-medium">{t('titleExtractor')}</h4>
        <p className="text-muted-foreground text-sm">
          {t('titleExtractorDisabledNote')}
        </p>
      </div>
    );
  }

  if (!extractor) {
    return (
      <div className="space-y-2">
        <h4 className="text-sm font-medium">{t('titleExtractor')}</h4>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() =>
            setValue(`playlists.${index}.titleExtractor`, {
              source: 'title',
              group: 0,
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
        <HintLabel hint="titleExtractor">{t('titleExtractor')}</HintLabel>
      </h4>

      {steps.map((step, stepIndex) => (
        <TitleExtractorStep
          key={stepIndex}
          step={step}
          stepIndex={stepIndex}
          playlistIndex={index}
          onUpdate={(patch) => updateStep(stepIndex, patch)}
          onRemove={() => handleRemove(stepIndex)}
        />
      ))}

      <div className="flex gap-2">
        <Button type="button" variant="outline" size="sm" onClick={handleAdd}>
          <Plus className="mr-2 h-4 w-4" />
          {t('addFallback')}
        </Button>
      </div>

      <div className="space-y-1.5">
        <HintLabel hint="titleExtractorFallbackValue">
          {t('titleExtractorFallbackValue')}
        </HintLabel>
        <Input
          value={fallbackValue ?? ''}
          onChange={(e) => handleFallbackValueChange(e.target.value)}
          placeholder=""
        />
      </div>
    </div>
  );
}

// -- Step sub-component --

interface TitleExtractorStepProps {
  step: TitleExtractor;
  stepIndex: number;
  playlistIndex: number;
  onUpdate: (patch: Partial<TitleExtractor>) => void;
  onRemove: () => void;
}

function TitleExtractorStep({
  step,
  stepIndex,
  playlistIndex,
  onUpdate,
  onRemove,
}: TitleExtractorStepProps) {
  const { t } = useTranslation('editor');

  const label =
    stepIndex === 0
      ? t('titleExtractor')
      : t('fallbackStep', { number: stepIndex });

  return (
    <Card className="py-4">
      <CardContent className="space-y-3 px-4">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium">{label}</span>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={onRemove}
          >
            <Trash2 className="h-4 w-4" />
            <span className="sr-only">{t('removeFallbackStep')}</span>
          </Button>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`title-ext-${playlistIndex}-${stepIndex}-source`}
              hint="titleExtractorSource"
            >
              {t('titleExtractorSource')}
            </HintLabel>
            <Select
              value={step.source}
              onValueChange={(val) => onUpdate({ source: val })}
            >
              <SelectTrigger id={`title-ext-${playlistIndex}-${stepIndex}-source`}>
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
              htmlFor={`title-ext-${playlistIndex}-${stepIndex}-group`}
              hint="titleExtractorGroup"
            >
              {t('titleExtractorGroup')}
            </HintLabel>
            <Input
              id={`title-ext-${playlistIndex}-${stepIndex}-group`}
              type="number"
              value={step.group ?? 0}
              onChange={(e) =>
                onUpdate({ group: parseInt(e.target.value, 10) || 0 })
              }
            />
          </div>
        </div>

        <div className="space-y-1.5">
          <HintLabel
            htmlFor={`title-ext-${playlistIndex}-${stepIndex}-pattern`}
            hint="titleExtractorPattern"
          >
            {t('titleExtractorPattern')}
          </HintLabel>
          <Input
            id={`title-ext-${playlistIndex}-${stepIndex}-pattern`}
            value={step.pattern ?? ''}
            onChange={(e) =>
              onUpdate({ pattern: e.target.value || null })
            }
            placeholder={t('placeholderRegex')}
          />
        </div>

        <div className="space-y-1.5">
          <HintLabel
            htmlFor={`title-ext-${playlistIndex}-${stepIndex}-template`}
            hint="titleExtractorTemplate"
          >
            {t('titleExtractorTemplate')}
          </HintLabel>
          <Input
            id={`title-ext-${playlistIndex}-${stepIndex}-template`}
            value={step.template ?? ''}
            onChange={(e) =>
              onUpdate({ template: e.target.value || null })
            }
            placeholder="{value}"
          />
        </div>
      </CardContent>
    </Card>
  );
}
