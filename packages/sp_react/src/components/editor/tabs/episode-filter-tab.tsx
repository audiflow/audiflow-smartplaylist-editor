import { useFieldArray, useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PresetConfig } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { Button } from '@/components/ui/button.tsx';
import { RegexTester } from '@/components/editor/regex-tester.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';
import { Plus, Trash2 } from 'lucide-react';
import { usePreviewHighlight } from '@/hooks/use-preview-highlight.ts';
import { PREVIEW_FIELDS } from '@/components/editor/preview/preview-field-ids.ts';

interface EpisodeFilterTabProps {
  index: number;
  episodeTitles: readonly string[];
}

export function EpisodeFilterTab({ index, episodeTitles }: EpisodeFilterTabProps) {
  const { register, watch, control } = useFormContext<PresetConfig>();
  const { t } = useTranslation('editor');
  const requireHl = usePreviewHighlight(PREVIEW_FIELDS.filtersRequire);
  const excludeHl = usePreviewHighlight(PREVIEW_FIELDS.filtersExclude);

  const { fields: requireFields, append: appendRequire, remove: removeRequire } = useFieldArray({
    control,
    name: `playlists.${index}.episodeFilters.require` as `playlists.${number}.episodeFilters.require`,
  });

  const { fields: excludeFields, append: appendExclude, remove: removeExclude } = useFieldArray({
    control,
    name: `playlists.${index}.episodeFilters.exclude` as `playlists.${number}.episodeFilters.exclude`,
  });

  return (
    <div className="space-y-3">
      <SectionNote i18nKey="sectionNote.episodeFilters" />

      <div className="rounded-lg border border-border p-4 space-y-3">
        <h5 className="text-xs font-medium text-muted-foreground">{t('requireFilters')}</h5>
        {requireFields.map((field, filterIndex) => {
          const titleValue = watch(`playlists.${index}.episodeFilters.require.${filterIndex}.title`) ?? '';
          return (
            <div key={field.id} className="rounded-lg border border-border p-3">
              <div className="flex items-start gap-2">
                <div className="flex-1 grid grid-cols-2 gap-3">
                  <div className="space-y-1.5">
                    <HintLabel hint="filterTitle">{t('filterTitle')}</HintLabel>
                    <Input
                      {...register(`playlists.${index}.episodeFilters.require.${filterIndex}.title`)}
                      {...requireHl}
                      placeholder={t('placeholderRegex')}
                    />
                    {titleValue && <RegexTester pattern={titleValue} variant="include" titles={episodeTitles} />}
                  </div>
                  <div className="space-y-1.5">
                    <HintLabel hint="filterDescription">{t('filterDescription')}</HintLabel>
                    <Input
                      {...register(`playlists.${index}.episodeFilters.require.${filterIndex}.description`)}
                      placeholder={t('placeholderRegex')}
                    />
                  </div>
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="mt-5"
                  onClick={() => removeRequire(filterIndex)}
                >
                  <Trash2 className="h-4 w-4" />
                  <span className="sr-only">{t('removeFilter')}</span>
                </Button>
              </div>
            </div>
          );
        })}
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => appendRequire({ title: '' })}
        >
          <Plus className="mr-2 h-4 w-4" />
          {t('addFilter')}
        </Button>
      </div>

      <InteractionNote i18nKey="interactionNote.episodeFilters.requireExclude" />

      <div className="rounded-lg border border-border p-4 space-y-3">
        <h5 className="text-xs font-medium text-muted-foreground">{t('excludeFilters')}</h5>
        {excludeFields.map((field, filterIndex) => {
          const titleValue = watch(`playlists.${index}.episodeFilters.exclude.${filterIndex}.title`) ?? '';
          return (
            <div key={field.id} className="rounded-lg border border-border p-3">
              <div className="flex items-start gap-2">
                <div className="flex-1 grid grid-cols-2 gap-3">
                  <div className="space-y-1.5">
                    <HintLabel hint="filterTitle">{t('filterTitle')}</HintLabel>
                    <Input
                      {...register(`playlists.${index}.episodeFilters.exclude.${filterIndex}.title`)}
                      {...excludeHl}
                      placeholder={t('placeholderRegex')}
                    />
                    {titleValue && <RegexTester pattern={titleValue} variant="exclude" titles={episodeTitles} />}
                  </div>
                  <div className="space-y-1.5">
                    <HintLabel hint="filterDescription">{t('filterDescription')}</HintLabel>
                    <Input
                      {...register(`playlists.${index}.episodeFilters.exclude.${filterIndex}.description`)}
                      placeholder={t('placeholderRegex')}
                    />
                  </div>
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="mt-5"
                  onClick={() => removeExclude(filterIndex)}
                >
                  <Trash2 className="h-4 w-4" />
                  <span className="sr-only">{t('removeFilter')}</span>
                </Button>
              </div>
            </div>
          );
        })}
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => appendExclude({ title: '' })}
        >
          <Plus className="mr-2 h-4 w-4" />
          {t('addFilter')}
        </Button>
      </div>
    </div>
  );
}
