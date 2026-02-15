import { useEffect, useRef } from 'react';
import { DraftService } from '@/lib/draft-service.ts';
import { useEditorStore } from '@/stores/editor-store.ts';

const draftService = new DraftService();
const AUTO_SAVE_DELAY = 2000;

export function useAutoSave(
  configId: string | null,
  base: unknown,
  getValues: () => unknown,
  watch: (callback: () => void) => { unsubscribe: () => void },
) {
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const { unsubscribe } = watch(() => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
      timeoutRef.current = setTimeout(() => {
        draftService.saveDraft({
          configId,
          base,
          modified: getValues(),
        });
        useEditorStore.getState().setLastAutoSavedAt(new Date());
      }, AUTO_SAVE_DELAY);
    });

    return () => {
      unsubscribe();
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    };
  }, [configId, base, getValues, watch]);
}
