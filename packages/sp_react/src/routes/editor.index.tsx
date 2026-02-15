import { createFileRoute } from '@tanstack/react-router';
import { EditorLayout } from '@/components/editor/editor-layout.tsx';

export const Route = createFileRoute('/editor/')({
  component: () => <EditorLayout configId={null} />,
});
