import { useTranslation } from 'react-i18next';
import type { PlaylistDebug } from '@/schemas/api-schema.ts';

interface PlaylistDebugStatsProps {
  debug: PlaylistDebug;
}

export function PlaylistDebugStats({ debug }: PlaylistDebugStatsProps) {
  const { t } = useTranslation('preview');

  return (
    <div className="flex gap-4 text-sm border rounded-md px-3 py-1.5">
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
  );
}
