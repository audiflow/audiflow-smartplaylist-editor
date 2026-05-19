import { createRootRoute, Outlet } from '@tanstack/react-router';
import { Toaster } from '@/components/ui/sonner.tsx';
import { useFileEvents } from '@/hooks/use-file-events.ts';

export const Route = createRootRoute({
  component: RootLayout,
});

function RootLayout() {
  useFileEvents();
  return (
    <>
      <Outlet />
      <Toaster />
    </>
  );
}
