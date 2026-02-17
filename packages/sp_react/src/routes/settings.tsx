import { createFileRoute, redirect, useNavigate } from '@tanstack/react-router';
import { useTranslation } from 'react-i18next';
import { useAuthStore } from '@/stores/auth-store.ts';
import { ApiKeyManager } from '@/components/settings/api-key-manager.tsx';
import { Button } from '@/components/ui/button.tsx';
import { ArrowLeft } from 'lucide-react';

export const Route = createFileRoute('/settings')({
  beforeLoad: () => {
    if (!useAuthStore.getState().isAuthenticated) {
      throw redirect({ to: '/login' });
    }
  },
  component: SettingsScreen,
});

function SettingsScreen() {
  const { t } = useTranslation('common');
  const navigate = useNavigate();

  return (
    <div className="container mx-auto max-w-4xl p-6">
      <div className="flex items-center gap-4 mb-6">
        <Button
          variant="ghost"
          size="icon"
          onClick={() => void navigate({ to: '/browse' })}
        >
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <h1 className="text-2xl font-bold">{t('settings')}</h1>
      </div>
      <ApiKeyManager />
    </div>
  );
}
