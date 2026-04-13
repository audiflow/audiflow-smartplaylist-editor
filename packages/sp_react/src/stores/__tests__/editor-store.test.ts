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

describe('editor-store — activeGroupContext', () => {
  beforeEach(() => {
    useEditorStore.getState().reset();
  });

  it('defaults to "all" for any playlist id', () => {
    expect(useEditorStore.getState().getActiveGroupContext('any-id')).toBe('all');
  });

  it('stores and retrieves context per playlist id', () => {
    useEditorStore.getState().setActiveGroupContext('playlist-1', 'group-abc');
    useEditorStore.getState().setActiveGroupContext('playlist-2', 'group-xyz');
    expect(useEditorStore.getState().getActiveGroupContext('playlist-1')).toBe('group-abc');
    expect(useEditorStore.getState().getActiveGroupContext('playlist-2')).toBe('group-xyz');
  });

  it('resets context for a specific playlist', () => {
    useEditorStore.getState().setActiveGroupContext('playlist-1', 'group-abc');
    useEditorStore.getState().resetActiveGroupContext('playlist-1');
    expect(useEditorStore.getState().getActiveGroupContext('playlist-1')).toBe('all');
  });

  it('clears all contexts on reset()', () => {
    useEditorStore.getState().setActiveGroupContext('playlist-1', 'group-abc');
    useEditorStore.getState().reset();
    expect(useEditorStore.getState().getActiveGroupContext('playlist-1')).toBe('all');
  });
});

describe('editor-store — preview highlight', () => {
  beforeEach(() => useEditorStore.getState().reset());

  it('defaults activePreviewRegion to null and activePreviewFields to empty array', () => {
    expect(useEditorStore.getState().activePreviewRegion).toBeNull();
    expect(useEditorStore.getState().activePreviewFields).toEqual([]);
  });

  it('sets and clears activePreviewRegion', () => {
    useEditorStore.getState().setActivePreviewRegion('group-list');
    expect(useEditorStore.getState().activePreviewRegion).toBe('group-list');
    useEditorStore.getState().setActivePreviewRegion(null);
    expect(useEditorStore.getState().activePreviewRegion).toBeNull();
  });

  it('adds field to activePreviewFields and auto-removes after delay', async () => {
    useEditorStore.getState().pulseActivePreviewField('group-sort', 50);
    expect(useEditorStore.getState().activePreviewFields).toContain('group-sort');
    await new Promise((r) => setTimeout(r, 80));
    expect(useEditorStore.getState().activePreviewFields).not.toContain('group-sort');
  });

  it('supports dual-field pulse simultaneously', () => {
    useEditorStore.getState().pulseActivePreviewField('partition-entries', 200);
    useEditorStore.getState().pulseActivePreviewField('group-list-order', 200);
    const { activePreviewFields } = useEditorStore.getState();
    expect(activePreviewFields).toContain('partition-entries');
    expect(activePreviewFields).toContain('group-list-order');
  });

  it('does not duplicate a field already pulsing', () => {
    useEditorStore.getState().pulseActivePreviewField('group-sort', 200);
    useEditorStore.getState().pulseActivePreviewField('group-sort', 200);
    const { activePreviewFields } = useEditorStore.getState();
    expect(activePreviewFields.filter((f) => f === 'group-sort')).toHaveLength(1);
  });

  it('resets TTL on rapid re-focus, keeping field active past original expiry', async () => {
    // First pulse with 50 ms TTL.
    useEditorStore.getState().pulseActivePreviewField('x', 50);
    // Re-pulse after 20 ms with a 100 ms TTL — this should cancel the 50 ms timer.
    await new Promise((r) => setTimeout(r, 20));
    useEditorStore.getState().pulseActivePreviewField('x', 100);
    // 60 ms later: past the original 50 ms TTL but only 80 ms into the 100 ms TTL.
    await new Promise((r) => setTimeout(r, 60));
    expect(useEditorStore.getState().activePreviewFields).toContain('x');
    // Another 60 ms: now 140 ms total since re-pulse, past the 100 ms TTL.
    await new Promise((r) => setTimeout(r, 60));
    expect(useEditorStore.getState().activePreviewFields).not.toContain('x');
  });
});
