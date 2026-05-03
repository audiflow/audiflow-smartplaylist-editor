import { useState, useCallback, useEffect, useMemo, useRef } from 'react';
import { useNavigate } from '@tanstack/react-router';
import { useForm, useFieldArray, useFormContext, useWatch, FormProvider, type Resolver, type Control } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import {
  patternConfigSchema,
  type PatternConfig,
} from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import {
  useFeed,
  useAssembledConfig,
  useSavePlaylist,
  useSavePatternMeta,
  useCreatePattern,
  useDeletePlaylist,
} from '@/api/queries.ts';
import { useStorePreview } from '@/hooks/use-store-preview.ts';
import { sanitizeConfig, stripConditionalFields } from '@/lib/sanitize-config.ts';
import { DEFAULT_PLAYLIST } from '@/components/editor/config-form.tsx';
import { PatternSettingsCard } from '@/components/editor/pattern-settings.tsx';
import { PatternDangerZone } from '@/components/editor/pattern-danger-zone.tsx';
import { PlaylistTabContent } from '@/components/editor/playlist-tab-content.tsx';
import { JsonEditor } from '@/components/editor/json-editor.tsx';
import { ConflictDialog } from '@/components/editor/conflict-dialog.tsx';
import { FeedUrlInput } from '@/components/editor/feed-url-input.tsx';
import { PlaylistReorderDialog } from '@/components/editor/playlist-reorder-dialog.tsx';
import { DebugInfoStats } from '@/components/preview/debug-info-panel.tsx';
import { Button } from '@/components/ui/button.tsx';
import {
  Tabs,
  TabsList,
  TabsTrigger,
  TabsContent,
} from '@/components/ui/tabs.tsx';
import { Badge } from '@/components/ui/badge.tsx';
import {
  ArrowLeft,
  ArrowUpDown,
  BookOpen,
  Code,
  ExternalLink,
  FormInput,
  Loader2,
  Plus,
  Save,
} from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';

const DEFAULT_CONFIG: PatternConfig = {
  id: '',
  displayName: '',
  playlists: [],
  yearGroupedEpisodes: false,
};

interface EditorLayoutProps {
  configId: string | null;
  initialConfig?: PatternConfig;
}

