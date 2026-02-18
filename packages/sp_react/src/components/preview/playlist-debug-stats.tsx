import { useTranslation } from 'react-i18next';
import type { PlaylistDebug } from '@/schemas/api-schema.ts';
import { Card, CardContent } from '@/components/ui/card.tsx';

interface PlaylistDebugStatsProps {
  debug: PlaylistDebug;
}

export function PlaylistDebugStats({ debug }: PlaylistDebugStatsProps) {
  const { t } = useTranslation('preview');

  return (
    <Card>
      <CardContent className="py-3">
        <div className="flex gap-6 text-sm">
          <div>
            <span className="text-muted-foreground">{t('matchedLabel')}</span>
            <span className="font-medium">{debug.filterMatched}</span>
          </div>
          <div>
            <span className="text-muted-foreground">{t('claimedLabel')}</span>
            <span className="font-medium">{debug.episodeCount}</span>
          </div>
          {0 < debug.claimedByOthersCount && (
            <div>
              <span className="text-muted-foreground">{t('lostLabel')}</span>
              <span className="font-medium text-orange-600">
                {debug.claimedByOthersCount}
              </span>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
