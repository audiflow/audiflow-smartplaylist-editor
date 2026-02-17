import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import { useApiKeys, useGenerateKey, useRevokeKey } from '@/api/queries.ts';
import type { ApiKey } from '@/schemas/api-schema.ts';
import { Button } from '@/components/ui/button.tsx';
import { Input } from '@/components/ui/input.tsx';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card.tsx';
import { Separator } from '@/components/ui/separator.tsx';
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
import { Copy, Key, Loader2, Plus, Trash2 } from 'lucide-react';

export function ApiKeyManager() {
  const { t } = useTranslation('settings');
  const { t: tCommon } = useTranslation('common');
  const { data: keysData, isLoading } = useApiKeys();
  const generateKey = useGenerateKey();
  const revokeKey = useRevokeKey();

  const [keyName, setKeyName] = useState('');
  const [generatedKey, setGeneratedKey] = useState<string | null>(null);
  const [revokeTarget, setRevokeTarget] = useState<string | null>(null);

  const keys = keysData?.keys ?? [];

  const handleGenerate = async () => {
    const trimmed = keyName.trim();
    if (!trimmed) return;

    try {
      const result = await generateKey.mutateAsync({ name: trimmed });
      setGeneratedKey(result.key);
      setKeyName('');
      toast.success(t('toastKeyGenerated'));
    } catch {
      toast.error(t('toastKeyGenerateFailed'));
    }
  };

  const handleRevoke = async () => {
    if (!revokeTarget) return;

    try {
      await revokeKey.mutateAsync(revokeTarget);
      setRevokeTarget(null);
      toast.success(t('toastKeyRevoked'));
    } catch {
      toast.error(t('toastKeyRevokeFailed'));
    }
  };

  const handleCopy = async () => {
    if (!generatedKey) return;

    try {
      await navigator.clipboard.writeText(generatedKey);
      toast.success(t('toastCopied'));
    } catch {
      toast.error(t('toastCopyFailed'));
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Key className="h-5 w-5" />
          {t('apiKeys')}
        </CardTitle>
        <CardDescription>
          {t('apiKeysDescription')}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        <GenerateForm
          keyName={keyName}
          onKeyNameChange={setKeyName}
          onGenerate={() => void handleGenerate()}
          isPending={generateKey.isPending}
        />

        {generatedKey && (
          <GeneratedKeyBanner
            generatedKey={generatedKey}
            onCopy={() => void handleCopy()}
            onDismiss={() => setGeneratedKey(null)}
          />
        )}

        <Separator />

        <KeyList
          keys={keys}
          isLoading={isLoading}
          isRevoking={revokeKey.isPending}
          revokingId={revokeTarget}
          onRevoke={setRevokeTarget}
        />

        <RevokeDialog
          isOpen={revokeTarget !== null}
          onOpenChange={(open) => {
            if (!open) setRevokeTarget(null);
          }}
          onConfirm={() => void handleRevoke()}
          isPending={revokeKey.isPending}
        />
      </CardContent>
    </Card>
  );
}

function GenerateForm({
  keyName,
  onKeyNameChange,
  onGenerate,
  isPending,
}: {
  keyName: string;
  onKeyNameChange: (value: string) => void;
  onGenerate: () => void;
  isPending: boolean;
}) {
  const { t } = useTranslation('settings');
  const { t: tCommon } = useTranslation('common');

  return (
    <div className="flex gap-2">
      <Input
        placeholder={t('keyNamePlaceholder')}
        value={keyName}
        onChange={(e) => onKeyNameChange(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === 'Enter') onGenerate();
        }}
        disabled={isPending}
      />
      <Button
        onClick={onGenerate}
        disabled={!keyName.trim() || isPending}
        className="shrink-0"
      >
        {isPending ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : (
          <Plus className="h-4 w-4" />
        )}
        {tCommon('generate')}
      </Button>
    </div>
  );
}

