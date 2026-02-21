import { create } from 'zustand';

interface EditorState {
  isJsonMode: boolean;
  feedUrl: string;
  lastAutoSavedAt: Date | null;
  configVersion: number;
  lastSubmittedBranch: string | null;
  lastPrUrl: string | null;
  toggleJsonMode: () => void;
  setFeedUrl: (url: string) => void;
  setLastAutoSavedAt: (date: Date) => void;
  incrementConfigVersion: () => void;
  setLastSubmission: (branch: string, prUrl: string | null) => void;
  reset: () => void;
}

const initialState = {
  isJsonMode: false,
  feedUrl: '',
  lastAutoSavedAt: null as Date | null,
  configVersion: 0,
  lastSubmittedBranch: null as string | null,
  lastPrUrl: null as string | null,
};

export const useEditorStore = create<EditorState>((set) => ({
  ...initialState,

  toggleJsonMode: () => set((state) => ({ isJsonMode: !state.isJsonMode })),
  setFeedUrl: (url) => set({ feedUrl: url }),
  setLastAutoSavedAt: (date) => set({ lastAutoSavedAt: date }),
  incrementConfigVersion: () =>
    set((state) => ({ configVersion: state.configVersion + 1 })),
  setLastSubmission: (branch, prUrl) =>
    set({ lastSubmittedBranch: branch, lastPrUrl: prUrl }),
  reset: () => set(initialState),
}));
