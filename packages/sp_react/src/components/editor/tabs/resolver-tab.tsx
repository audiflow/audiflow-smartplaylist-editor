import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, ResolverType } from '@/schemas/config-schema.ts';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
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

export function ResolverTab({ index }: ResolverTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const resolverType = watch(`${prefix}.grouping.by`);

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
            onValueChange={(val) => setValue(`${prefix}.grouping.by`, val as ResolverType, { shouldDirty: true })}
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

        {resolverType === 'seasonNumber' && (
          <>
            <InteractionNote i18nKey="interactionNote.resolver.numberingExtractor" />
            <NumberingExtractorForm
              fieldPath={`playlists.${index}.grouping.numberingExtractor`}
              idPrefix={`ep-ext-${index}`}
            />
          </>
        )}
      </div>

      {(resolverType === 'seasonNumber' || resolverType === 'titleDiscovery' || resolverType === 'year') && (
        <>
          <InteractionNote i18nKey="interactionNote.resolver.titleExtractor" />
          <TitleExtractorForm
            fieldPath={`playlists.${index}.groupItem.titleExtractor`}
            idPrefix={`title-ext-${index}`}
            resolverType={resolverType}
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
