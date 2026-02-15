import { createFileRoute, redirect } from '@tanstack/react-router';
import { useAuthStore } from '@/stores/auth-store.ts';

export const Route = createFileRoute('/browse')({
  beforeLoad: () => {
    if (!useAuthStore.getState().isAuthenticated) {
      throw redirect({ to: '/login' });
    }
  },
  component: BrowseScreen,
});

function BrowseScreen() {
  return <div>Browse (placeholder)</div>;
}
