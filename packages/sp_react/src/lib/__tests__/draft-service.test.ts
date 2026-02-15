import { describe, it, expect, beforeEach } from 'vitest';
import { DraftService } from '../draft-service';

describe('DraftService', () => {
  beforeEach(() => localStorage.clear());

  it('saves and loads a draft', () => {
    const service = new DraftService();
    const base = { id: 'p1', playlists: [] };
    const modified = { id: 'p1', playlists: [{ id: 'pl1' }] };

    service.saveDraft({ configId: 'p1', base, modified });
    const loaded = service.loadDraft('p1');

    expect(loaded).not.toBeNull();
    expect(loaded!.base).toEqual(base);
    expect(loaded!.modified).toEqual(modified);
    expect(loaded!.savedAt).toBeDefined();
  });

  it('returns null for missing draft', () => {
    const service = new DraftService();
    expect(service.loadDraft('nonexistent')).toBeNull();
  });

  it('uses __new__ key for null configId', () => {
    const service = new DraftService();
    service.saveDraft({ configId: null, base: {}, modified: { x: 1 } });
    expect(service.hasDraft(null)).toBe(true);
    expect(localStorage.getItem('autosave:__new__')).not.toBeNull();
  });

  it('clears a draft', () => {
    const service = new DraftService();
    service.saveDraft({ configId: 'p1', base: {}, modified: {} });
    service.clearDraft('p1');
    expect(service.hasDraft('p1')).toBe(false);
  });

  it('returns null for corrupted JSON', () => {
    const service = new DraftService();
    localStorage.setItem('autosave:bad', 'not-json');
    expect(service.loadDraft('bad')).toBeNull();
  });
});