export function EditorLayout({ configId, initialConfig }: EditorLayoutProps) {
  const { t } = useTranslation('editor');
  const navigate = useNavigate();
  // Use individual selectors to avoid re-rendering on unrelated store changes
  // (e.g., previewData updates should not re-render EditorLayout).
  const isJsonMode = useEditorStore((s) => s.isJsonMode);
  const feedUrl = useEditorStore((s) => s.feedUrl);
  const isDirty = useEditorStore((s) => s.isDirty);
  const isSaving = useEditorStore((s) => s.isSaving);
  const conflictDetected = useEditorStore((s) => s.conflictDetected);
  const conflictPath = useEditorStore((s) => s.conflictPath);
  // Actions are stable — read once via getState, no subscription needed
  const {
    toggleJsonMode,
    setFeedUrl,
    setDirty,
    setSaving,
    setLastSavedAt,
    setConflict,
    clearConflict,
    reset: resetEditorStore,
  } = useMemo(() => useEditorStore.getState(), []);
  const [jsonText, setJsonText] = useState('');

  // Normalize the incoming config through the Zod schema (applies default
   // transforms and coercions) before seeding the form.
  const normalizedInitialConfig = useMemo(() => {
    if (!initialConfig) return undefined;
    const parsed = patternConfigSchema.safeParse(initialConfig);
    return parsed.success ? parsed.data : initialConfig;
  }, [initialConfig]);

  const form = useForm<PatternConfig>({
    // Cast needed: zodResolver infers the Zod input type (with optional defaults),
    // but the form operates on the output type where defaults are applied.
    resolver: zodResolver(patternConfigSchema) as Resolver<PatternConfig>,
    defaultValues: normalizedInitialConfig ?? DEFAULT_CONFIG,
  });


  const storePreview = useStorePreview();
  const storePreviewRef = useRef(storePreview);
  storePreviewRef.current = storePreview;
  // Read preview state only where needed (via selectors), not here.

  const feedQuery = useFeed(feedUrl || null);
  const savePlaylistMutation = useSavePlaylist();
  const savePatternMetaMutation = useSavePatternMeta();
  const createPatternMutation = useCreatePattern();
  const deletePlaylistMutation = useDeletePlaylist();

  // Watch form fields for header display and save button
  const formId = useWatch({ control: form.control, name: 'id' });
  const formDisplayName = useWatch({ control: form.control, name: 'displayName' });
  const isNewConfig = configId === null;
  const effectiveId = isNewConfig ? formId : configId;


  // Auto-populate feed URL input from feedUrls when the input is empty.
  // In form mode, watch the form field; in JSON mode, parse from jsonText.
  const formFeedUrls = useWatch({ control: form.control, name: 'feedUrls' });
  useEffect(() => {
    if (feedUrl) return;
    if (isJsonMode) {
      try {
        const parsed = JSON.parse(jsonText) as { feedUrls?: string[] };
        const first = parsed.feedUrls?.[0];
        if (first) setFeedUrl(first);
      } catch { /* ignore parse errors */ }
    } else {
      const first = formFeedUrls?.[0];
      if (first) setFeedUrl(first);
    }
  }, [formFeedUrls, jsonText, isJsonMode, feedUrl, setFeedUrl]);

  // Track the config snapshot that was last loaded/saved for conflict detection
  const [lastLoadedConfig, setLastLoadedConfig] = useState<PatternConfig | undefined>(normalizedInitialConfig);

  // Watch the assembled config query for external changes
  const assembledConfigQuery = useAssembledConfig(configId);

  // Initialize feed URL from config on mount
  useEffect(() => {
    const urls = initialConfig?.feedUrls;
    if (urls && 0 < urls.length) {
      setFeedUrl(urls[0]);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Detect external changes while user has unsaved edits (conflict detection).
  // Normalize the server payload through Zod so v3 legacy naming differences
  // don't trigger false conflict warnings.
  useEffect(() => {
    if (!assembledConfigQuery.data || !isDirty || isSaving) return;
    const parsed = patternConfigSchema.safeParse(assembledConfigQuery.data);
    const normalizedServer = parsed.success ? parsed.data : assembledConfigQuery.data;
    if (JSON.stringify(normalizedServer) !== JSON.stringify(lastLoadedConfig)) {
      setConflict(`patterns/${configId}`);
    }
  }, [assembledConfigQuery.data]); // eslint-disable-line react-hooks/exhaustive-deps

  // Pre-compute normalized reference for dirty comparison.
  // Zod parse applies all defaults (showYearHeaders: false, etc.)
  // so both sides have the same shape regardless of which tabs have been mounted.
  const normalizedLastLoaded = useMemo(() => {
    if (!lastLoadedConfig) return undefined;
    const parsed = patternConfigSchema.safeParse(lastLoadedConfig);
    if (!parsed.success) return undefined;
    return JSON.stringify(sanitizeConfig(parsed.data));
  }, [lastLoadedConfig]);

  // Dirty tracking via form.watch()
  useEffect(() => {
    const subscription = form.watch(() => {
      if (isNewConfig) {
        // New configs are dirty once the user has entered a pattern id
        const values = form.getValues();
        setDirty(!!values.id);
        return;
      }
      if (!normalizedInitialConfig || normalizedLastLoaded === undefined) {
        setDirty(true);
        return;
      }
      const parsed = patternConfigSchema.safeParse(form.getValues());
      if (!parsed.success) {
        setDirty(true);
        return;
      }
      const current = JSON.stringify(sanitizeConfig(parsed.data));
      setDirty(current !== normalizedLastLoaded);
    });
    return () => subscription.unsubscribe();
  }, [form, normalizedLastLoaded, setDirty, normalizedInitialConfig, isNewConfig]);

  const handleModeToggle = useCallback(() => {
    if (!isJsonMode) {
      // Form -> JSON: serialize current form values
      setJsonText(JSON.stringify(form.getValues(), null, 2));
    } else {
      // JSON -> Form: require valid JSON syntax, but allow schema errors
      // so the user can fix them inline via form validation.
      let raw: unknown;
      try {
        raw = JSON.parse(jsonText);
      } catch (e) {
        toast.error(
          t('toastInvalidJson', { error: e instanceof Error ? e.message : 'Parse error' }),
        );
        return;
      }
      const result = patternConfigSchema.safeParse(raw);
      form.reset(result.success ? result.data : (raw as PatternConfig), { keepDefaultValues: false });
      if (!result.success) {
        // Trigger validation so field errors show immediately
        void form.trigger();
      }
    }
    toggleJsonMode();
  }, [isJsonMode, jsonText, form, toggleJsonMode, t]);

  // Safe JSON parse for render-time props (avoids throwing during render)
  const parsedJsonConfig = useMemo(() => {
    if (!isJsonMode) return null;
    try {
      return JSON.parse(jsonText) as PatternConfig;
    } catch {
      return null;
    }
  }, [isJsonMode, jsonText]);

  // Save handler: persist each playlist + pattern meta to disk
  const handleSave = useCallback(async () => {
    if (!effectiveId || isSaving) return;

    // Normalize through Zod so legacy-key migrations and default transforms are
    // applied before saving, keeping save behavior consistent with preview.
    // stripConditionalFields removes fields hidden by the current resolverType
    // so they don't get persisted (form state retains them for undo).
    const raw = isJsonMode && parsedJsonConfig ? parsedJsonConfig : form.getValues();
    const parsed = patternConfigSchema.safeParse(raw);
    if (!parsed.success) {
      // Trigger form validation so field errors surface in the UI
      void form.trigger();
      return;
    }
    const stripped = isJsonMode ? parsed.data : stripConditionalFields(parsed.data);
    // Auto-assign priority from playlist array order so users never need to
    // set it manually -- the order in the editor *is* the priority.
    const snapshot = structuredClone({
      ...stripped,
      playlists: stripped.playlists.map((pl, index) => ({ ...pl, priority: index })),
    });

    setSaving(true);
    try {
      if (isNewConfig) {
        // Create the pattern directory first
        await createPatternMutation.mutateAsync({
          data: {
            id: effectiveId,
            displayName: snapshot.displayName ?? undefined,
            meta: {
              id: effectiveId,
              feedUrls: snapshot.feedUrls ?? [],
              yearGroupedEpisodes: snapshot.yearGroupedEpisodes ?? false,
              playlists: snapshot.playlists.map((p) => p.id),
            },
          },
        });
      }

      // Delete playlist files for playlists the user removed from the form.
      // Without this, removed playlists disappear from meta.json but their
      // {patternId}/playlists/{id}.json files stay on disk as orphans and the
      // server endpoint that updates meta later re-lists no-longer-existing files.
      if (!isNewConfig) {
        const previousIds = new Set(
          lastLoadedConfig?.playlists.map((p) => p.id) ?? [],
        );
        const currentIds = new Set(snapshot.playlists.map((p) => p.id));
        const removedIds = [...previousIds].filter((id) => !currentIds.has(id));
        for (const removedId of removedIds) {
          await deletePlaylistMutation.mutateAsync({
            patternId: effectiveId,
            playlistId: removedId,
          });
        }
      }

      for (const playlist of snapshot.playlists) {
        await savePlaylistMutation.mutateAsync({
          patternId: effectiveId,
          playlistId: playlist.id,
          data: sanitizeConfig(playlist),
        });
      }

      if (!isNewConfig) {
        await savePatternMetaMutation.mutateAsync({
          patternId: effectiveId,
          data: {
            id: effectiveId,
            displayName: snapshot.displayName ?? undefined,
            feedUrls: snapshot.feedUrls ?? [],
            yearGroupedEpisodes: snapshot.yearGroupedEpisodes ?? false,
            playlists: snapshot.playlists.map((p) => p.id),
          },
        });
      }

      setLastSavedAt(new Date());
      setLastLoadedConfig(snapshot);
      setDirty(false);
      toast.success(t('toastSaved', 'Saved successfully'));

      if (isNewConfig) {
        void navigate({ to: '/editor/$id', params: { id: effectiveId } });
      }
    } catch (error) {
      toast.error(
        t('toastSaveError', {
          error: error instanceof Error ? error.message : 'Save failed',
          defaultValue: 'Save failed: {{error}}',
        }),
      );
    } finally {
      setSaving(false);
    }
  }, [effectiveId, isSaving, isJsonMode, isNewConfig, parsedJsonConfig, form, createPatternMutation, savePlaylistMutation, savePatternMetaMutation, deletePlaylistMutation, lastLoadedConfig, navigate, setSaving, setDirty, setLastSavedAt, t]);

  // Ctrl+S / Cmd+S keyboard shortcut
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 's') {
        e.preventDefault();
        void handleSave();
      }
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [handleSave]);

  // Auto-run preview when opening an existing config.
  // Uses initialConfig.feedUrls directly (not the Zustand store's feedUrl) to
  // avoid a stale-URL race: the store may still hold the previous config's URL
  // when this effect first fires.
  //
  // The cleanup resets the ref so StrictMode's remount phase can re-fire.
  // StrictMode detaches the mutation observer during cleanup, so the first
  // fire's mutation becomes orphaned; the second fire attaches properly.
  const hasAutoPreviewedRef = useRef(false);
  // Tracks the last-previewed form serialization so the debounced effect can
  // skip duplicate requests (e.g. the initial auto-preview's first tick).
  const lastPreviewedValuesRef = useRef<string | null>(null);
  useEffect(() => {
    if (hasAutoPreviewedRef.current || !configId || !normalizedInitialConfig) return;
    const url = normalizedInitialConfig.feedUrls?.[0];
    if (!url) return;
    hasAutoPreviewedRef.current = true;
    // Record the initial serialization so the debounced effect skips its first tick
    const stripped = stripConditionalFields(normalizedInitialConfig);
    lastPreviewedValuesRef.current = `${url}\0${JSON.stringify(stripped)}`;
    storePreviewRef.current.mutate(
      { config: sanitizeConfig(stripped), feedUrl: url },
      {
        onError: (error) => {
          toast.error(t('toastPreviewError', {
            error: error instanceof Error ? error.message : 'Preview failed',
            defaultValue: 'Preview failed: {{error}}',
          }));
        },
      },
    );
    return () => {
      hasAutoPreviewedRef.current = false;
    };
  }, [configId, normalizedInitialConfig, t]);

  // Shared preview trigger used by form-mode form.watch(), JSON-mode jsonText
  // changes, and feedUrl switches. Returns without mutating when the same
  // (feedUrl, config) pair was already previewed, guarding against redundant
  // requests across the three entry points. Marks the auto-preview ref so
  // later triggers (typing a feed URL on a saved config that had none) are
  // not gated by a never-fired initial auto-preview.
  const triggerPreview = useCallback(
    (rawConfig: unknown) => {
      if (!feedUrl) return;
      const parsed = patternConfigSchema.safeParse(rawConfig);
      if (!parsed.success) return;
      const config = stripConditionalFields(parsed.data);
      const key = `${feedUrl}\0${JSON.stringify(config)}`;
      if (key === lastPreviewedValuesRef.current) return;
      lastPreviewedValuesRef.current = key;
      hasAutoPreviewedRef.current = true;
      storePreviewRef.current.mutate(
        { config: sanitizeConfig(config), feedUrl },
        {
          onError: (error) => {
            toast.error(t('toastPreviewError', {
              error: error instanceof Error ? error.message : 'Preview failed',
              defaultValue: 'Preview failed: {{error}}',
            }));
          },
        },
      );
    },
    [feedUrl, t],
  );

  // Debounced auto-preview via form.watch() subscription (form mode only).
  // Uses a subscription + setTimeout instead of useWatch to avoid re-rendering
  // the entire editor on every keystroke.
  useEffect(() => {
    if (isJsonMode) return;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const subscription = form.watch(() => {
      clearTimeout(timer);
      timer = setTimeout(() => {
        triggerPreview(form.getValues());
      }, 400);
    });
    return () => {
      clearTimeout(timer);
      subscription.unsubscribe();
    };
  }, [form, isJsonMode, triggerPreview]);

  // Debounced auto-preview for JSON-mode edits. Parses jsonText and mirrors
  // the form-mode path so users editing advanced fields in JSON can still
  // validate their changes against live preview.
  useEffect(() => {
    if (!isJsonMode) return;
    const timer = setTimeout(() => {
      let raw: unknown;
      try {
        raw = JSON.parse(jsonText);
      } catch {
        return;
      }
      triggerPreview(raw);
    }, 400);
    return () => clearTimeout(timer);
  }, [jsonText, isJsonMode, triggerPreview]);

  // Fire preview when the feed URL changes, even if the config itself is
  // unchanged. Without this, switching feeds via the FeedUrlInput dropdown
  // or pasting a new URL leaves the preview bound to the previous feed
  // until the user edits an unrelated form field.
  useEffect(() => {
    if (!feedUrl) return;
    const source = isJsonMode ? (() => {
      try { return JSON.parse(jsonText); } catch { return null; }
    })() : form.getValues();
    if (source === null) return;
    triggerPreview(source);
    // jsonText intentionally omitted: only feedUrl switches should refire here.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [feedUrl, triggerPreview]);

  // Normalize server payload through Zod for consistent v3-to-v4 migration.
  const normalizeServerConfig = useCallback((raw: PatternConfig): PatternConfig => {
    const parsed = patternConfigSchema.safeParse(raw);
    return parsed.success ? parsed.data : raw;
  }, []);

  // Conflict resolution: reload from disk
  const handleReload = useCallback(() => {
    if (assembledConfigQuery.data) {
      const normalized = normalizeServerConfig(assembledConfigQuery.data);
      form.reset(normalized);
      setLastLoadedConfig(normalized);
      setDirty(false);
    }
    clearConflict();
  }, [assembledConfigQuery.data, form, setDirty, clearConflict, normalizeServerConfig]);

  // Conflict resolution: keep current changes
  const handleKeepChanges = useCallback(() => {
    clearConflict();
    // Update lastLoadedConfig so we don't re-trigger conflict
    if (assembledConfigQuery.data) {
      setLastLoadedConfig(normalizeServerConfig(assembledConfigQuery.data));
    }
  }, [assembledConfigQuery.data, clearConflict, normalizeServerConfig]);

  return (
    <div className="container mx-auto max-w-7xl p-6">
      {/* Header + Preview button (sticky) */}
      <div className="sticky top-0 z-10 bg-background pb-4 border-b">
        <EditorHeader
          configId={configId}
          displayName={formDisplayName || null}
          feedUrl={feedUrl || null}
          isJsonMode={isJsonMode}
          onBack={() => {
            resetEditorStore();
            void navigate({ to: '/browse' });
          }}
          onModeToggle={handleModeToggle}
        />

        <div className="flex items-center justify-end gap-2">
            <PreviewPendingIndicator />
            <Button
              onClick={() => void handleSave()}
              disabled={!isDirty || isSaving || !effectiveId}
              variant={isDirty ? 'default' : 'outline'}
            >
              {isSaving ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Save className="mr-2 h-4 w-4" />
              )}
              {t('save', 'Save')}
            </Button>
        </div>
      </div>

      {/* Feed URL Input */}
      <div className="my-6">
        <FeedUrlInput
          feedUrls={initialConfig?.feedUrls ?? undefined}
          value={feedUrl}
          onChange={setFeedUrl}
          isLoading={feedQuery.isLoading}
        />
      </div>

      {/* Main Content */}
      {isJsonMode ? (
        <FormProvider {...form}>
          <JsonEditor
            value={jsonText}
            onChange={setJsonText}
            className="min-h-[600px]"
          />
        </FormProvider>
      ) : (
        <FormProvider {...form}>
          <PatternSettingsCard configId={configId} />
          <PlaylistSection isNewConfig={isNewConfig} />
          {!isNewConfig && configId && (
            <PatternDangerZone
              patternId={configId}
              displayName={formDisplayName || null}
            />
          )}
        </FormProvider>
      )}

      <ConflictDialog
        open={conflictDetected}
        filePath={conflictPath}
        onReload={handleReload}
        onKeepChanges={handleKeepChanges}
      />
    </div>
  );
}

// -- Header sub-component --

interface EditorHeaderProps {
  configId: string | null;
  displayName: string | null;
  feedUrl: string | null;
  isJsonMode: boolean;
  onBack: () => void;
  onModeToggle: () => void;
}

function EditorHeader({
  configId,
  displayName,
  feedUrl,
  isJsonMode,
  onBack,
  onModeToggle,
}: EditorHeaderProps) {
  const { t } = useTranslation('editor');

  const handleViewFeed = useCallback(() => {
    if (!feedUrl) return;
    const params = new URLSearchParams({ url: feedUrl });
    window.open(`/feeds?${params.toString()}`, '_blank');
  }, [feedUrl]);

  return (
    <div className="flex items-center justify-between mb-6">
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" onClick={onBack}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div>
          <h1 className="text-2xl font-bold">
            {configId ? t('editConfig', { name: displayName || configId }) : t('newConfig')}
          </h1>
        </div>
      </div>
      <div className="flex gap-2">
        <Button
          variant="outline"
          onClick={() => window.open('/docs/schema.html', '_blank')}
        >
          <BookOpen className="mr-2 h-4 w-4" />
          {t('schemaDocs')}
        </Button>
        <Button variant="outline" onClick={onModeToggle}>
          {isJsonMode ? (
            <FormInput className="mr-2 h-4 w-4" />
          ) : (
            <Code className="mr-2 h-4 w-4" />
          )}
          {isJsonMode ? t('formMode') : t('jsonMode')}
        </Button>
        {feedUrl && (
          <Button variant="outline" onClick={handleViewFeed}>
            <ExternalLink className="mr-2 h-4 w-4" />
            {t('viewFeed')}
          </Button>
        )}
      </div>
    </div>
  );
}

// -- Tab trigger sub-component --

interface PlaylistTabTriggerProps {
  index: number;
  control: Control<PatternConfig>;
}

// -- Playlist section (owns useFieldArray — isolated so nested field changes
//    don't re-render EditorLayout) --

function PlaylistSection({ isNewConfig }: { isNewConfig: boolean }) {
  const { t } = useTranslation('editor');
  const form = useFormContext<PatternConfig>();
  const { fields, append, remove, replace } = useFieldArray({
    control: form.control,
    name: 'playlists',
  });
  const [activeTab, setActiveTab] = useState('tab-0');
  const [reorderOpen, setReorderOpen] = useState(false);

  return (
    <>
      <Tabs
        value={activeTab}
        onValueChange={setActiveTab}
        className="mt-6"
      >
        <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_460px] items-center">
          <div className="flex min-w-0 items-center gap-2 flex-wrap">
            <TabsList>
              {fields.map((field, index) => (
                <PlaylistTabTrigger
                  key={field.id}
                  index={index}
                  control={form.control}
                />
              ))}
            </TabsList>
            {2 <= fields.length && (
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => setReorderOpen(true)}
              >
                <ArrowUpDown className="mr-1 h-3 w-3" />
                {t('reorderPlaylists')}
              </Button>
            )}
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => {
                append({ ...DEFAULT_PLAYLIST, priority: fields.length });
                setActiveTab(`tab-${fields.length}`);
              }}
            >
              <Plus className="mr-1 h-3 w-3" />
              {t('add')}
            </Button>
          </div>
          <PreviewDebugStats />
        </div>

        {fields.map((field, index) => (
          <TabsContent key={field.id} value={`tab-${index}`}>
            <PlaylistTabContent
              index={index}
              playlistCount={fields.length}
              isNewConfig={isNewConfig}
              onRemove={() => {
                remove(index);
                const lastIndex = fields.length - 2;
                if (0 <= lastIndex) {
                  setActiveTab(`tab-${Math.min(index, lastIndex)}`);
                }
              }}
              onSelectPlaylist={(targetId, entryIndex) => {
                const playlists = form.getValues('playlists');
                const idx = playlists.findIndex((p) => p.id === targetId);
                if (0 <= idx) {
                  // Stash the chosen entry index so PlaylistTabContent can
                  // adopt it on mount instead of defaulting to 0.
                  useEditorStore
                    .getState()
                    .setPendingEntryIndex(targetId, entryIndex);
                  setActiveTab(`tab-${idx}`);
                }
              }}
            />
          </TabsContent>
        ))}
      </Tabs>

      {fields.length === 0 && (
        <p className="text-sm text-muted-foreground text-center py-12">
          {t('noPlaylists')}
        </p>
      )}

      <PlaylistReorderDialog
        open={reorderOpen}
        onOpenChange={setReorderOpen}
        items={fields.map((field, index) => ({
          id: field.id,
          displayName: form.getValues(`playlists.${index}.displayName`) || t('playlistFallbackName', { number: index + 1 }),
        }))}
        onConfirm={(reordered) => {
          const currentPlaylists = form.getValues('playlists');
          const idToIndex = new Map(fields.map((f, i) => [f.id, i]));
          const newPlaylists = reordered.map((item, newIndex) => ({
            ...currentPlaylists[idToIndex.get(item.id)!],
            priority: newIndex,
          }));
          replace(newPlaylists);
          setActiveTab('tab-0');
        }}
      />
    </>
  );
}

