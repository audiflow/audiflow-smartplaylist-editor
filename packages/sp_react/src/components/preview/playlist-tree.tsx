import { useTranslation } from 'react-i18next';
import type {
  PreviewPlaylist,
  PreviewGroup,
  PreviewEpisode,
} from '@/schemas/api-schema.ts';
import type { YearBinding } from '@/schemas/config-schema.ts';
import {
  Accordion,
  AccordionItem,
  AccordionTrigger,
  AccordionContent,
} from '@/components/ui/accordion.tsx';
import { Badge } from '@/components/ui/badge.tsx';
import { groupByYear } from '@/components/preview/year-group-utils.ts';
import type { YearGroupEntry } from '@/components/preview/year-group-utils.ts';

interface PlaylistTreeProps {
  playlists: PreviewPlaylist[];
  prependSeasonNumber?: boolean;
  yearBinding?: YearBinding;
}

export function PlaylistTree({
  playlists,
  prependSeasonNumber = false,
  yearBinding = 'none',
}: PlaylistTreeProps) {
  const { t } = useTranslation('preview');

  return (
    <div className="w-full space-y-4">
      {playlists.map((playlist) => (
        <div key={playlist.id}>
          {playlist.groups && 0 < playlist.groups.length ? (
            <YearAwareGroupList
              groups={playlist.groups}
              prependSeasonNumber={prependSeasonNumber}
              yearBinding={yearBinding}
            />
          ) : (
            <p className="text-sm text-muted-foreground py-2">{t('noGroups')}</p>
          )}
        </div>
      ))}
    </div>
  );
}

function YearAwareGroupList({
  groups,
  prependSeasonNumber,
  yearBinding,
}: {
  groups: PreviewGroup[];
  prependSeasonNumber: boolean;
  yearBinding: YearBinding;
}) {
  const yearSections = groupByYear(groups, yearBinding);

  if (!yearSections) {
    return <GroupList groups={groups} prependSeasonNumber={prependSeasonNumber} />;
  }

  return (
    <div className="space-y-4">
      {yearSections.map((section) => (
        <YearSection
          key={section.year}
          year={section.year}
          entries={section.entries}
          prependSeasonNumber={prependSeasonNumber}
        />
      ))}
    </div>
  );
}

function YearSection({
  year,
  entries,
  prependSeasonNumber,
}: {
  year: number;
  entries: YearGroupEntry[];
  prependSeasonNumber: boolean;
}) {
  const { t } = useTranslation('preview');

  return (
    <div>
      <div className="sticky top-0 z-10 bg-muted/80 backdrop-blur-sm px-2 py-1.5 -mx-2 border-b">
        <span className="text-sm font-semibold">
          {year === 0 ? t('yearUnknown') : t('yearHeader', { year })}
        </span>
      </div>
      <YearGroupEntryList entries={entries} prependSeasonNumber={prependSeasonNumber} />
    </div>
  );
}

function YearGroupEntryList({
  entries,
  prependSeasonNumber,
}: {
  entries: YearGroupEntry[];
  prependSeasonNumber: boolean;
}) {
  const { t } = useTranslation('preview');

  return (
    <Accordion type="multiple" className="ml-4">
      {entries.map((entry, idx) => (
        <AccordionItem key={`${entry.group.id}-${idx}`} value={`${entry.group.id}-${idx}`}>
          <AccordionTrigger>
            <div className="flex items-center gap-2">
              <span>{formatGroupName(entry.group, prependSeasonNumber)}</span>
              <Badge variant="secondary">
                {t('episodes', { count: entry.episodeCount })}
              </Badge>
            </div>
          </AccordionTrigger>
          <AccordionContent>
            <EpisodeList episodes={entry.filteredEpisodes ?? entry.group.episodes} />
          </AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}

function formatGroupName(group: PreviewGroup, prependSeasonNumber: boolean): string {
  if (prependSeasonNumber && typeof group.sortKey === 'number' && group.id.startsWith('season_')) {
    return `S${group.sortKey} ${group.displayName}`;
  }
  return group.displayName;
}

function GroupList({ groups, prependSeasonNumber }: { groups: PreviewGroup[]; prependSeasonNumber: boolean }) {
  const { t } = useTranslation('preview');

  return (
    <Accordion type="multiple" className="ml-4">
      {groups.map((group) => (
        <AccordionItem key={group.id} value={group.id}>
          <AccordionTrigger>
            <div className="flex items-center gap-2">
              <span>{formatGroupName(group, prependSeasonNumber)}</span>
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
