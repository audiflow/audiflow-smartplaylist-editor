import { createFileRoute } from '@tanstack/react-router';
import { z } from 'zod';
import { FeedViewer } from '@/components/feed/feed-viewer.tsx';

const feedSearchSchema = z.object({
  url: z.string().optional(),
});

export const Route = createFileRoute('/feeds')({
  validateSearch: feedSearchSchema,
  component: FeedViewerPage,
});

function FeedViewerPage() {
  const { url } = Route.useSearch();
  return <FeedViewer initialUrl={url} />;
}
