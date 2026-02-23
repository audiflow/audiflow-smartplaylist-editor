import { describe, it, expect } from 'vitest';

/**
 * Regression test for the save-then-edit dirty tracking bug.
 *
 * The editor compares JSON.stringify(current) against JSON.stringify(lastLoadedConfig)
 * to determine dirty state. After save, lastLoadedConfig must be an independent
 * deep clone so that subsequent form mutations don't silently update it.
 */
describe('dirty tracking snapshot isolation', () => {
  // Simulates the dirty-check logic from editor-layout.tsx
  function isDirty(
    current: Record<string, unknown>,
    lastLoaded: Record<string, unknown>,
  ): boolean {
    return JSON.stringify(current) !== JSON.stringify(lastLoaded);
  }

  it('detects changes after save when snapshot is cloned', () => {
    // Simulate form.getValues() returning a mutable object
    const formValues = {
      id: 'test',
      playlists: [{ id: 'p1', displayName: 'Original' }],
    };

    // Save: snapshot with structuredClone (the fix)
    const snapshot = structuredClone(formValues);

    // User edits after save (mutates the form's internal state)
    formValues.playlists[0].displayName = 'Modified';

    // Dirty check should detect the change
    expect(isDirty(formValues, snapshot)).toBe(true);
  });

  it('fails to detect changes when snapshot aliases form state (the bug)', () => {
    const formValues = {
      id: 'test',
      playlists: [{ id: 'p1', displayName: 'Original' }],
    };

    // Bug: storing the reference directly (no clone)
    const snapshot = formValues;

    // User edits after save — mutates both formValues and snapshot
    formValues.playlists[0].displayName = 'Modified';

    // Bug: dirty check sees them as equal because they're the same object
    expect(isDirty(formValues, snapshot)).toBe(false);
  });
});
