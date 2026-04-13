import { create } from 'zustand';
import type { PreviewResult } from '@/schemas/api-schema.ts';

// Module-scope map so timer handles survive re-renders without entering React state.
// Cancelling the previous timer for a field before registering a new one ensures
// rapid re-focus extends the TTL rather than letting stale timeouts fire early.
const pulseTimers = new Map<string, ReturnType<typeof setTimeout>>();

export type ActiveGroupContext = 'all' | string;

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
  activeGroupContexts: Record<string, ActiveGroupContext>;
  toggleJsonMode: () => void;
  setFeedUrl: (url: string) => void;
  setDirty: (dirty: boolean) => void;
  setSaving: (saving: boolean) => void;
  setLastSavedAt: (date: Date) => void;
  setConflict: (path: string) => void;
  clearConflict: () => void;
  setPreviewData: (data: PreviewResult | null) => void;
  setPreviewPending: (pending: boolean) => void;
  getActiveGroupContext: (playlistId: string) => ActiveGroupContext;
  setActiveGroupContext: (playlistId: string, context: ActiveGroupContext) => void;
  resetActiveGroupContext: (playlistId: string) => void;
  activePreviewRegion: string | null;
  activePreviewFields: string[];
  setActivePreviewRegion: (region: string | null) => void;
  pulseActivePreviewField: (field: string, ttlMs?: number) => void;
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
  activeGroupContexts: {} as Record<string, ActiveGroupContext>,
  activePreviewRegion: null as string | null,
  activePreviewFields: [] as string[],
};

export const useEditorStore = create<EditorState>((set, get) => ({
  ...initialState,
  toggleJsonMode: () => set((state) => ({ isJsonMode: !state.isJsonMode })),
  setFeedUrl: (url) => set((state) => (state.feedUrl === url ? {} : { feedUrl: url })),
  setDirty: (dirty) => set((state) => (state.isDirty === dirty ? {} : { isDirty: dirty })),
  setSaving: (saving) => set((state) => (state.isSaving === saving ? {} : { isSaving: saving })),
  setLastSavedAt: (date) => set({ lastSavedAt: date, isDirty: false }),
  setConflict: (path) => set({ conflictDetected: true, conflictPath: path }),
  clearConflict: () => set({ conflictDetected: false, conflictPath: null }),
  setPreviewData: (data) => set({ previewData: data }),
  setPreviewPending: (pending) => set((state) => (state.previewPending === pending ? {} : { previewPending: pending })),
  getActiveGroupContext: (playlistId) => get().activeGroupContexts[playlistId] ?? 'all',
  setActiveGroupContext: (playlistId, context) =>
    set((state) => ({
      activeGroupContexts: { ...state.activeGroupContexts, [playlistId]: context },
    })),
  resetActiveGroupContext: (playlistId) =>
    set((state) => {
      if (!(playlistId in state.activeGroupContexts)) return {};
      const { [playlistId]: _removed, ...rest } = state.activeGroupContexts;
      return { activeGroupContexts: rest };
    }),
  setActivePreviewRegion: (region) =>
    set((state) => (state.activePreviewRegion === region ? {} : { activePreviewRegion: region })),
  pulseActivePreviewField: (field, ttlMs = 1000) => {
    const existing = pulseTimers.get(field);
    if (existing !== undefined) clearTimeout(existing);
    set((state) =>
      state.activePreviewFields.includes(field)
        ? {}
        : { activePreviewFields: [...state.activePreviewFields, field] },
    );
    const timer = setTimeout(() => {
      pulseTimers.delete(field);
      set((state) => ({
        activePreviewFields: state.activePreviewFields.filter((f) => f !== field),
      }));
    }, ttlMs);
    pulseTimers.set(field, timer);
  },
  reset: () => set(initialState),
}));
