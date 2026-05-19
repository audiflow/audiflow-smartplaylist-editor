import { createFileRoute, Outlet } from '@tanstack/react-router';

export const Route = createFileRoute('/editor')({
  component: () => <Outlet />,
});
