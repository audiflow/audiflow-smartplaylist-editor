import { createFileRoute, redirect } from '@tanstack/react-router';
import { useAuthStore } from '@/stores/auth-store.ts';

export const Route = createFileRoute('/settings')({
  beforeLoad: () => {
    if (!useAuthStore.getState().isAuthenticated) {
      throw redirect({ to: '/login' });
    }
  },
  component: SettingsScreen,
});

function SettingsScreen() {
  return <div>Settings (placeholder)</div>;
}
