import { useState } from 'react';
import { useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { Loader2, Trash2 } from 'lucide-react';
import { toast } from 'sonner';
import { useDeletePreset } from '@/api/queries.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { Button } from '@/components/ui/button.tsx';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card.tsx';
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

interface PresetDangerZoneProps {
  presetId: string;
  displayName: string | null;
}

export function PresetDangerZone({
  presetId,
  displayName,
}: PresetDangerZoneProps) {
  const { t } = useTranslation('editor');
  const navigate = useNavigate();
  const deletePresetMutation = useDeletePreset();
  const resetEditorStore = useEditorStore((s) => s.reset);
  const [confirmOpen, setConfirmOpen] = useState(false);

  const handleConfirmDelete = async () => {
    try {
      await deletePresetMutation.mutateAsync(presetId);
      setConfirmOpen(false);
      resetEditorStore();
      toast.success(
        t('toastPresetDeleted', {
          name: displayName ?? presetId,
          defaultValue: 'Deleted {{name}}',
        }),
      );
      void navigate({ to: '/browse' });
    } catch (error) {
      toast.error(
        t('toastPresetDeleteError', {
          error: error instanceof Error ? error.message : 'Delete failed',
          defaultValue: 'Delete failed: {{error}}',
        }),
      );
    }
  };

  const isDeleting = deletePresetMutation.isPending;

  return (
    <>
      <Card className="mt-6 border-destructive/40">
        <CardHeader>
          <CardTitle className="text-base text-destructive">
            {t('presetDangerZone', 'Delete entire preset')}
          </CardTitle>
        </CardHeader>
        <CardContent className="flex items-center justify-between gap-4">
          <p className="text-sm text-muted-foreground">
            {t(
              'presetDangerZoneHint',
              'Removes this pattern and all its playlists. This cannot be undone.',
            )}
          </p>
          <Button
            variant="destructive"
            size="sm"
            type="button"
            onClick={() => setConfirmOpen(true)}
            disabled={isDeleting}
            className="shrink-0"
          >
            {isDeleting ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <Trash2 className="mr-2 h-4 w-4" />
            )}
            {t('deletePreset', 'Delete preset')}
          </Button>
        </CardContent>
      </Card>

      <AlertDialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {t('deletePresetTitle', 'Delete this preset?')}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {t('deletePresetDescription', {
                name: displayName ?? presetId,
                defaultValue:
                  'This permanently removes {{name}} and all of its playlists. This cannot be undone.',
              })}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={isDeleting}>
              {t('cancel', 'Cancel')}
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={(event) => {
                event.preventDefault();
                void handleConfirmDelete();
              }}
              disabled={isDeleting}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {isDeleting ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : null}
              {t('deletePreset', 'Delete preset')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}
