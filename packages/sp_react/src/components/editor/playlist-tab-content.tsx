import { useTranslation } from 'react-i18next';
import type { PreviewPlaylist } from '@/schemas/api-schema.ts';
import { Accordion } from '@/components/ui/accordion.tsx';
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
    <div className="space-y-4 pt-4">
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Config side */}
        <div>
          <Accordion type="multiple" defaultValue={[`playlist-${index}`]}>
            <PlaylistForm index={index} onRemove={onRemove} />
          </Accordion>
        </div>

        {/* Preview side */}
        <div className="space-y-4 lg:sticky lg:top-4 lg:self-start">
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
            <p className="text-sm text-muted-foreground py-8 text-center">
              {t('tabPreviewEmpty')}
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
