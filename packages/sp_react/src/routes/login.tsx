import { createFileRoute, redirect } from '@tanstack/react-router';
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
  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="flex flex-col items-center gap-6">
        <h1 className="text-2xl font-bold">Audiflow Smart Playlist Editor</h1>
        <Button asChild size="lg">
          <a href={`${API_BASE_URL}/api/auth/github`}>Sign in with GitHub</a>
        </Button>
      </div>
    </div>
  );
}
