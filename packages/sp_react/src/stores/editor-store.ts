import { create } from 'zustand';
import type { PreviewResult } from '@/schemas/api-schema.ts';

interface EditorState {
  isJsonMode: boolean;
  feedUrl: string;
  isDirty: boolean;
  isSaving: boolean;
  lastSavedAt: Date | null;
  conflictDetected: boolean;
  conflictPath: string | null;
  previewData: PreviewResult | null;
  previewPending: boolean;
  toggleJsonMode: () => void;
  setFeedUrl: (url: string) => void;
  setDirty: (dirty: boolean) => void;
  setSaving: (saving: boolean) => void;
  setLastSavedAt: (date: Date) => void;
  setConflict: (path: string) => void;
  clearConflict: () => void;
  setPreviewData: (data: PreviewResult | null) => void;
  setPreviewPending: (pending: boolean) => void;
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
  previewData: null as PreviewResult | null,
  previewPending: false,
};

export const useEditorStore = create<EditorState>((set) => ({
  ...initialState,
  toggleJsonMode: () => set((state) => ({ isJsonMode: !state.isJsonMode })),
  setFeedUrl: (url) => set((state) => (state.feedUrl === url ? state : { feedUrl: url })),
  setDirty: (dirty) => set((state) => (state.isDirty === dirty ? state : { isDirty: dirty })),
  setSaving: (saving) => set({ isSaving: saving }),
  setLastSavedAt: (date) => set({ lastSavedAt: date, isDirty: false }),
  setConflict: (path) => set({ conflictDetected: true, conflictPath: path }),
  clearConflict: () => set({ conflictDetected: false, conflictPath: null }),
  setPreviewData: (data) => set({ previewData: data }),
  setPreviewPending: (pending) => set((state) => (state.previewPending === pending ? state : { previewPending: pending })),
  reset: () => set(initialState),
}));
