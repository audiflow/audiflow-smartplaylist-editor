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

function formatSavedAt(isoTimestamp: string): string {
  const date = new Date(isoTimestamp);
  if (isNaN(date.getTime())) return 'unknown time';
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
  return (
    <AlertDialog open>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Draft Found</AlertDialogTitle>
          <AlertDialogDescription>
            A saved draft was found from {formatSavedAt(savedAt)}. Would you
            like to restore it or discard it?
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel variant="destructive" onClick={onDiscard}>
            Discard
          </AlertDialogCancel>
          <AlertDialogAction onClick={onRestore}>Restore</AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
