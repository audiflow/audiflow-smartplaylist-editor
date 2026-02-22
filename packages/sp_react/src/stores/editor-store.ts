import { create } from 'zustand';

interface EditorState {
  isJsonMode: boolean;
  feedUrl: string;
  toggleJsonMode: () => void;
  setFeedUrl: (url: string) => void;
  reset: () => void;
}

const initialState = {
  isJsonMode: false,
  feedUrl: '',
};

export const useEditorStore = create<EditorState>((set) => ({
  ...initialState,

  toggleJsonMode: () => set((state) => ({ isJsonMode: !state.isJsonMode })),
  setFeedUrl: (url) => set({ feedUrl: url }),
  reset: () => set(initialState),
}));
