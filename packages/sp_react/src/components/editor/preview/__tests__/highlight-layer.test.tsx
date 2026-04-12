import { describe, expect, it, beforeEach } from 'vitest';
import { render, act } from '@testing-library/react';
import { HighlightLayer } from '@/components/editor/preview/highlight-layer.tsx';
import { useEditorStore } from '@/stores/editor-store.ts';

describe('HighlightLayer', () => {
  beforeEach(() => useEditorStore.getState().reset());

  it('adds the region-highlight class when activePreviewRegion matches', () => {
    const { container } = render(
      <HighlightLayer>
        <div>
          <div data-preview-region="group-list">group list</div>
        </div>
      </HighlightLayer>,
    );
    const target = container.querySelector('[data-preview-region="group-list"]')!;
    expect(target.classList.contains('preview-region-active')).toBe(false);
    act(() => useEditorStore.getState().setActivePreviewRegion('group-list'));
    expect(target.classList.contains('preview-region-active')).toBe(true);
    act(() => useEditorStore.getState().setActivePreviewRegion(null));
    expect(target.classList.contains('preview-region-active')).toBe(false);
  });

  it('adds the field-pulse class when activePreviewField matches', () => {
    const { container } = render(
      <HighlightLayer>
        <div data-preview-field="group-sort">sort</div>
      </HighlightLayer>,
    );
    const target = container.querySelector('[data-preview-field="group-sort"]')!;
    expect(target.classList.contains('preview-field-pulse')).toBe(false);
    act(() => useEditorStore.getState().pulseActivePreviewField('group-sort', 10_000));
    expect(target.classList.contains('preview-field-pulse')).toBe(true);
  });
});
