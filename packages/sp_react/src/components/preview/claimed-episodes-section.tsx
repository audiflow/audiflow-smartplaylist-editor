import type { ClaimedEpisode } from '@/schemas/api-schema.ts';
import { Badge } from '@/components/ui/badge.tsx';

interface ClaimedEpisodesSectionProps {
  episodes: ClaimedEpisode[];
}

export function ClaimedEpisodesSection({
  episodes,
}: ClaimedEpisodesSectionProps) {
  if (episodes.length === 0) return null;

  return (
    <div className="space-y-2">
      <h4 className="text-sm font-medium text-muted-foreground">
        Claimed by other playlists ({episodes.length})
      </h4>
      <ul className="space-y-1">
        {episodes.map((ep) => (
          <li
            key={ep.id}
            className="flex items-center gap-2 text-sm text-muted-foreground/60"
          >
            <span className="line-through">{ep.title}</span>
            <Badge variant="outline" className="text-xs">
              claimed by {ep.claimedBy}
            </Badge>
          </li>
        ))}
      </ul>
    </div>
  );
}
