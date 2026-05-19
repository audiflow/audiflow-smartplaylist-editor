import { describe, expect, it, beforeEach } from 'vitest';
import { render, act } from '@testing-library/react';
import { HighlightLayer } from '@/components/editor/preview/highlight-layer.tsx';
import { useEditorStore } from '@/stores/editor-store.ts';

describe('HighlightLayer', () => {
  beforeEach(() => useEditorStore.getState().reset());

  it('sets data-active-region when activePreviewRegion is set', () => {
    const { container } = render(
      <HighlightLayer>
        <div data-preview-region="group-list">group list</div>
      </HighlightLayer>,
    );
    const wrapper = container.firstElementChild as HTMLElement;
    expect(wrapper.dataset.activeRegion).toBeUndefined();
    act(() => useEditorStore.getState().setActivePreviewRegion('group-list'));
    expect(wrapper.dataset.activeRegion).toBe('group-list');
    act(() => useEditorStore.getState().setActivePreviewRegion(null));
    expect(wrapper.dataset.activeRegion).toBeUndefined();
  });

  it('sets data-active-fields when pulseActivePreviewField is called', () => {
    const { container } = render(
      <HighlightLayer>
        <div data-preview-field="group-sort">sort</div>
      </HighlightLayer>,
    );
    const wrapper = container.firstElementChild as HTMLElement;
    expect(wrapper.dataset.activeFields).toBeUndefined();
    act(() => useEditorStore.getState().pulseActivePreviewField('group-sort', 10_000));
    expect(wrapper.dataset.activeFields).toBe('group-sort');
  });

  it('lists multiple simultaneous active fields space-separated', () => {
    const { container } = render(
      <HighlightLayer>
        <div data-preview-field="partition-entries">partitions</div>
        <div data-preview-field="group-list-order">groups</div>
      </HighlightLayer>,
    );
    const wrapper = container.firstElementChild as HTMLElement;
    act(() => {
      useEditorStore.getState().pulseActivePreviewField('partition-entries', 10_000);
      useEditorStore.getState().pulseActivePreviewField('group-list-order', 10_000);
    });
    // Both fields must appear as space-separated tokens so CSS ~= matching works
    const fields = wrapper.dataset.activeFields?.split(' ') ?? [];
    expect(fields).toContain('partition-entries');
    expect(fields).toContain('group-list-order');
  });
});
