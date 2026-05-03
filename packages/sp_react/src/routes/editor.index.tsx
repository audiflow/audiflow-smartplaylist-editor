import { useEffect, useMemo } from 'react';
import { createFileRoute } from '@tanstack/react-router';
import { z } from 'zod';
import { EditorLayout } from '@/components/editor/editor-layout.tsx';
import { useEditorStore } from '@/stores/editor-store.ts';
import type { PatternConfig } from '@/schemas/config-schema.ts';

const editorSearchSchema = z.object({
  feedUrl: z.string().optional(),
  displayName: z.string().optional(),
});

export const Route = createFileRoute('/editor/')({
  validateSearch: editorSearchSchema,
  component: EditorIndex,
});

function EditorIndex() {
  const { feedUrl, displayName } = Route.useSearch();
  const setFeedUrl = useEditorStore((s) => s.setFeedUrl);

  useEffect(() => {
    setFeedUrl(feedUrl ?? '');
  }, [feedUrl, setFeedUrl]);

  const initialConfig = useMemo<PatternConfig | undefined>(() => {
    if (!feedUrl && !displayName) return undefined;
    return {
      id: '',
      displayName: displayName ?? '',
      feedUrls: feedUrl ? [feedUrl] : [],
      playlists: [],
      yearGroupedEpisodes: false,
      showEpisodeThumbnail: true,
    };
  }, [feedUrl, displayName]);

  return <EditorLayout configId={null} initialConfig={initialConfig} />;
}
