import { useTranslation } from 'react-i18next';
import type { PreviewPlaylist } from '@/schemas/api-schema.ts';
import { PlaylistForm } from '@/components/editor/playlist-form.tsx';
import { PlaylistDebugStats } from '@/components/preview/playlist-debug-stats.tsx';
import { ClaimedEpisodesSection } from '@/components/preview/claimed-episodes-section.tsx';
import { PlaylistTree } from '@/components/preview/playlist-tree.tsx';
import { ExtractionPreview } from '@/components/preview/extraction-preview.tsx';
import {
  Tabs,
  TabsList,
  TabsTrigger,
  TabsContent,
} from '@/components/ui/tabs.tsx';
import { Badge } from '@/components/ui/badge.tsx';

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
  const { t: tp } = useTranslation('preview');

  const claimedCount = previewPlaylist?.claimedByOthers?.length ?? 0;

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
              <Tabs defaultValue="groups">
                <TabsList>
                  <TabsTrigger value="groups">
                    {tp('tabGroups')}
                    <Badge variant="secondary" className="ml-1.5">
                      {previewPlaylist.episodeCount}
                    </Badge>
                  </TabsTrigger>
                  <TabsTrigger value="extraction">
                    {tp('tabExtraction')}
                  </TabsTrigger>
                  <TabsTrigger value="claimed">
                    {tp('tabClaimed')}
                    {0 < claimedCount && (
                      <Badge variant="secondary" className="ml-1.5">
                        {claimedCount}
                      </Badge>
                    )}
                  </TabsTrigger>
                </TabsList>
                <TabsContent value="groups">
                  <PlaylistTree playlists={[previewPlaylist]} />
                </TabsContent>
                <TabsContent value="extraction">
                  <ExtractionPreview playlist={previewPlaylist} />
                </TabsContent>
                <TabsContent value="claimed">
                  <ClaimedEpisodesSection
                    episodes={previewPlaylist.claimedByOthers ?? []}
                  />
                </TabsContent>
              </Tabs>
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
