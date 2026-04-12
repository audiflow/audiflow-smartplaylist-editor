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

  it('adds the field-pulse class when activePreviewFields contains the field', () => {
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

  it('pulses multiple fields simultaneously', () => {
    const { container } = render(
      <HighlightLayer>
        <div data-preview-field="partition-entries">partitions</div>
        <div data-preview-field="group-list-order">groups</div>
      </HighlightLayer>,
    );
    const partitions = container.querySelector('[data-preview-field="partition-entries"]')!;
    const groups = container.querySelector('[data-preview-field="group-list-order"]')!;
    act(() => {
      useEditorStore.getState().pulseActivePreviewField('partition-entries', 10_000);
      useEditorStore.getState().pulseActivePreviewField('group-list-order', 10_000);
    });
    expect(partitions.classList.contains('preview-field-pulse')).toBe(true);
    expect(groups.classList.contains('preview-field-pulse')).toBe(true);
  });
});
