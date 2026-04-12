import { useEffect, useRef, type ReactNode } from 'react';
import { useEditorStore } from '@/stores/editor-store.ts';

interface HighlightLayerProps {
  children: ReactNode;
}

export function HighlightLayer({ children }: HighlightLayerProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const activeRegion = useEditorStore((s) => s.activePreviewRegion);
  const activeField = useEditorStore((s) => s.activePreviewField);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const all = root.querySelectorAll<HTMLElement>('[data-preview-region]');
    all.forEach((el) => {
      el.classList.toggle('preview-region-active', el.dataset.previewRegion === activeRegion);
    });
  }, [activeRegion]);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const all = root.querySelectorAll<HTMLElement>('[data-preview-field]');
    all.forEach((el) => {
      el.classList.toggle('preview-field-pulse', el.dataset.previewField === activeField);
    });
  }, [activeField]);

  return <div ref={rootRef}>{children}</div>;
}
