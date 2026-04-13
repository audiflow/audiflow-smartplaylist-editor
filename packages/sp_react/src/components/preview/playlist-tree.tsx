import { useMemo } from 'react';
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
import { sortEpisodes } from '@/components/preview/episode-sort-utils.ts';
import type { EpisodeSortRule } from '@/components/preview/episode-sort-utils.ts';

interface PlaylistTreeProps {
  playlists: PreviewPlaylist[];
  prependSeasonNumber?: boolean;
  yearBinding?: YearBinding;
  /** Per-group yearBinding overrides keyed by group id. */
  groupYearBindingOverrides?: ReadonlyMap<string, YearBinding>;
  /** Per-group episode sort rules keyed by group id. Playlist-level default uses key '_default'. */
  episodeSortRules?: ReadonlyMap<string, EpisodeSortRule>;
}

export function PlaylistTree({
  playlists,
  prependSeasonNumber = false,
  yearBinding = 'none',
  groupYearBindingOverrides,
  episodeSortRules,
}: PlaylistTreeProps) {
  const { t } = useTranslation('preview');

  return (
    <div data-preview-region="group-list" className="w-full space-y-4">
      {playlists.map((playlist) => (
        <div key={playlist.id}>
          {playlist.groups && 0 < playlist.groups.length ? (
            <YearAwareGroupList
              groups={playlist.groups}
              prependSeasonNumber={prependSeasonNumber}
              yearBinding={yearBinding}
              groupYearBindingOverrides={groupYearBindingOverrides}
              episodeSortRules={episodeSortRules}
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
  groupYearBindingOverrides,
  episodeSortRules,
}: {
  groups: PreviewGroup[];
  prependSeasonNumber: boolean;
  yearBinding: YearBinding;
  groupYearBindingOverrides?: ReadonlyMap<string, YearBinding>;
  episodeSortRules?: ReadonlyMap<string, EpisodeSortRule>;
}) {
  const yearSections = groupByYear(groups, yearBinding, groupYearBindingOverrides);

  if (!yearSections) {
    return <GroupList groups={groups} prependSeasonNumber={prependSeasonNumber} episodeSortRules={episodeSortRules} />;
  }

  return (
    <div className="space-y-4">
      {yearSections.map((section) => (
        <YearSection
          key={section.year}
          year={section.year}
          entries={section.entries}
          prependSeasonNumber={prependSeasonNumber}
          episodeSortRules={episodeSortRules}
        />
      ))}
    </div>
  );
}

function YearSection({
  year,
  entries,
  prependSeasonNumber,
  episodeSortRules,
}: {
  year: number;
  entries: YearGroupEntry[];
  prependSeasonNumber: boolean;
  episodeSortRules?: ReadonlyMap<string, EpisodeSortRule>;
}) {
  const { t } = useTranslation('preview');

  return (
    <div>
      <div data-preview-field="group-year-sections" className="sticky top-12 z-10 bg-muted/80 backdrop-blur-sm px-2 py-1.5 border-b">
        <span className="text-sm font-semibold">
          {year === 0 ? t('yearUnknown') : t('yearHeader', { year })}
        </span>
      </div>
      <YearGroupEntryList entries={entries} prependSeasonNumber={prependSeasonNumber} episodeSortRules={episodeSortRules} />
    </div>
  );
}

function YearGroupEntryList({
  entries,
  prependSeasonNumber,
  episodeSortRules,
}: {
  entries: YearGroupEntry[];
  prependSeasonNumber: boolean;
  episodeSortRules?: ReadonlyMap<string, EpisodeSortRule>;
}) {
  const { t } = useTranslation('preview');

  return (
    <Accordion type="multiple" className="ml-4">
      {entries.map((entry, idx) => (
        <AccordionItem data-preview-field="group-list-order" key={`${entry.group.id}-${idx}`} value={`${entry.group.id}-${idx}`}>
          <AccordionTrigger>
            <div className="flex items-center gap-2">
              <span data-preview-field="group-card-season-prefix">{formatGroupName(entry.group, prependSeasonNumber)}</span>
              <Badge variant="secondary">
                {t('episodes', { count: entry.episodeCount })}
              </Badge>
            </div>
          </AccordionTrigger>
          <AccordionContent>
            {entry.group.subGroups && 0 < entry.group.subGroups.length ? (
              <SubGroupList
                subGroups={entry.group.subGroups}
                episodeSortRules={episodeSortRules}
              />
            ) : (
              <SortedEpisodeList
                groupId={entry.group.id}
                episodes={entry.filteredEpisodes ?? entry.group.episodes}
                episodeSortRules={episodeSortRules}
              />
            )}
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

function GroupList({
  groups,
  prependSeasonNumber,
  episodeSortRules,
}: {
  groups: PreviewGroup[];
  prependSeasonNumber: boolean;
  episodeSortRules?: ReadonlyMap<string, EpisodeSortRule>;
}) {
  const { t } = useTranslation('preview');

  return (
    <Accordion type="multiple" className="ml-4">
      {groups.map((group) => (
        <AccordionItem data-preview-field="group-list-order" key={group.id} value={group.id}>
          <AccordionTrigger>
            <div className="flex items-center gap-2">
              <span data-preview-field="group-card-season-prefix">{formatGroupName(group, prependSeasonNumber)}</span>
              <Badge variant="secondary">
                {t('episodes', { count: group.episodeCount })}
              </Badge>
            </div>
          </AccordionTrigger>
          <AccordionContent>
            {group.subGroups && 0 < group.subGroups.length ? (
              <SubGroupList
                subGroups={group.subGroups}
                episodeSortRules={episodeSortRules}
              />
            ) : (
              <SortedEpisodeList
                groupId={group.id}
                episodes={group.episodes}
                episodeSortRules={episodeSortRules}
              />
            )}
          </AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}

function SubGroupList({
  subGroups,
  episodeSortRules,
}: {
  subGroups: PreviewGroup[];
  episodeSortRules?: ReadonlyMap<string, EpisodeSortRule>;
}) {
  const { t } = useTranslation('preview');

  return (
    <Accordion type="multiple" className="ml-4">
      {subGroups.map((sub) => (
        <AccordionItem key={sub.id} value={sub.id}>
          <AccordionTrigger>
            <div className="flex items-center gap-2">
              <span>{sub.displayName}</span>
              <Badge variant="outline">
                {t('episodes', { count: sub.episodeCount })}
              </Badge>
            </div>
          </AccordionTrigger>
          <AccordionContent>
            <SortedEpisodeList
              groupId={sub.id}
              episodes={sub.episodes}
              episodeSortRules={episodeSortRules}
            />
          </AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}

/** Resolves per-group or playlist-default sort rule and sorts episodes. */
function SortedEpisodeList({
  groupId,
  episodes,
  episodeSortRules,
}: {
  groupId: string;
  episodes: PreviewEpisode[];
  episodeSortRules?: ReadonlyMap<string, EpisodeSortRule>;
}) {
  const rule = episodeSortRules?.get(groupId) ?? episodeSortRules?.get('_default');
  const sorted = useMemo(
    () => (rule ? sortEpisodes(episodes, rule) : episodes),
    [episodes, rule],
  );
  return <EpisodeList episodes={sorted} />;
}

function EpisodeList({ episodes }: { episodes: PreviewEpisode[] }) {
  return (
    <ul data-preview-field="episode-order" className="ml-4 space-y-0.5 text-sm text-muted-foreground">
      {episodes.map((ep) => (
        <li key={ep.id} className="flex items-center gap-2">
          <span data-preview-field="episode-title" className="truncate" title={ep.title}>{ep.title}</span>
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
