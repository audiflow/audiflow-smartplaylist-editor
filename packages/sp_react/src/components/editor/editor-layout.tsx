import { useState, useCallback, useEffect, useMemo, useRef } from 'react';
import { useNavigate } from '@tanstack/react-router';
import { useForm, useFieldArray, useWatch, FormProvider, type Resolver, type Control } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import {
  patternConfigSchema,
  type PatternConfig,
} from '@/schemas/config-schema.ts';
import type { PreviewPlaylist } from '@/schemas/api-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import {
  usePreviewMutation,
  useFeed,
  useAssembledConfig,
  useSavePlaylist,
  useSavePatternMeta,
  useCreatePattern,
} from '@/api/queries.ts';
import { sanitizeConfig } from '@/lib/sanitize-config.ts';
import { DEFAULT_PLAYLIST } from '@/components/editor/config-form.tsx';
import { PatternSettingsCard } from '@/components/editor/pattern-settings.tsx';
import { PlaylistTabContent } from '@/components/editor/playlist-tab-content.tsx';
import { JsonEditor } from '@/components/editor/json-editor.tsx';
import { ConflictDialog } from '@/components/editor/conflict-dialog.tsx';
import { FeedUrlInput } from '@/components/editor/feed-url-input.tsx';
import { DebugInfoPanel } from '@/components/preview/debug-info-panel.tsx';
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
  BookOpen,
  Code,
  ExternalLink,
  FormInput,
  Loader2,
  Play,
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
  const {
    isJsonMode,
    feedUrl,
    isDirty,
    isSaving,
    conflictDetected,
    conflictPath,
    toggleJsonMode,
    setFeedUrl,
    setDirty,
    setSaving,
    setLastSavedAt,
    setConflict,
    clearConflict,
    reset: resetEditorStore,
  } = useEditorStore();
  const [jsonText, setJsonText] = useState('');
  const [activeTab, setActiveTab] = useState('tab-0');

  // Normalize legacy v3 field names (e.g. episodeExtractor, rss resolver type)
  // through the Zod schema before seeding the form.
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

  const { fields, append, remove } = useFieldArray({
    control: form.control,
    name: 'playlists',
  });

  const previewMutation = usePreviewMutation();
  // Ref avoids `handleRunPreview` changing every render (useMutation returns
  // a new object each render), which would destabilise the auto-preview effect.
  const previewMutationRef = useRef(previewMutation);
  previewMutationRef.current = previewMutation;

  const feedQuery = useFeed(feedUrl || null);
  const savePlaylistMutation = useSavePlaylist();
  const savePatternMetaMutation = useSavePatternMeta();
  const createPatternMutation = useCreatePattern();

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

  // Detect external changes while user has unsaved edits (conflict detection)
  useEffect(() => {
    if (!assembledConfigQuery.data || !isDirty || isSaving) return;
    if (JSON.stringify(assembledConfigQuery.data) !== JSON.stringify(lastLoadedConfig)) {
      setConflict(`patterns/${configId}`);
    }
  }, [assembledConfigQuery.data]); // eslint-disable-line react-hooks/exhaustive-deps

  // Pre-compute normalized reference for dirty comparison.
  // Zod parse applies all defaults (priority: 0, showYearHeaders: false, etc.)
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

  const handleRunPreview = useCallback(() => {
    if (!feedUrl) {
      toast.error(t('toastEnterFeedUrl'));
      return;
    }
    let config: unknown;
    if (isJsonMode) {
      try {
        config = JSON.parse(jsonText);
      } catch {
        toast.error(t('toastInvalidJsonPreview'));
        return;
      }
    } else {
      config = form.getValues();
    }
    previewMutationRef.current.mutate(
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
  }, [isJsonMode, jsonText, form, feedUrl, t]);

  const findPreviewPlaylist = useCallback(
    (index: number): PreviewPlaylist | null => {
      if (!previewMutation.data) return null;
      const definitionId = form.getValues(`playlists.${index}.id`);
      return (
        previewMutation.data.playlists.find((p) => p.id === definitionId) ??
        null
      );
    },
    [previewMutation.data, form],
  );

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

    // Snapshot immediately: form.getValues() returns mutable references to RHF
    // internal state, so clone before any awaits to avoid mid-save mutations.
    const snapshot = structuredClone(
      isJsonMode && parsedJsonConfig ? parsedJsonConfig : form.getValues(),
    );

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
  }, [effectiveId, isSaving, isJsonMode, isNewConfig, parsedJsonConfig, form, createPatternMutation, savePlaylistMutation, savePatternMetaMutation, navigate, setSaving, setDirty, setLastSavedAt, t]);

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

  // Cmd+Enter / Ctrl+Enter keyboard shortcut for preview
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
        e.preventDefault();
        handleRunPreview();
      }
    };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [handleRunPreview]);

  // Auto-run preview when opening an existing config.
  // Uses initialConfig.feedUrls directly (not the Zustand store's feedUrl) to
  // avoid a stale-URL race: the store may still hold the previous config's URL
  // when this effect first fires.
  //
  // The cleanup resets the ref so StrictMode's remount phase can re-fire.
  // StrictMode detaches the mutation observer during cleanup, so the first
  // fire's mutation becomes orphaned; the second fire attaches properly.
  const hasAutoPreviewedRef = useRef(false);
  useEffect(() => {
    if (hasAutoPreviewedRef.current || !configId || !normalizedInitialConfig) return;
    const url = normalizedInitialConfig.feedUrls?.[0];
    if (!url) return;
    hasAutoPreviewedRef.current = true;
    previewMutationRef.current.mutate(
      { config: sanitizeConfig(normalizedInitialConfig), feedUrl: url },
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

  // Conflict resolution: reload from disk
  const handleReload = useCallback(() => {
    if (assembledConfigQuery.data) {
      form.reset(assembledConfigQuery.data);
      setLastLoadedConfig(assembledConfigQuery.data);
      setDirty(false);
    }
    clearConflict();
  }, [assembledConfigQuery.data, form, setDirty, clearConflict]);

  // Conflict resolution: keep current changes
  const handleKeepChanges = useCallback(() => {
    clearConflict();
    // Update lastLoadedConfig so we don't re-trigger conflict
    if (assembledConfigQuery.data) {
      setLastLoadedConfig(assembledConfigQuery.data);
    }
  }, [assembledConfigQuery.data, clearConflict]);

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

        <div className="flex items-center justify-between">
          {previewMutation.data?.debug && (
            <DebugInfoPanel debug={previewMutation.data.debug} />
          )}
          {!previewMutation.data?.debug && <div />}
          <div className="flex items-center gap-2">
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
            <Button onClick={handleRunPreview} disabled={previewMutation.isPending}>
              {previewMutation.isPending ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Play className="mr-2 h-4 w-4" />
              )}
              {t('runPreview')}
            </Button>
          </div>
        </div>
      </div>

      {/* Feed URL Input */}
      <div className="my-6">
        <FeedUrlInput
          feedUrls={initialConfig?.feedUrls ?? undefined}
          value={feedUrl}
          onChange={setFeedUrl}
          onLoadFeed={() => {
            /* feedQuery auto-fetches when feedUrl changes */
          }}
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

          {/* Playlist Tabs */}
          <Tabs
            value={activeTab}
            onValueChange={setActiveTab}
            className="mt-6"
          >
            <div className="flex items-center gap-2">
              <TabsList>
                {fields.map((field, index) => (
                  <PlaylistTabTrigger
                    key={field.id}
                    index={index}
                    control={form.control}
                    previewPlaylist={findPreviewPlaylist(index)}
                  />
                ))}
              </TabsList>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => {
                  append({ ...DEFAULT_PLAYLIST });
                  setActiveTab(`tab-${fields.length}`);
                }}
              >
                <Plus className="mr-1 h-3 w-3" />
                {t('add')}
              </Button>
            </div>

            {fields.map((field, index) => (
              <TabsContent key={field.id} value={`tab-${index}`}>
                <PlaylistTabContent
                  index={index}
                  previewPlaylist={findPreviewPlaylist(index)}
                  ungroupedEpisodes={previewMutation.data?.ungrouped ?? []}
                  excludedEpisodes={previewMutation.data?.excluded ?? []}
                  globalDebug={previewMutation.data?.debug}
                  playlistCount={fields.length}
                  onRemove={() => {
                    remove(index);
                    const lastIndex = fields.length - 2;
                    if (0 <= lastIndex) {
                      setActiveTab(`tab-${Math.min(index, lastIndex)}`);
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
  previewPlaylist: PreviewPlaylist | null;
}

function PlaylistTabTrigger({
  index,
  control,
  previewPlaylist,
}: PlaylistTabTriggerProps) {
  const { t } = useTranslation('editor');
  const displayName = useWatch({
    control,
    name: `playlists.${index}.displayName`,
  });
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
