import { createFileRoute, redirect } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { useAuthStore } from '@/stores/auth-store.ts';
import { Button } from '@/components/ui/button.tsx';

const API_BASE_URL =
  (import.meta.env.VITE_API_BASE_URL as string) || 'http://localhost:8080';

export const Route = createFileRoute('/login')({
  beforeLoad: () => {
    if (useAuthStore.getState().isAuthenticated) {
      throw redirect({ to: '/browse' });
    }
  },
  component: LoginScreen,
});

function LoginScreen() {
  const { t } = useTranslation('common');
  const redirectUri = `${window.location.origin}/login`;
  const authUrl = `${API_BASE_URL}/api/auth/github?redirect_uri=${encodeURIComponent(redirectUri)}`;

  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="flex flex-col items-center gap-6">
        <h1 className="text-2xl font-bold">{t('appTitle')}</h1>
        <Button asChild size="lg">
          <a href={authUrl}>{t('signInGithub')}</a>
        </Button>
      </div>
    </div>
  );
}
