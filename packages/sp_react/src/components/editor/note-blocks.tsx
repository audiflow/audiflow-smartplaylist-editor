import { useTranslation } from 'react-i18next';

interface NoteProps {
  i18nKey: string;
}

export function SectionNote({ i18nKey }: NoteProps) {
  const { t } = useTranslation('notes');
  const { t: tc } = useTranslation('common');

  return (
    <div className="bg-blue-950/30 border-l-[3px] border-blue-500 rounded-r-md px-4 py-3 mb-4">
      <p className="text-[11px] font-semibold uppercase text-blue-400 mb-1">
        {tc('noteLabel.section')}
      </p>
      <p className="text-sm text-muted-foreground leading-relaxed whitespace-pre-line">
        {t(i18nKey)}
      </p>
    </div>
  );
}

export function InteractionNote({ i18nKey }: NoteProps) {
  const { t } = useTranslation('notes');
  const { t: tc } = useTranslation('common');

  return (
    <div className="bg-amber-950/20 border-l-[3px] border-amber-500 rounded-r-md px-4 py-3 my-3">
      <p className="text-[11px] font-semibold uppercase text-amber-400 mb-1">
        {tc('noteLabel.interaction')}
      </p>
      <p className="text-sm text-muted-foreground leading-relaxed whitespace-pre-line">
        {t(i18nKey)}
      </p>
    </div>
  );
}
