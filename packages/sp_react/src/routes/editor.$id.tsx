import { createFileRoute, redirect } from '@tanstack/react-router';
import { useAuthStore } from '@/stores/auth-store.ts';

export const Route = createFileRoute('/editor/$id')({
  beforeLoad: () => {
    if (!useAuthStore.getState().isAuthenticated) {
      throw redirect({ to: '/login' });
    }
  },
  component: EditorEditScreen,
});

function EditorEditScreen() {
  const { id } = Route.useParams();
  return <div>Editor: {id} (placeholder)</div>;
}
