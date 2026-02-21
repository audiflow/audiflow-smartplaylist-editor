import { useTranslation } from 'react-i18next';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { EpisodeNumberExtractorForm } from '@/components/editor/episode-number-extractor-form.tsx';
import { EpisodeExtractorForm } from '@/components/editor/episode-extractor-form.tsx';

interface ExtractorsFormProps {
  index: number;
}

export function ExtractorsForm({ index }: ExtractorsFormProps) {
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-6">
      <h3 className="text-sm font-semibold">{t('extractorsSection')}</h3>
      <TitleExtractorForm index={index} />
      <EpisodeNumberExtractorForm index={index} />
      <EpisodeExtractorForm index={index} />
    </div>
  );
}
