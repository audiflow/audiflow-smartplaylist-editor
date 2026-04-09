import { useTranslation } from 'react-i18next';
import type { FeedEpisode } from '@/schemas/api-schema.ts';

interface FilteredEpisodesPanelProps {
  episodes: readonly FeedEpisode[];
  totalCount: number;
}

export function FilteredEpisodesPanel({
  episodes,
  totalCount,
}: FilteredEpisodesPanelProps) {
  const { t } = useTranslation('preview');

  if (episodes.length === 0) {
    return (
      <p className="text-sm text-muted-foreground py-4 text-center">
        {t('emptyFiltered')}
      </p>
    );
  }

  return (
    <div className="space-y-1">
      <p className="text-xs text-muted-foreground mb-2">
        {t('filteredCount', { filtered: episodes.length, total: totalCount })}
      </p>
      <ul className="space-y-1">
        {episodes.map((ep) => (
          <li
            key={ep.id}
            className="text-sm py-1.5 px-2 rounded hover:bg-muted/50"
          >
            <span className="text-foreground">{ep.title}</span>
            {ep.publishedAt && (
              <span className="text-muted-foreground ml-2 text-xs">
                {ep.publishedAt}
              </span>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