// Isolated components that read preview state from Zustand store.
// Only these re-render when preview data changes, not EditorLayout.

function PreviewDebugStats() {
  const debug = useEditorStore((s) => s.previewData?.debug);
  if (!debug) return null;
  return (
    <div className="border rounded-md px-3 py-1 text-xs">
      <DebugInfoStats debug={debug} />
    </div>
  );
}

function PreviewPendingIndicator() {
  const isPending = useEditorStore((s) => s.previewPending);
  const { t } = useTranslation('editor');
  if (!isPending) return null;
  return (
    <span
      className="inline-flex items-center gap-1.5 text-xs text-muted-foreground"
      aria-live="polite"
    >
      <Loader2 className="h-3.5 w-3.5 animate-spin" />
      {t('previewUpdating', 'Updating preview…')}
    </span>
  );
}

function PlaylistTabTrigger({
  index,
  control,
}: PlaylistTabTriggerProps) {
  const { t } = useTranslation('editor');
  const displayName = useWatch({
    control,
    name: `playlists.${index}.displayName`,
  });
  const playlistId = useWatch({
    control,
    name: `playlists.${index}.id`,
  });
  const previewPlaylist = useEditorStore((s) =>
    s.previewData?.playlists.find((p) => p.id === playlistId) ?? null,
  );
  const name = displayName || t('playlistFallbackName', { number: index + 1 });

  return (
    <TabsTrigger value={`tab-${index}`}>
      {name}
      {previewPlaylist && (
        <Badge variant="secondary" className="ml-1.5">
          {previewPlaylist.episodeCount}
        </Badge>
      )}
    </TabsTrigger>
  );
}
