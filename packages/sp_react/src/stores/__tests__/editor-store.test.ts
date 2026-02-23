import { describe, it, expect, beforeEach } from 'vitest';
import { useEditorStore } from '../editor-store';

describe('editorStore', () => {
  beforeEach(() => {
    useEditorStore.getState().reset();
  });

  it('starts with default state', () => {
    const state = useEditorStore.getState();
    expect(state.isJsonMode).toBe(false);
    expect(state.feedUrl).toBe('');
    expect(state.isDirty).toBe(false);
    expect(state.isSaving).toBe(false);
    expect(state.lastSavedAt).toBeNull();
    expect(state.conflictDetected).toBe(false);
    expect(state.conflictPath).toBeNull();
  });

  it('toggles JSON mode', () => {
    useEditorStore.getState().toggleJsonMode();
    expect(useEditorStore.getState().isJsonMode).toBe(true);
    useEditorStore.getState().toggleJsonMode();
    expect(useEditorStore.getState().isJsonMode).toBe(false);
  });

  it('sets feed URL', () => {
    useEditorStore.getState().setFeedUrl('https://example.com/feed.xml');
    expect(useEditorStore.getState().feedUrl).toBe(
      'https://example.com/feed.xml',
    );
  });

  it('tracks dirty state', () => {
    useEditorStore.getState().setDirty(true);
    expect(useEditorStore.getState().isDirty).toBe(true);
    useEditorStore.getState().setDirty(false);
    expect(useEditorStore.getState().isDirty).toBe(false);
  });

  it('tracks saving state', () => {
    useEditorStore.getState().setSaving(true);
    expect(useEditorStore.getState().isSaving).toBe(true);
    useEditorStore.getState().setSaving(false);
    expect(useEditorStore.getState().isSaving).toBe(false);
  });

  it('sets lastSavedAt and clears dirty flag', () => {
    useEditorStore.getState().setDirty(true);
    const now = new Date();
    useEditorStore.getState().setLastSavedAt(now);

    const state = useEditorStore.getState();
    expect(state.lastSavedAt).toBe(now);
    expect(state.isDirty).toBe(false);
  });

  it('sets and clears conflict', () => {
    useEditorStore.getState().setConflict('patterns/abc/meta.json');
    let state = useEditorStore.getState();
    expect(state.conflictDetected).toBe(true);
    expect(state.conflictPath).toBe('patterns/abc/meta.json');

    useEditorStore.getState().clearConflict();
    state = useEditorStore.getState();
    expect(state.conflictDetected).toBe(false);
    expect(state.conflictPath).toBeNull();
  });

  it('resets all state to defaults', () => {
    useEditorStore.getState().setFeedUrl('https://example.com');
    useEditorStore.getState().toggleJsonMode();
    useEditorStore.getState().setDirty(true);
    useEditorStore.getState().setSaving(true);
    useEditorStore.getState().setLastSavedAt(new Date());
    useEditorStore.getState().setConflict('some/path');
    useEditorStore.getState().reset();

    const state = useEditorStore.getState();
    expect(state.isJsonMode).toBe(false);
    expect(state.feedUrl).toBe('');
    expect(state.isDirty).toBe(false);
    expect(state.isSaving).toBe(false);
    expect(state.lastSavedAt).toBeNull();
    expect(state.conflictDetected).toBe(false);
    expect(state.conflictPath).toBeNull();
  });
});
