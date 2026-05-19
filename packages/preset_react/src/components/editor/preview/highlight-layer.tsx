import type { ReactNode } from 'react';
import { useEditorStore } from '@/stores/editor-store.ts';

interface HighlightLayerProps {
  children: ReactNode;
}

// Declarative approach: write data attributes onto the wrapper div and let CSS
// handle descendant matching via attribute selectors. This avoids all ref/timing
// and multi-instance races that arise when imperatively toggling classes in
// useEffect (e.g. React Strict Mode double-invocation, multiple mounted instances
// each with their own rootRef, cleanup ordering races on unmount).
export function HighlightLayer({ children }: HighlightLayerProps) {
  const activeRegion = useEditorStore((s) => s.activePreviewRegion);
  const activeFields = useEditorStore((s) => s.activePreviewFields);

  return (
    <div
      data-active-region={activeRegion ?? undefined}
      data-active-fields={0 < activeFields.length ? activeFields.join(' ') : undefined}
    >
      {children}
    </div>
  );
}
