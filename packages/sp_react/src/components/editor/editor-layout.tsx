import { useState, useCallback, useEffect, useMemo } from 'react';
import { useNavigate } from '@tanstack/react-router';
import { useForm, useFieldArray, FormProvider, type Resolver } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import {
  patternConfigSchema,
  type PatternConfig,
} from '@/schemas/config-schema.ts';
import type { PreviewPlaylist } from '@/schemas/api-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { usePreviewMutation, useFeed } from '@/api/queries.ts';
import { useAutoSave } from '@/hooks/use-auto-save.ts';
import { DraftService } from '@/lib/draft-service.ts';
import type { DraftEntry } from '@/lib/draft-service.ts';
import { merge } from '@/lib/json-merge.ts';
import type { JsonValue } from '@/lib/json-merge.ts';
import { DEFAULT_PLAYLIST } from '@/components/editor/config-form.tsx';
import { PatternSettingsCard } from '@/components/editor/pattern-settings.tsx';
import { PlaylistTabContent } from '@/components/editor/playlist-tab-content.tsx';
import { DraftRestoreDialog } from '@/components/editor/draft-restore-dialog.tsx';
import { JsonEditor } from '@/components/editor/json-editor.tsx';
import { FeedUrlInput } from '@/components/editor/feed-url-input.tsx';
import { SubmitDialog } from '@/components/editor/submit-dialog.tsx';
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
  Code,
  ExternalLink,
  FormInput,
  Loader2,
  Play,
  Plus,
} from 'lucide-react';
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
  const navigate = useNavigate();
  const {
    isJsonMode,
    feedUrl,
    lastAutoSavedAt,
    toggleJsonMode,
    setFeedUrl,
    reset: resetEditorStore,
  } = useEditorStore();
  const [jsonText, setJsonText] = useState('');
  const [submitOpen, setSubmitOpen] = useState(false);
  const [activeTab, setActiveTab] = useState('tab-0');
  const [pendingDraft, setPendingDraft] = useState<DraftEntry | null>(() =>
    new DraftService().loadDraft(configId),
  );

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

  useAutoSave(
    configId,
    initialConfig ?? DEFAULT_CONFIG,
    form.getValues,
    form.watch,
  );

  // Initialize feed URL from config on mount
  useEffect(() => {
    const urls = initialConfig?.feedUrls;
    if (urls && 0 < urls.length) {
      setFeedUrl(urls[0]);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const handleRestoreDraft = useCallback(() => {
    if (!pendingDraft) return;
    try {
      if (initialConfig) {
        // DraftEntry fields are `unknown` but originate from JSON.parse
        const merged = merge({
          base: pendingDraft.base as JsonValue,
          latest: initialConfig as JsonValue,
          modified: pendingDraft.modified as JsonValue,
        });
        const parsed = patternConfigSchema.parse(merged);
        form.reset(parsed);
      } else {
        const parsed = patternConfigSchema.parse(pendingDraft.modified);
        form.reset(parsed);
      }
      new DraftService().clearDraft(configId);
      setPendingDraft(null);
    } catch (e) {
      toast.error(
        'Failed to restore draft: ' +
          (e instanceof Error ? e.message : 'Unknown error'),
      );
    }
  }, [pendingDraft, initialConfig, configId, form]);

  const handleDiscardDraft = useCallback(() => {
    new DraftService().clearDraft(configId);
    setPendingDraft(null);
  }, [configId]);

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
          'Invalid JSON: ' +
            (e instanceof Error ? e.message : 'Parse error'),
        );
        return;
      }
    }
    toggleJsonMode();
  }, [isJsonMode, jsonText, form, toggleJsonMode]);

  const handleRunPreview = useCallback(() => {
    if (!feedUrl) {
      toast.error('Enter a feed URL before running preview');
      return;
    }
    let config: unknown;
    if (isJsonMode) {
      try {
        config = JSON.parse(jsonText);
      } catch {
        toast.error('Invalid JSON: cannot run preview');
        return;
      }
    } else {
      config = form.getValues();
    }
    previewMutation.mutate({ config, feedUrl });
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

  return (
    <div className="container mx-auto max-w-7xl p-6">
      {/* Header */}
      <EditorHeader
        configId={configId}
        feedUrl={feedUrl || null}
        lastAutoSavedAt={lastAutoSavedAt}
        isJsonMode={isJsonMode}
        onBack={() => {
          resetEditorStore();
          void navigate({ to: '/browse' });
        }}
        onModeToggle={handleModeToggle}
        onSubmit={() => setSubmitOpen(true)}
      />

      {/* Feed URL Input */}
      <div className="mb-6">
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

      {/* Preview Controls */}
      <div className="flex items-center justify-between my-4">
        {previewMutation.data?.debug && (
          <DebugInfoPanel debug={previewMutation.data.debug} />
        )}
        {!previewMutation.data?.debug && <div />}
        <Button onClick={handleRunPreview} disabled={previewMutation.isPending}>
          {previewMutation.isPending ? (
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
          ) : (
            <Play className="mr-2 h-4 w-4" />
          )}
          Run Preview
        </Button>
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
                {fields.map((field, index) => {
                  const name =
                    form.watch(`playlists.${index}.displayName`) ||
                    `Playlist ${index + 1}`;
                  const pp = findPreviewPlaylist(index);
                  return (
                    <TabsTrigger key={field.id} value={`tab-${index}`}>
                      {name}
                      {pp && (
                        <Badge variant="secondary" className="ml-1.5">
                          {pp.episodeCount}
                        </Badge>
                      )}
                    </TabsTrigger>
                  );
                })}
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
                Add
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
              No playlists. Click &quot;Add&quot; to create one.
            </p>
          )}
        </FormProvider>
      )}

      {/* Submit Dialog */}
      <SubmitDialog
        open={submitOpen}
        onOpenChange={setSubmitOpen}
        patternId={form.getValues().id || configId || ''}
        playlist={parsedJsonConfig ?? form.getValues()}
      />

      {/* Draft Restore Dialog */}
      {pendingDraft && (
        <DraftRestoreDialog
          savedAt={pendingDraft.savedAt}
          onRestore={handleRestoreDraft}
          onDiscard={handleDiscardDraft}
        />
      )}
    </div>
  );
}

// -- Header sub-component --

interface EditorHeaderProps {
  configId: string | null;
  feedUrl: string | null;
  lastAutoSavedAt: Date | null;
  isJsonMode: boolean;
  onBack: () => void;
  onModeToggle: () => void;
  onSubmit: () => void;
}

function EditorHeader({
  configId,
  feedUrl,
  lastAutoSavedAt,
  isJsonMode,
  onBack,
  onModeToggle,
  onSubmit,
}: EditorHeaderProps) {
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
            {configId ? `Edit: ${configId}` : 'New Config'}
          </h1>
          {lastAutoSavedAt && (
            <p className="text-xs text-muted-foreground">
              Auto-saved at {lastAutoSavedAt.toLocaleTimeString()}
            </p>
          )}
        </div>
      </div>
      <div className="flex gap-2">
        <Button variant="outline" onClick={onModeToggle}>
          {isJsonMode ? (
            <FormInput className="mr-2 h-4 w-4" />
          ) : (
            <Code className="mr-2 h-4 w-4" />
          )}
          {isJsonMode ? 'Form Mode' : 'JSON Mode'}
        </Button>
        {feedUrl && (
          <Button variant="outline" onClick={handleViewFeed}>
            <ExternalLink className="mr-2 h-4 w-4" />
            View Feed
          </Button>
        )}
        <Button onClick={onSubmit}>Submit PR</Button>
      </div>
    </div>
  );
}
