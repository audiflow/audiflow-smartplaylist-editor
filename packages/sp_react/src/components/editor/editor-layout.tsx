import { useState, useCallback, useEffect, useMemo } from 'react';
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

  const form = useForm<PatternConfig>({
    // Cast needed: zodResolver infers the Zod input type (with optional defaults),
    // but the form operates on the output type where defaults are applied.
    resolver: zodResolver(patternConfigSchema) as Resolver<PatternConfig>,
    defaultValues: initialConfig ?? DEFAULT_CONFIG,
  });

  const { fields, append, remove } = useFieldArray({
    control: form.control,
    name: 'playlists',
  });

  const previewMutation = usePreviewMutation();
  const feedQuery = useFeed(feedUrl || null);
  const savePlaylistMutation = useSavePlaylist();
  const savePatternMetaMutation = useSavePatternMeta();

  // Track the config snapshot that was last loaded/saved for conflict detection
  const [lastLoadedConfig, setLastLoadedConfig] = useState<PatternConfig | undefined>(initialConfig);

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
    if (!assembledConfigQuery.data || !isDirty) return;
    if (JSON.stringify(assembledConfigQuery.data) !== JSON.stringify(lastLoadedConfig)) {
      setConflict(`patterns/${configId}`);
    }
  }, [assembledConfigQuery.data]); // eslint-disable-line react-hooks/exhaustive-deps

  // Dirty tracking via form.watch()
  useEffect(() => {
    const subscription = form.watch(() => {
      if (!initialConfig) {
        setDirty(true);
        return;
      }
      const current = form.getValues();
      const changed = JSON.stringify(current) !== JSON.stringify(lastLoadedConfig);
      setDirty(changed);
    });
    return () => subscription.unsubscribe();
  }, [form, lastLoadedConfig, setDirty, initialConfig]);

  const handleModeToggle = useCallback(() => {
    if (!isJsonMode) {
      // Form -> JSON: serialize current form values
      setJsonText(JSON.stringify(form.getValues(), null, 2));
    } else {
      // JSON -> Form: parse and validate
      try {
        const parsed = patternConfigSchema.parse(JSON.parse(jsonText));
        form.reset(parsed);
      } catch (e) {
        toast.error(
          t('toastInvalidJson', { error: e instanceof Error ? e.message : 'Parse error' }),
        );
        return;
      }
    }
    toggleJsonMode();
  }, [isJsonMode, jsonText, form, toggleJsonMode]);

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
    previewMutation.mutate({ config: sanitizeConfig(config), feedUrl });
  }, [isJsonMode, jsonText, form, feedUrl, previewMutation]);

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
    if (!configId || isSaving) return;

    const config = isJsonMode && parsedJsonConfig
      ? parsedJsonConfig
      : form.getValues();

    setSaving(true);
    try {
      for (const playlist of config.playlists) {
        await savePlaylistMutation.mutateAsync({
          patternId: configId,
          playlistId: playlist.id,
          data: playlist,
        });
      }

      await savePatternMetaMutation.mutateAsync({
        patternId: configId,
        data: {
          version: 1,
          id: configId,
          feedUrls: config.feedUrls ?? [],
          yearGroupedEpisodes: config.yearGroupedEpisodes ?? false,
          playlists: config.playlists.map((p) => p.id),
        },
      });

      setLastSavedAt(new Date());
      setLastLoadedConfig(config);
      toast.success(t('toastSaved', 'Saved successfully'));
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
  }, [configId, isSaving, isJsonMode, parsedJsonConfig, form, savePlaylistMutation, savePatternMetaMutation, setSaving, setLastSavedAt, t]);

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
              disabled={!isDirty || isSaving || !configId}
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
          <PatternSettingsCard />

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
  feedUrl: string | null;
  isJsonMode: boolean;
  onBack: () => void;
  onModeToggle: () => void;
}

function EditorHeader({
  configId,
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
            {configId ? t('editConfig', { configId }) : t('newConfig')}
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
