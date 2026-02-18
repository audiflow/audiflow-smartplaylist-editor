import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { Loader2 } from 'lucide-react';
import { useSubmitPr } from '@/api/queries.ts';
import { Button } from '@/components/ui/button.tsx';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog.tsx';

interface SubmitDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  patternId: string;
  playlist: unknown;
  patternMeta?: unknown;
  isNewPattern?: boolean;
}

export function SubmitDialog({
  open,
  onOpenChange,
  patternId,
  playlist,
  patternMeta,
  isNewPattern,
}: SubmitDialogProps) {
  const { t } = useTranslation('editor');
  const submitPr = useSubmitPr();

  const handleSubmit = () => {
    submitPr.mutate({ patternId, playlist, patternMeta, isNewPattern });
  };

  // Reset mutation state when dialog closes
  useEffect(() => {
    if (!open) submitPr.reset();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('submitTitle')}</DialogTitle>
          <DialogDescription>
            {t('submitDescription')}
          </DialogDescription>
        </DialogHeader>
        {renderBody(submitPr, patternId, handleSubmit, onOpenChange)}
      </DialogContent>
    </Dialog>
  );
}

type SubmitMutation = ReturnType<typeof useSubmitPr>;

function renderBody(
  submitPr: SubmitMutation,
  patternId: string,
  onSubmit: () => void,
  onOpenChange: (open: boolean) => void,
) {
  switch (submitPr.status) {
    case 'idle':
      return <ConfirmContent patternId={patternId} onSubmit={onSubmit} onCancel={() => onOpenChange(false)} />;
    case 'pending':
      return <PendingContent />;
    case 'success':
      return <SuccessContent prUrl={submitPr.data?.prUrl} />;
    case 'error':
      return <ErrorContent message={submitPr.error?.message} onRetry={onSubmit} />;
  }
}

function ConfirmContent({
  patternId,
  onSubmit,
  onCancel,
}: {
  patternId: string;
  onSubmit: () => void;
  onCancel: () => void;
}) {
  const { t } = useTranslation('editor');
  const { t: tCommon } = useTranslation('common');

  return (
    <div className="space-y-4">
      <p className="text-sm text-muted-foreground">
        {t('submitPattern', { patternId })}
      </p>
      <DialogFooter>
        <Button variant="outline" onClick={onCancel}>
          {tCommon('cancel')}
        </Button>
        <Button onClick={onSubmit}>{t('submitPr')}</Button>
      </DialogFooter>
    </div>
  );
}

function PendingContent() {
  const { t } = useTranslation('editor');

  return (
    <div className="flex flex-col items-center py-8 gap-4">
      <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      <p className="text-sm text-muted-foreground">{t('submitting')}</p>
    </div>
  );
}

function SuccessContent({ prUrl }: { prUrl: string | undefined }) {
  const { t } = useTranslation('editor');

  const handleOpen = () => {
    if (prUrl) window.open(prUrl, '_blank');
  };

  return (
    <div className="flex flex-col items-center py-4 gap-4">
      <p className="text-sm font-medium">{t('submitSuccess')}</p>
      {prUrl && (
        <p className="text-xs text-muted-foreground font-mono break-all text-center">
          {prUrl}
        </p>
      )}
      <Button onClick={handleOpen}>{t('openPr')}</Button>
    </div>
  );
}

function ErrorContent({
  message,
  onRetry,
}: {
  message: string | undefined;
  onRetry: () => void;
}) {
  const { t } = useTranslation('editor');
  const { t: tCommon } = useTranslation('common');

  return (
    <div className="flex flex-col items-center py-4 gap-4">
      <p className="text-sm text-destructive">
        {t('submitFailed', { error: message ?? 'Unknown error' })}
      </p>
      <Button variant="outline" onClick={onRetry}>
        {tCommon('retry')}
      </Button>
    </div>
  );
}
