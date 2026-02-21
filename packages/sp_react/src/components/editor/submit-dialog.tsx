import { useEffect, useMemo } from 'react';
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
import { useEditorStore } from '@/stores/editor-store.ts';

interface SubmitDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  config: Record<string, unknown>;
  configId: string | null;
}

/**
 * Extracts the submit payload from the full PatternConfig.
 * The server expects `patternId`, `playlists` (array), and optional
 * `patternMeta` (feedUrls, podcastGuid, yearGroupedEpisodes).
 */
function buildSubmitPayload(
  config: Record<string, unknown>,
  configId: string | null,
) {
  const patternId = (config.id as string) || configId || '';
  const playlists = (config.playlists as unknown[]) ?? [];

  const patternMeta: Record<string, unknown> = {};
  if (config.podcastGuid != null) patternMeta.podcastGuid = config.podcastGuid;
  if (config.feedUrls != null) patternMeta.feedUrls = config.feedUrls;
  if (config.yearGroupedEpisodes != null) {
    patternMeta.yearGroupedEpisodes = config.yearGroupedEpisodes;
  }

  return { patternId, playlists, patternMeta };
}

export function SubmitDialog({
  open,
  onOpenChange,
  config,
  configId,
}: SubmitDialogProps) {
  const { t } = useTranslation('editor');
  const submitPr = useSubmitPr();
  const lastSubmittedBranch = useEditorStore((s) => s.lastSubmittedBranch);
  const lastPrUrl = useEditorStore((s) => s.lastPrUrl);
  const setLastSubmission = useEditorStore((s) => s.setLastSubmission);

  const payload = useMemo(
    () => buildSubmitPayload(config, configId),
    [config, configId],
  );

  const handleCreateNew = () => {
    submitPr.mutate(payload);
  };

  const handleUpdateExisting = () => {
    if (lastSubmittedBranch) {
      submitPr.mutate({ ...payload, branch: lastSubmittedBranch });
    }
  };

  // Store submission result on success
  useEffect(() => {
    if (submitPr.status === 'success' && submitPr.data) {
      const { branch, prUrl } = submitPr.data;
      setLastSubmission(branch, prUrl ?? lastPrUrl);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [submitPr.status, submitPr.data]);

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
        {renderBody(
          submitPr,
          payload.patternId,
          lastSubmittedBranch,
          lastPrUrl,
          handleCreateNew,
          handleUpdateExisting,
          onOpenChange,
        )}
      </DialogContent>
    </Dialog>
  );
}

type SubmitMutation = ReturnType<typeof useSubmitPr>;

function renderBody(
  submitPr: SubmitMutation,
  patternId: string,
  lastBranch: string | null,
  lastPrUrl: string | null,
  onCreateNew: () => void,
  onUpdateExisting: () => void,
  onOpenChange: (open: boolean) => void,
) {
  switch (submitPr.status) {
    case 'idle':
      return (
        <ConfirmContent
          patternId={patternId}
          hasExistingPr={lastBranch != null}
          onCreateNew={onCreateNew}
          onUpdateExisting={onUpdateExisting}
          onCancel={() => onOpenChange(false)}
        />
      );
    case 'pending':
      return <PendingContent />;
    case 'success':
      return (
        <SuccessContent
          prUrl={submitPr.data?.prUrl ?? lastPrUrl}
          isUpdate={submitPr.data?.prUrl == null}
        />
      );
    case 'error':
      return <ErrorContent message={submitPr.error?.message} onRetry={onCreateNew} />;
  }
}

function ConfirmContent({
  patternId,
  hasExistingPr,
  onCreateNew,
  onUpdateExisting,
  onCancel,
}: {
  patternId: string;
  hasExistingPr: boolean;
  onCreateNew: () => void;
  onUpdateExisting: () => void;
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
        {hasExistingPr ? (
          <>
            <Button variant="outline" onClick={onCreateNew}>
              {t('createNewPr')}
            </Button>
            <Button onClick={onUpdateExisting}>
              {t('updatePr')}
            </Button>
          </>
        ) : (
          <Button onClick={onCreateNew}>{t('submitPr')}</Button>
        )}
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

function SuccessContent({
  prUrl,
  isUpdate,
}: {
  prUrl: string | undefined | null;
  isUpdate: boolean;
}) {
  const { t } = useTranslation('editor');

  const handleOpen = () => {
    if (prUrl) window.open(prUrl, '_blank');
  };

  return (
    <div className="flex flex-col items-center py-4 gap-4">
      <p className="text-sm font-medium">
        {isUpdate ? t('updatePrSuccess') : t('submitSuccess')}
      </p>
      {prUrl && (
        <p className="text-xs text-muted-foreground font-mono break-all text-center">
          {prUrl}
        </p>
      )}
      {prUrl && <Button onClick={handleOpen}>{t('openPr')}</Button>}
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
