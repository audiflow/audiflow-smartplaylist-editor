import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { NumberingExtractorForm } from '@/components/editor/numbering-extractor-form.tsx';

interface ExtractorsFormProps {
  index: number;
}

export function ExtractorsForm({ index }: ExtractorsFormProps) {
  const { watch } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-6">
      <h3 className="text-sm font-semibold">{t('extractorsSection')}</h3>
      <TitleExtractorForm
        fieldPath={`playlists.${index}.titleExtractor`}
        idPrefix={`title-ext-${index}`}
        resolverType={watch(`playlists.${index}.resolverType`) ?? undefined}
        showCategoryNote
      />
      <NumberingExtractorForm
        fieldPath={`playlists.${index}.numberingExtractor`}
        idPrefix={`ep-ext-${index}`}
      />
    </div>
  );
}