function GeneratedKeyBanner({
  generatedKey,
  onCopy,
  onDismiss,
}: {
  generatedKey: string;
  onCopy: () => void;
  onDismiss: () => void;
}) {
  const { t } = useTranslation('settings');
  const { t: tCommon } = useTranslation('common');

  return (
    <div className="rounded-md border border-green-200 bg-green-50 p-4 dark:border-green-900 dark:bg-green-950">
      <p className="mb-2 text-sm font-medium text-green-800 dark:text-green-200">
        {t('saveKeyWarning')}
      </p>
      <div className="flex items-center gap-2">
        <code className="flex-1 rounded bg-green-100 px-3 py-2 font-mono text-sm break-all dark:bg-green-900">
          {generatedKey}
        </code>
        <Button variant="outline" size="icon" onClick={onCopy}>
          <Copy className="h-4 w-4" />
        </Button>
        <Button variant="ghost" size="sm" onClick={onDismiss}>
          {tCommon('dismiss')}
        </Button>
      </div>
    </div>
  );
}

function KeyList({
  keys,
  isLoading,
  isRevoking,
  revokingId,
  onRevoke,
}: {
  keys: ApiKey[];
  isLoading: boolean;
  isRevoking: boolean;
  revokingId: string | null;
  onRevoke: (id: string) => void;
}) {
  const { t } = useTranslation('settings');

  if (isLoading) {
    return (
      <div className="flex justify-center py-8">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (keys.length === 0) {
    return (
      <div className="py-8 text-center text-sm text-muted-foreground">
        {t('noKeysYet')}
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <h3 className="text-sm font-medium">{t('existingKeys')}</h3>
      {keys.map((apiKey) => (
        <KeyRow
          key={apiKey.id}
          apiKey={apiKey}
          isRevoking={isRevoking && revokingId === apiKey.id}
          onRevoke={() => onRevoke(apiKey.id)}
        />
      ))}
    </div>
  );
}

function KeyRow({
  apiKey,
  isRevoking,
  onRevoke,
}: {
  apiKey: ApiKey;
  isRevoking: boolean;
  onRevoke: () => void;
}) {
  const { t } = useTranslation('settings');
  const createdDate = formatDate(apiKey.createdAt);

  return (
    <div className="flex items-center justify-between rounded-md border px-4 py-3">
      <div className="min-w-0 flex-1 space-y-1">
        <p className="text-sm font-medium">{apiKey.name}</p>
        <div className="flex items-center gap-3 text-xs text-muted-foreground">
          <code className="font-mono">{apiKey.maskedKey}</code>
          <span>{t('createdAt', { date: createdDate })}</span>
        </div>
      </div>
      <Button
        variant="ghost"
        size="icon"
        className="text-destructive hover:text-destructive shrink-0"
        onClick={onRevoke}
        disabled={isRevoking}
      >
        {isRevoking ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : (
          <Trash2 className="h-4 w-4" />
        )}
      </Button>
    </div>
  );
}

function RevokeDialog({
  isOpen,
  onOpenChange,
  onConfirm,
  isPending,
}: {
  isOpen: boolean;
  onOpenChange: (open: boolean) => void;
  onConfirm: () => void;
  isPending: boolean;
}) {
  const { t } = useTranslation('settings');
  const { t: tCommon } = useTranslation('common');

  return (
    <AlertDialog open={isOpen} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{t('revokeTitle')}</AlertDialogTitle>
          <AlertDialogDescription>
            {t('revokeDescription')}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel disabled={isPending}>{tCommon('cancel')}</AlertDialogCancel>
          <AlertDialogAction
            variant="destructive"
            onClick={onConfirm}
            disabled={isPending}
          >
            {isPending && <Loader2 className="h-4 w-4 animate-spin" />}
            {tCommon('revoke')}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}

function formatDate(isoString: string): string {
  try {
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    }).format(new Date(isoString));
  } catch {
    return isoString;
  }
}
