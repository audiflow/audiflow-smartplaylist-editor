import { useTranslation } from 'react-i18next';
import type { ClaimedEpisode } from '@/schemas/api-schema.ts';
import { Badge } from '@/components/ui/badge.tsx';

interface ClaimedEpisodesSectionProps {
  episodes: ClaimedEpisode[];
}

export function ClaimedEpisodesSection({
  episodes,
}: ClaimedEpisodesSectionProps) {
  const { t } = useTranslation('preview');

  if (episodes.length === 0) return null;

  return (
    <div className="space-y-2">
      <h4 className="text-sm font-medium text-muted-foreground">
        {t('claimedByOthers', { count: episodes.length })}
      </h4>
      <ul className="space-y-1">
        {episodes.map((ep) => (
          <li
            key={ep.id}
            className="flex items-center gap-2 text-sm text-muted-foreground/60"
          >
            <span className="line-through">{ep.title}</span>
            <Badge variant="outline" className="text-xs">
              {t('claimedBy', { name: ep.claimedBy })}
            </Badge>
          </li>
        ))}
      </ul>
    </div>
  );
}
