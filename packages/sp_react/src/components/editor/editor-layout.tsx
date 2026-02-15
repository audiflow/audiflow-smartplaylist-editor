import { useState, useCallback, useEffect, useMemo } from 'react';
import { useNavigate } from '@tanstack/react-router';
import { useForm, FormProvider, type Resolver } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import {
  patternConfigSchema,
  type PatternConfig,
} from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { usePreviewMutation, useFeed } from '@/api/queries.ts';
import { useAutoSave } from '@/hooks/use-auto-save.ts';
import { DraftService } from '@/lib/draft-service.ts';
import type { DraftEntry } from '@/lib/draft-service.ts';
import { merge } from '@/lib/json-merge.ts';
import type { JsonValue } from '@/lib/json-merge.ts';
import { ConfigForm } from '@/components/editor/config-form.tsx';
import { DraftRestoreDialog } from '@/components/editor/draft-restore-dialog.tsx';
import { JsonEditor } from '@/components/editor/json-editor.tsx';
import { FeedUrlInput } from '@/components/editor/feed-url-input.tsx';
import { SubmitDialog } from '@/components/editor/submit-dialog.tsx';
import { PreviewPanel } from '@/components/preview/preview-panel.tsx';
import { Button } from '@/components/ui/button.tsx';
import { ArrowLeft, Code, FormInput } from 'lucide-react';
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
  const [pendingDraft, setPendingDraft] = useState<DraftEntry | null>(() =>
    new DraftService().loadDraft(configId),
  );

  const form = useForm<PatternConfig>({
    // Cast needed: zodResolver infers the Zod input type (with optional defaults),
    // but the form operates on the output type where defaults are applied.
    resolver: zodResolver(patternConfigSchema) as Resolver<PatternConfig>,
    defaultValues: initialConfig ?? DEFAULT_CONFIG,
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

      {/* Main Content: Editor + Preview */}
      <div className="grid gap-6 lg:grid-cols-2">
        <div>
          <FormProvider {...form}>
            {isJsonMode ? (
              <JsonEditor
                value={jsonText}
                onChange={setJsonText}
                className="min-h-[600px]"
              />
            ) : (
              <ConfigForm />
            )}
          </FormProvider>
        </div>

        <div>
          <PreviewPanel
            onRunPreview={handleRunPreview}
            isLoading={previewMutation.isPending}
            result={previewMutation.data ?? null}
            error={previewMutation.error}
          />
        </div>
      </div>

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
  lastAutoSavedAt: Date | null;
  isJsonMode: boolean;
  onBack: () => void;
  onModeToggle: () => void;
  onSubmit: () => void;
}

function EditorHeader({
  configId,
  lastAutoSavedAt,
  isJsonMode,
  onBack,
  onModeToggle,
  onSubmit,
}: EditorHeaderProps) {
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
        <Button onClick={onSubmit}>Submit PR</Button>
      </div>
    </div>
  );
}
