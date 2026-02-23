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

interface ConflictDialogProps {
  open: boolean;
  filePath: string | null;
  onReload: () => void;
  onKeepChanges: () => void;
}

export function ConflictDialog({
  open,
  filePath,
  onReload,
  onKeepChanges,
}: ConflictDialogProps) {
  const { t } = useTranslation('editor');

  return (
    <AlertDialog open={open}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>
            {t('conflictTitle', 'File changed externally')}
          </AlertDialogTitle>
          <AlertDialogDescription>
            {t('conflictDescription', {
              path: filePath,
              defaultValue:
                '{{path}} was modified outside the editor. You have unsaved changes.',
            })}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel onClick={onKeepChanges}>
            {t('keepChanges', 'Keep my changes')}
          </AlertDialogCancel>
          <AlertDialogAction onClick={onReload}>
            {t('reloadFromDisk', 'Reload from disk')}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
