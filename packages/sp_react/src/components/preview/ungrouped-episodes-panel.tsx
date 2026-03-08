import type { PreviewEpisode } from '@/schemas/api-schema.ts';

interface UngroupedEpisodesPanelProps {
  episodes: PreviewEpisode[];
}

export function UngroupedEpisodesPanel({
  episodes,
}: UngroupedEpisodesPanelProps) {
  if (episodes.length === 0) return null;

  return (
    <ul className="space-y-0.5">
      {episodes.map((ep) => (
        <li
          key={ep.id}
          className="flex items-center gap-2 text-sm text-muted-foreground"
        >
          <span className="truncate" title={ep.title}>{ep.title}</span>
          {ep.publishedAt && (
            <span className="text-xs text-muted-foreground/60 shrink-0">
              {new Date(ep.publishedAt).toLocaleDateString()}
            </span>
          )}
        </li>
      ))}
    </ul>
  );
}
