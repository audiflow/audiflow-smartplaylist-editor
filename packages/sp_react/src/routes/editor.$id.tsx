import { createFileRoute, redirect } from '@tanstack/react-router';
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
        Failed to load config: {error.message}
      </div>
    );
  }

  return <EditorLayout configId={id} initialConfig={config} />;
}
