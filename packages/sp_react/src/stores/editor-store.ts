import { create } from 'zustand';

interface EditorState {
  isJsonMode: boolean;
  feedUrl: string;
  lastAutoSavedAt: Date | null;
  configVersion: number;
  toggleJsonMode: () => void;
  setFeedUrl: (url: string) => void;
  setLastAutoSavedAt: (date: Date) => void;
  incrementConfigVersion: () => void;
  reset: () => void;
}

const initialState = {
  isJsonMode: false,
  feedUrl: '',
  lastAutoSavedAt: null as Date | null,
  configVersion: 0,
};

export const useEditorStore = create<EditorState>((set) => ({
  ...initialState,

  toggleJsonMode: () => set((state) => ({ isJsonMode: !state.isJsonMode })),
  setFeedUrl: (url) => set({ feedUrl: url }),
  setLastAutoSavedAt: (date) => set({ lastAutoSavedAt: date }),
  incrementConfigVersion: () =>
    set((state) => ({ configVersion: state.configVersion + 1 })),
  reset: () => set(initialState),
}));
