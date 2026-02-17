import { useTranslation } from 'react-i18next';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog.tsx';

interface DraftRestoreDialogProps {
  savedAt: string;
  onRestore: () => void;
  onDiscard: () => void;
}

function formatSavedAt(isoTimestamp: string, fallback: string): string {
  const date = new Date(isoTimestamp);
  if (isNaN(date.getTime())) return fallback;
  return date.toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

export function DraftRestoreDialog({
  savedAt,
  onRestore,
  onDiscard,
}: DraftRestoreDialogProps) {
  const { t } = useTranslation('editor');

  return (
    <AlertDialog open>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{t('draftFound')}</AlertDialogTitle>
          <AlertDialogDescription>
            {t('draftDescription', { savedAt: formatSavedAt(savedAt, t('draftUnknownTime')) })}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel variant="destructive" onClick={onDiscard}>
            {t('draftDiscard')}
          </AlertDialogCancel>
          <AlertDialogAction onClick={onRestore}>{t('draftRestore')}</AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
