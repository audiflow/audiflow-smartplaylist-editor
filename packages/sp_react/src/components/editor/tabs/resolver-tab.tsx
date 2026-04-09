import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, Presentation, ResolverType } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { NumberingExtractorForm } from '@/components/editor/numbering-extractor-form.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';
import { cn } from '@/lib/utils.ts';

const RESOLVER_TYPES = [
  'seasonNumber',
  'year',
  'titleDiscovery',
  'titleClassifier',
] as const;

interface ResolverTabProps {
  index: number;
  playlistCount: number;
}

export function ResolverTab({ index, playlistCount }: ResolverTabProps) {
  const prefix = `playlists.${index}` as const;
  const { register, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const resolverType = watch(`${prefix}.resolverType`);
  const presentation = watch(`${prefix}.presentation`) ?? 'combined';
  const isSeparateDisabled = 1 < playlistCount;

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.resolver" />

      <div className="space-y-4">
        <div className="space-y-2">
          <HintLabel hint="resolverType">
            {t('resolverType')}
          </HintLabel>
          <div className="grid gap-2">
            {RESOLVER_TYPES.map((type) => (
              <button
                key={type}
                type="button"
                onClick={() => setValue(`${prefix}.resolverType`, type as ResolverType, { shouldDirty: true })}
                className={cn(
                  'flex items-start gap-3 rounded-lg border p-3 text-left transition-colors',
                  resolverType === type
                    ? 'border-primary bg-primary/5'
                    : 'border-border hover:border-muted-foreground/50',
                )}
              >
                <div
                  className={cn(
                    'mt-0.5 h-4 w-4 shrink-0 rounded-full border-2',
                    resolverType === type ? 'border-primary bg-primary' : 'border-muted-foreground/40',
                  )}
                >
                  {resolverType === type && (
                    <div className="flex h-full w-full items-center justify-center">
                      <div className="h-1.5 w-1.5 rounded-full bg-primary-foreground" />
                    </div>
                  )}
                </div>
                <div>
                  <p className="text-sm font-medium">{t(`resolverLabel_${type}`)}</p>
                  <p className="text-xs text-muted-foreground mt-0.5">{t(`resolverDesc_${type}`)}</p>
                </div>
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-2">
          <HintLabel hint="presentation">
            {t('presentation')}
          </HintLabel>
          <div className="grid gap-2">
            <PresentationOption
              selected={presentation === 'combined'}
              label={t('presentationLabel_combined')}
              description={t('presentationDesc_combined')}
              onSelect={() => setValue(`${prefix}.presentation`, 'combined' as Presentation, { shouldDirty: true })}
            />
            <PresentationOption
              selected={presentation === 'separate'}
              disabled={isSeparateDisabled}
              label={t('presentationLabel_separate')}
              description={isSeparateDisabled ? t('presentationDesc_separate_disabled') : t('presentationDesc_separate')}
              onSelect={() => setValue(`${prefix}.presentation`, 'separate' as Presentation, { shouldDirty: true })}
            />
          </div>
        </div>

        <InteractionNote i18nKey="interactionNote.resolver.resolverStructure" />

        {resolverType === 'seasonNumber' && (
          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`playlist-${index}-nullSeasonGroupKey`}
              hint="nullSeasonGroupKey"
            >
              {t('nullSeasonGroupKey')}
            </HintLabel>
            <Input
              id={`playlist-${index}-nullSeasonGroupKey`}
              type="number"
              {...register(`${prefix}.nullSeasonGroupKey`, {
                setValueAs: (v) =>
                  v === '' || v === null || v === undefined
                    ? null
                    : Number(v),
              })}
            />
          </div>
        )}
      </div>

      <InteractionNote i18nKey="interactionNote.resolver.titleExtractor" />

      <TitleExtractorForm
        fieldPath={`playlists.${index}.titleExtractor`}
        idPrefix={`title-ext-${index}`}
        resolverType={resolverType}
        showCategoryNote
      />

      {resolverType === 'seasonNumber' && (
        <>
          <InteractionNote i18nKey="interactionNote.resolver.numberingExtractor" />
          <NumberingExtractorForm
            fieldPath={`playlists.${index}.numberingExtractor`}
            idPrefix={`ep-ext-${index}`}
          />
        </>
      )}
    </div>
  );
}

function PresentationOption({
  selected,
  disabled,
  label,
  description,
  onSelect,
}: {
  selected: boolean;
  disabled?: boolean;
  label: string;
  description: string;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onSelect}
      className={cn(
        'flex items-start gap-3 rounded-lg border p-3 text-left transition-colors',
        selected && 'border-primary bg-primary/5',
        !selected && !disabled && 'border-border hover:border-muted-foreground/50',
        disabled && 'cursor-not-allowed opacity-50',
      )}
    >
      <div
        className={cn(
          'mt-0.5 h-4 w-4 shrink-0 rounded-full border-2',
          selected ? 'border-primary bg-primary' : 'border-muted-foreground/40',
        )}
      >
        {selected && (
          <div className="flex h-full w-full items-center justify-center">
            <div className="h-1.5 w-1.5 rounded-full bg-primary-foreground" />
          </div>
        )}
      </div>
      <div>
        <p className="text-sm font-medium">{label}</p>
        <p className="text-xs text-muted-foreground mt-0.5">{description}</p>
      </div>
    </button>
  );
}
