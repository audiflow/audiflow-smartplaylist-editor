import { createFileRoute, redirect } from '@tanstack/react-router';
import { useAuthStore } from '@/stores/auth-store.ts';
import { EditorLayout } from '@/components/editor/editor-layout.tsx';

export const Route = createFileRoute('/editor')({
  beforeLoad: () => {
    if (!useAuthStore.getState().isAuthenticated) {
      throw redirect({ to: '/login' });
    }
  },
  component: () => <EditorLayout configId={null} />,
});
