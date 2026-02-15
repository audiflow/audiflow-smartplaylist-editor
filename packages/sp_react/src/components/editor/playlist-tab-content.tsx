import type { PreviewPlaylist } from '@/schemas/api-schema.ts';
import { Accordion } from '@/components/ui/accordion.tsx';
import { PlaylistForm } from '@/components/editor/playlist-form.tsx';
import { PlaylistDebugStats } from '@/components/preview/playlist-debug-stats.tsx';
import { ClaimedEpisodesSection } from '@/components/preview/claimed-episodes-section.tsx';
import { PlaylistTree } from '@/components/preview/playlist-tree.tsx';

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
        <div className="space-y-4">
          {previewPlaylist ? (
            <>
              {previewPlaylist.debug && (
                <PlaylistDebugStats debug={previewPlaylist.debug} />
              )}
              <PlaylistTree playlists={[previewPlaylist]} />
              <ClaimedEpisodesSection
                episodes={previewPlaylist.claimedByOthers ?? []}
              />
            </>
          ) : (
            <p className="text-sm text-muted-foreground py-8 text-center">
              Run preview to see results for this playlist.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
