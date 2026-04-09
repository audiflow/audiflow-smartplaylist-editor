import { useRef, useCallback } from 'react';
import { useApiClient } from '@/api/client-context.ts';
import type { PreviewResult } from '@/schemas/api-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';

/**
 * Preview mutation that writes results to the Zustand store instead of
 * returning them via useMutation. This avoids re-rendering the component
 * that triggers the preview (EditorLayout) when isPending/data changes.
 * Only components that select previewData/previewPending from the store
 * will re-render.
 */
export function useStorePreview() {
  const client = useApiClient();
  const inflightRef = useRef(0);

  const mutate = useCallback(
    (
      params: { config: unknown; feedUrl: string },
      options?: { onError?: (error: unknown) => void },
    ) => {
      const id = ++inflightRef.current;
      useEditorStore.getState().setPreviewPending(true);

      client
        .post<PreviewResult>('/api/configs/preview', params)
        .then((data) => {
          // Only apply if this is still the latest request
          if (id === inflightRef.current) {
            useEditorStore.getState().setPreviewData(data);
            useEditorStore.getState().setPreviewPending(false);
          }
        })
        .catch((error) => {
          if (id === inflightRef.current) {
            useEditorStore.getState().setPreviewPending(false);
          }
          options?.onError?.(error);
        });
    },
    [client],
  );

  return { mutate };
}
