import { useTranslation } from 'react-i18next';
import type { PreviewDebug } from '@/schemas/api-schema.ts';
import { Card, CardContent } from '@/components/ui/card.tsx';

interface DebugInfoPanelProps {
  debug: PreviewDebug;
}

export function DebugInfoPanel({ debug }: DebugInfoPanelProps) {
  return (
    <Card>
      <CardContent className="py-3">
        <DebugInfoStats debug={debug} />
      </CardContent>
    </Card>
  );
}

export function DebugInfoStats({ debug }: DebugInfoPanelProps) {
  const { t } = useTranslation('preview');

  return (
    <div className="flex gap-6 text-sm">
      <div>
        <span className="text-muted-foreground">{t('totalLabel')}</span>
        <span className="font-medium">{debug.totalEpisodes}</span>
      </div>
      <div>
        <span className="text-muted-foreground">{t('groupedLabel')}</span>
        <span className="font-medium">{debug.groupedEpisodes}</span>
      </div>
      <div>
        <span className="text-muted-foreground">{t('ungroupedLabel')}</span>
        <span className="font-medium">{debug.ungroupedEpisodes}</span>
      </div>
      {0 < debug.excludedEpisodes && (
        <div>
          <span className="text-muted-foreground">{t('excludedLabel')}</span>
          <span className="font-medium">{debug.excludedEpisodes}</span>
        </div>
      )}
    </div>
  );
}
