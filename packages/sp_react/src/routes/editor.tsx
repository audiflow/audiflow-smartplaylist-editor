import { createFileRoute, redirect } from '@tanstack/react-router';
import { useAuthStore } from '@/stores/auth-store.ts';

export const Route = createFileRoute('/editor')({
  beforeLoad: () => {
    if (!useAuthStore.getState().isAuthenticated) {
      throw redirect({ to: '/login' });
    }
  },
  component: EditorNewScreen,
});

function EditorNewScreen() {
  return <div>Editor: new config (placeholder)</div>;
}
