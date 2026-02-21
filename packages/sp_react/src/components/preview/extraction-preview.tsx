import { useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import type { PreviewPlaylist, PreviewEpisode } from '@/schemas/api-schema.ts';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card.tsx';

interface ExtractionPreviewProps {
  playlist: PreviewPlaylist;
}

function hasEnrichedData(ep: PreviewEpisode): boolean {
  return ep.extractedDisplayName != null || ep.seasonNumber != null || ep.episodeNumber != null;
}

function truncate(text: string, maxLength: number): string {
  if (text.length <= maxLength) {
    return text;
  }
  return text.slice(0, maxLength) + '…';
}

export function ExtractionPreview({ playlist }: ExtractionPreviewProps) {
  const { t } = useTranslation('preview');

  const enrichedEpisodes = useMemo(() => {
    const groups = playlist.groups ?? [];
    return groups
      .flatMap((group) => group.episodes)
      .filter(hasEnrichedData);
  }, [playlist.groups]);

  if (enrichedEpisodes.length === 0) {
    return null;
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm font-medium">{t('extractionResults')}</CardTitle>
      </CardHeader>
      <CardContent>
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b text-left text-muted-foreground">
              <th className="pb-2 pr-4 font-medium">{t('title')}</th>
              <th className="pb-2 pr-4 font-medium">{t('extractedName')}</th>
              <th className="pb-2 pr-4 font-medium">{t('season')}</th>
              <th className="pb-2 font-medium">{t('episode')}</th>
            </tr>
          </thead>
          <tbody>
            {enrichedEpisodes.map((ep) => (
              <tr key={ep.id} className="border-b last:border-0">
                <td className="py-1.5 pr-4 text-muted-foreground">
                  {truncate(ep.title, 40)}
                </td>
                <td className="py-1.5 pr-4">{ep.extractedDisplayName ?? '—'}</td>
                <td className="py-1.5 pr-4">{ep.seasonNumber ?? '—'}</td>
                <td className="py-1.5">{ep.episodeNumber ?? '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </CardContent>
    </Card>
  );
}
