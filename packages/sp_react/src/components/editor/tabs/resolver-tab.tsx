import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, Presentation, ResolverType } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { NumberingExtractorForm } from '@/components/editor/numbering-extractor-form.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';

const RESOLVER_TYPES = [
  'seasonNumber',
  'year',
  'titleDiscovery',
  'titleClassifier',
] as const;

const PRESENTATIONS = ['separate', 'combined'] as const;

interface ResolverTabProps {
  index: number;
}

export function ResolverTab({ index }: ResolverTabProps) {
  const prefix = `playlists.${index}` as const;
  const { register, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const resolverType = watch(`${prefix}.resolverType`);

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.resolver" />

      <div className="space-y-4">
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-resolverType`} hint="resolverType">
            {t('resolverType')}
          </HintLabel>
          <Select
            value={resolverType ?? ''}
            onValueChange={(val) => setValue(`${prefix}.resolverType`, val as ResolverType, { shouldDirty: true })}
          >
            <SelectTrigger id={`playlist-${index}-resolverType`}>
              <SelectValue placeholder={t('selectResolver')} />
            </SelectTrigger>
            <SelectContent className="min-w-[280px]">
              {RESOLVER_TYPES.map((type) => (
                <SelectItem
                  key={type}
                  value={type}
                  description={t(`resolverDesc_${type}`)}
                >
                  {t(`resolverLabel_${type}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <InteractionNote i18nKey="interactionNote.resolver.resolverStructure" />

        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-presentation`} hint="presentation">
            {t('presentation')}
          </HintLabel>
          <Select
            value={watch(`${prefix}.presentation`) ?? 'combined'}
            onValueChange={(val) => setValue(`${prefix}.presentation`, val as Presentation, { shouldDirty: true })}
          >
            <SelectTrigger id={`playlist-${index}-presentation`} className="w-full">
              <SelectValue placeholder={t('presentation_combined')} />
            </SelectTrigger>
            <SelectContent>
              {PRESENTATIONS.map((type) => (
                <SelectItem key={type} value={type}>
                  {t(`presentation_${type}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

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
