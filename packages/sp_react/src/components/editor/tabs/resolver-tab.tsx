import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, Presentation, ResolverType } from '@/schemas/config-schema.ts';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { NumberingExtractorForm } from '@/components/editor/numbering-extractor-form.tsx';
import { GroupsForm } from '@/components/editor/groups-form.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';

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
  const { watch, setValue, register } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const resolverType = watch(`${prefix}.resolverType`);
  const presentation = watch(`${prefix}.presentation`) ?? 'combined';
  const isSeparateDisabled = 1 < playlistCount;

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.resolver" />

      <div className="space-y-4">
        <div className="space-y-2">
          <HintLabel htmlFor={`playlist-${index}-resolverType`} hint="resolverType">
            {t('resolverType')}
          </HintLabel>
          <Select
            value={resolverType ?? ''}
            onValueChange={(val) => setValue(`${prefix}.resolverType`, val as ResolverType, { shouldDirty: true })}
          >
            <SelectTrigger id={`playlist-${index}-resolverType`} className="w-full">
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
            value={presentation}
            onValueChange={(val) => setValue(`${prefix}.presentation`, val as Presentation, { shouldDirty: true })}
          >
            <SelectTrigger id={`playlist-${index}-presentation`} className="w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="combined">
                {t('presentationLabel_combined')}
              </SelectItem>
              <SelectItem value="separate" disabled={isSeparateDisabled}>
                {t('presentationLabel_separate')}
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        {resolverType === 'seasonNumber' && (
          <>
            <div className="space-y-2">
              <HintLabel htmlFor={`playlist-${index}-nullSeasonGroupKey`} hint="nullSeasonGroupKey">
                {t('nullSeasonGroupKey')}
              </HintLabel>
              <Input
                id={`playlist-${index}-nullSeasonGroupKey`}
                type="number" className="w-24"
                {...register(`playlists.${index}.nullSeasonGroupKey`, {
                  setValueAs: (v: string | null | undefined) =>
                    v === '' || v === null || v === undefined
                      ? null
                      : Number(v),
                })}
              />
            </div>
            <InteractionNote i18nKey="interactionNote.resolver.numberingExtractor" />
            <NumberingExtractorForm
              fieldPath={`playlists.${index}.numberingExtractor`}
              idPrefix={`ep-ext-${index}`}
            />
          </>
        )}
      </div>

      {(resolverType === 'seasonNumber' || resolverType === 'titleDiscovery' || resolverType === 'year') && (
        <>
          <InteractionNote i18nKey="interactionNote.resolver.titleExtractor" />
          <TitleExtractorForm
            fieldPath={`playlists.${index}.titleExtractor`}
            idPrefix={`title-ext-${index}`}
            resolverType={resolverType}
          />

          <InteractionNote i18nKey="interactionNote.episodeList.titleExtractorChain" />
          <TitleExtractorForm
            fieldPath={`playlists.${index}.episodeList.titleExtractor`}
            idPrefix={`ep-list-title-ext-${index}`}
          />
        </>
      )}

      {resolverType === 'titleClassifier' && (
        <>
          <hr className="border-border" />
          <SectionNote i18nKey="sectionNote.groups" />
          <GroupsForm index={index} />
        </>
      )}
    </div>
  );
}
