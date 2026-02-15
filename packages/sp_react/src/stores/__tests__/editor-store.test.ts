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
    expect(state.lastAutoSavedAt).toBeNull();
    expect(state.configVersion).toBe(0);
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

  it('sets last auto-saved date', () => {
    const date = new Date('2024-01-01');
    useEditorStore.getState().setLastAutoSavedAt(date);
    expect(useEditorStore.getState().lastAutoSavedAt).toEqual(date);
  });

  it('increments config version', () => {
    useEditorStore.getState().incrementConfigVersion();
    expect(useEditorStore.getState().configVersion).toBe(1);
    useEditorStore.getState().incrementConfigVersion();
    expect(useEditorStore.getState().configVersion).toBe(2);
  });

  it('resets state', () => {
    useEditorStore.getState().setFeedUrl('https://example.com');
    useEditorStore.getState().toggleJsonMode();
    useEditorStore.getState().incrementConfigVersion();
    useEditorStore.getState().reset();

    const state = useEditorStore.getState();
    expect(state.isJsonMode).toBe(false);
    expect(state.feedUrl).toBe('');
    expect(state.lastAutoSavedAt).toBeNull();
    expect(state.configVersion).toBe(0);
  });
});
