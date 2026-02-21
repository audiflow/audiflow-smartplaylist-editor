import { useTranslation } from 'react-i18next';
import type {
  PreviewPlaylist,
  PreviewGroup,
  PreviewEpisode,
} from '@/schemas/api-schema.ts';
import {
  Accordion,
  AccordionItem,
  AccordionTrigger,
  AccordionContent,
} from '@/components/ui/accordion.tsx';
import { Badge } from '@/components/ui/badge.tsx';

interface PlaylistTreeProps {
  playlists: PreviewPlaylist[];
}

export function PlaylistTree({ playlists }: PlaylistTreeProps) {
  const { t } = useTranslation('preview');

  return (
    <Accordion type="multiple" className="w-full">
      {playlists.map((playlist) => (
        <AccordionItem key={playlist.id} value={playlist.id}>
          <AccordionTrigger>
            <div className="flex items-center gap-2">
              <span>{playlist.displayName}</span>
              {playlist.resolverType && (
                <Badge variant="outline">{playlist.resolverType}</Badge>
              )}
              <Badge variant="secondary">
                {t('episodes', { count: playlist.episodeCount })}
              </Badge>
            </div>
          </AccordionTrigger>
          <AccordionContent>
            {playlist.groups && 0 < playlist.groups.length ? (
              <GroupList groups={playlist.groups} />
            ) : (
              <p className="text-sm text-muted-foreground py-2">{t('noGroups')}</p>
            )}
          </AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}

function GroupList({ groups }: { groups: PreviewGroup[] }) {
  const { t } = useTranslation('preview');

  return (
    <Accordion type="multiple" className="ml-4">
      {groups.map((group) => (
        <AccordionItem key={group.id} value={group.id}>
          <AccordionTrigger>
            <div className="flex items-center gap-2">
              <span>{group.displayName}</span>
              <Badge variant="secondary">
                {t('episodes', { count: group.episodeCount })}
              </Badge>
            </div>
          </AccordionTrigger>
          <AccordionContent>
            <EpisodeList episodes={group.episodes} />
          </AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}

function EpisodeList({ episodes }: { episodes: PreviewEpisode[] }) {
  return (
    <ul className="ml-4 space-y-0.5 text-sm text-muted-foreground">
      {episodes.map((ep) => (
        <li key={ep.id} className="flex items-center gap-2">
          <span className="truncate">{ep.title}</span>
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
