import { describe, it, expect, beforeEach } from 'vitest';
import { useEditorStore } from '../editor-store';

describe('editorStore', () => {
  beforeEach(() => {
    useEditorStore.getState().reset();
  });

  it('starts in form mode', () => {
    const state = useEditorStore.getState();
    expect(state.isJsonMode).toBe(false);
    expect(state.feedUrl).toBe('');
  });

  it('toggles JSON mode', () => {
    useEditorStore.getState().toggleJsonMode();
    expect(useEditorStore.getState().isJsonMode).toBe(true);
    useEditorStore.getState().toggleJsonMode();
    expect(useEditorStore.getState().isJsonMode).toBe(false);
  });

  it('sets feed URL', () => {
    useEditorStore.getState().setFeedUrl('https://example.com/feed.xml');
    expect(useEditorStore.getState().feedUrl).toBe('https://example.com/feed.xml');
  });

  it('resets state', () => {
    useEditorStore.getState().setFeedUrl('https://example.com');
    useEditorStore.getState().toggleJsonMode();
    useEditorStore.getState().reset();

    const state = useEditorStore.getState();
    expect(state.isJsonMode).toBe(false);
    expect(state.feedUrl).toBe('');
  });
});
