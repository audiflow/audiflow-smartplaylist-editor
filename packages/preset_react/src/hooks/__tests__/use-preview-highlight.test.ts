import { describe, expect, it, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { usePreviewHighlight } from '@/hooks/use-preview-highlight.ts';
import { useEditorStore } from '@/stores/editor-store.ts';

describe('usePreviewHighlight', () => {
  beforeEach(() => useEditorStore.getState().reset());

  it('returns props that call pulseActivePreviewField on focus', () => {
    const { result } = renderHook(() => usePreviewHighlight('group-sort'));
    act(() => result.current.onFocus());
    expect(useEditorStore.getState().activePreviewFields).toContain('group-sort');
  });

  it('returns a data attribute for the field id', () => {
    const { result } = renderHook(() => usePreviewHighlight('episode-title'));
    expect(result.current['data-preview-field']).toBe('episode-title');
  });
});
