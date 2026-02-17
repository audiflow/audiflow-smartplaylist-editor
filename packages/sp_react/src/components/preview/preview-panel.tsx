import { useTranslation } from 'react-i18next';
import type { PreviewResult, PreviewEpisode } from '@/schemas/api-schema.ts';
import { Button } from '@/components/ui/button.tsx';
import { Loader2, Play } from 'lucide-react';
import { PlaylistTree } from './playlist-tree.tsx';
import { DebugInfoPanel } from './debug-info-panel.tsx';

interface PreviewPanelProps {
  onRunPreview: () => void;
  isLoading: boolean;
  result: PreviewResult | null;
  error: Error | null;
}

export function PreviewPanel({
  onRunPreview,
  isLoading,
  result,
  error,
}: PreviewPanelProps) {
  const { t } = useTranslation('preview');

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">{t('title')}</h2>
        <Button onClick={onRunPreview} disabled={isLoading}>
          {isLoading ? (
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
          ) : (
            <Play className="mr-2 h-4 w-4" />
          )}
          {t('runPreview')}
        </Button>
      </div>

      {!result && !isLoading && !error && (
        <p className="text-sm text-muted-foreground py-8 text-center">
          {t('idleMessage')}
        </p>
      )}

      {isLoading && (
        <div className="flex justify-center py-8">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      )}

      {error && (
        <div className="text-center py-4 text-destructive">
          {t('failed', { error: error.message })}
        </div>
      )}

      {result && (
        <div className="space-y-4">
          {result.debug && <DebugInfoPanel debug={result.debug} />}
          <PlaylistTree playlists={result.playlists} />
          {0 < result.ungrouped.length && (
            <div>
              <h3 className="text-sm font-medium mb-2">
                {t('ungroupedEpisodes')}
              </h3>
              <ul className="space-y-1">
                {result.ungrouped.map((ep: PreviewEpisode) => (
                  <li key={ep.id} className="text-sm text-muted-foreground">
                    {ep.title}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
