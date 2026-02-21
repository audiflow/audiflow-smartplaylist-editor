import { useTranslation } from 'react-i18next';
import type { PreviewPlaylist } from '@/schemas/api-schema.ts';
import { PlaylistForm } from '@/components/editor/playlist-form.tsx';
import { PlaylistDebugStats } from '@/components/preview/playlist-debug-stats.tsx';
import { ClaimedEpisodesSection } from '@/components/preview/claimed-episodes-section.tsx';
import { PlaylistTree } from '@/components/preview/playlist-tree.tsx';
import { ExtractionPreview } from '@/components/preview/extraction-preview.tsx';

interface PlaylistTabContentProps {
  index: number;
  previewPlaylist: PreviewPlaylist | null;
  onRemove: () => void;
}

export function PlaylistTabContent({
  index,
  previewPlaylist,
  onRemove,
}: PlaylistTabContentProps) {
  const { t } = useTranslation('editor');

  return (
    <div className="pt-2">
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Config side */}
        <div className="space-y-4">
          <PlaylistForm index={index} onRemove={onRemove} />
        </div>

        {/* Preview side */}
        <div className="rounded-lg border bg-muted/30 p-4 space-y-3 lg:sticky lg:top-20 lg:self-start">
          <h4 className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
            {t('previewSectionTitle')}
          </h4>
          {previewPlaylist ? (
            <>
              {previewPlaylist.debug && (
                <PlaylistDebugStats debug={previewPlaylist.debug} />
              )}
              <PlaylistTree playlists={[previewPlaylist]} />
              <ExtractionPreview playlist={previewPlaylist} />
              <ClaimedEpisodesSection
                episodes={previewPlaylist.claimedByOthers ?? []}
              />
            </>
          ) : (
            <p className="text-sm text-muted-foreground py-4 text-center">
              {t('tabPreviewEmpty')}
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
