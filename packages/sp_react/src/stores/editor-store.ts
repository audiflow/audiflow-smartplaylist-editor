import { create } from 'zustand';

interface EditorState {
  isJsonMode: boolean;
  feedUrl: string;
  isDirty: boolean;
  isSaving: boolean;
  lastSavedAt: Date | null;
  conflictDetected: boolean;
  conflictPath: string | null;
  toggleJsonMode: () => void;
  setFeedUrl: (url: string) => void;
  setDirty: (dirty: boolean) => void;
  setSaving: (saving: boolean) => void;
  setLastSavedAt: (date: Date) => void;
  setConflict: (path: string) => void;
  clearConflict: () => void;
  reset: () => void;
}

const initialState = {
  isJsonMode: false,
  feedUrl: '',
  isDirty: false,
  isSaving: false,
  lastSavedAt: null as Date | null,
  conflictDetected: false,
  conflictPath: null as string | null,
};

export const useEditorStore = create<EditorState>((set) => ({
  ...initialState,
  toggleJsonMode: () => set((state) => ({ isJsonMode: !state.isJsonMode })),
  setFeedUrl: (url) => set({ feedUrl: url }),
  setDirty: (dirty) => set({ isDirty: dirty }),
  setSaving: (saving) => set({ isSaving: saving }),
  setLastSavedAt: (date) => set({ lastSavedAt: date, isDirty: false }),
  setConflict: (path) => set({ conflictDetected: true, conflictPath: path }),
  clearConflict: () => set({ conflictDetected: false, conflictPath: null }),
  reset: () => set(initialState),
}));
