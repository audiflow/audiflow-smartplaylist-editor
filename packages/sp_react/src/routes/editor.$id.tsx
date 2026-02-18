import { createFileRoute, redirect } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { Loader2 } from 'lucide-react';
import { useAuthStore } from '@/stores/auth-store.ts';
import { useAssembledConfig } from '@/api/queries.ts';
import { EditorLayout } from '@/components/editor/editor-layout.tsx';

export const Route = createFileRoute('/editor/$id')({
  beforeLoad: () => {
    if (!useAuthStore.getState().isAuthenticated) {
      throw redirect({ to: '/login' });
    }
  },
  component: EditorWithId,
});

function EditorWithId() {
  const { t } = useTranslation('feed');
  const { id } = Route.useParams();
  const { data: config, isLoading, error } = useAssembledConfig(id);

  if (isLoading) {
    return (
      <div className="flex justify-center py-12">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-12 text-destructive">
        {t('loadConfigFailed', { error: error.message })}
      </div>
    );
  }

  return <EditorLayout configId={id} initialConfig={config} />;
}
