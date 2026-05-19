import { useCallback, useMemo } from 'react';
import { useEditorStore } from '@/stores/editor-store.ts';

export function usePreviewHighlight(fieldId: string) {
  const pulse = useEditorStore((s) => s.pulseActivePreviewField);
  const onFocus = useCallback(() => pulse(fieldId), [pulse, fieldId]);
  return useMemo(
    () => ({
      onFocus,
      'data-preview-field': fieldId,
    }),
    [onFocus, fieldId],
  );
}
