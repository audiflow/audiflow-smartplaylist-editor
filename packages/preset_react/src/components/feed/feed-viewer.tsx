import { useState, useMemo, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { useFeed } from '@/api/queries.ts';
import type { FeedEpisode } from '@/schemas/api-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Label } from '@/components/ui/label.tsx';
import { Loader2, ArrowUp, ArrowDown } from 'lucide-react';

type SortField = 'title' | 'seasonNumber' | 'episodeNumber' | 'publishedAt';
type SortDirection = 'asc' | 'desc';

interface FeedViewerProps {
  initialUrl?: string;
}

export function FeedViewer({ initialUrl }: FeedViewerProps) {
  const { t } = useTranslation('feed');
  const [urlInput, setUrlInput] = useState(initialUrl ?? '');
  const [activeUrl, setActiveUrl] = useState(initialUrl ?? '');
  const [search, setSearch] = useState('');
  const [sortField, setSortField] = useState<SortField>('publishedAt');
  const [sortDirection, setSortDirection] = useState<SortDirection>('desc');

  const feedQuery = useFeed(activeUrl || null);

  const handleLoad = useCallback(() => {
    setActiveUrl(urlInput);
  }, [urlInput]);

  const handleSort = useCallback(
    (field: SortField) => {
      if (sortField === field) {
        setSortDirection((prev) => (prev === 'asc' ? 'desc' : 'asc'));
      } else {
        setSortField(field);
        setSortDirection('asc');
      }
    },
    [sortField],
  );

  const filteredAndSorted = useMemo(() => {
    if (!feedQuery.data) return [];

    const lowerSearch = search.toLowerCase();
    const filtered = search
      ? feedQuery.data.filter((ep) =>
          ep.title.toLowerCase().includes(lowerSearch),
        )
      : feedQuery.data;

    return [...filtered].sort((a, b) =>
      compareEpisodes(a, b, sortField, sortDirection),
    );
  }, [feedQuery.data, search, sortField, sortDirection]);

  return (
    <div className="container mx-auto max-w-6xl p-6">
      <h1 className="text-2xl font-bold mb-6">{t('title')}</h1>

      {/* URL input */}
      <div className="flex gap-2 items-end mb-6">
        <div className="flex-1 space-y-1.5">
          <Label htmlFor="feed-url">{t('feedUrl')}</Label>
          <Input
            id="feed-url"
            value={urlInput}
            onChange={(e) => setUrlInput(e.target.value)}
            placeholder="https://example.com/feed.xml"
            onKeyDown={(e) => {
              if (e.key === 'Enter') handleLoad();
            }}
          />
        </div>
        <Button onClick={handleLoad} disabled={!urlInput || feedQuery.isLoading}>
          {feedQuery.isLoading ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            t('load')
          )}
        </Button>
      </div>

      {/* Error state */}
      {feedQuery.error && (
        <div className="text-destructive mb-4">
          {t('loadFailed', { error: feedQuery.error.message })}
        </div>
      )}

      {/* Episode table */}
      {feedQuery.data && (
        <>
          {/* Search + count */}
          <div className="flex items-center gap-4 mb-4">
            <div className="flex-1">
              <Input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder={t('filterPlaceholder')}
              />
            </div>
            <span className="text-sm text-muted-foreground whitespace-nowrap">
              {t('episodeCount', { filtered: filteredAndSorted.length, total: feedQuery.data.length })}
            </span>
          </div>

          <div className="border rounded-md overflow-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50">
                  <SortableHeader
                    label={t('columnTitle')}
                    field="title"
                    currentField={sortField}
                    direction={sortDirection}
                    onSort={handleSort}
                  />
                  <SortableHeader
                    label={t('columnSeason')}
                    field="seasonNumber"
                    currentField={sortField}
                    direction={sortDirection}
                    onSort={handleSort}
                    className="w-24"
                  />
                  <SortableHeader
                    label={t('columnEpisode')}
                    field="episodeNumber"
                    currentField={sortField}
                    direction={sortDirection}
                    onSort={handleSort}
                    className="w-24"
                  />
                  <SortableHeader
                    label={t('columnPublished')}
                    field="publishedAt"
                    currentField={sortField}
                    direction={sortDirection}
                    onSort={handleSort}
                    className="w-44"
                  />
                </tr>
              </thead>
              <tbody>
                {filteredAndSorted.map((episode) => (
                  <EpisodeRow key={episode.id} episode={episode} />
                ))}
                {filteredAndSorted.length === 0 && (
                  <tr>
                    <td
                      colSpan={4}
                      className="text-center py-8 text-muted-foreground"
                    >
                      {t('noEpisodes')}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
}

// -- Sub-components --

interface SortableHeaderProps {
  label: string;
  field: SortField;
  currentField: SortField;
  direction: SortDirection;
  onSort: (field: SortField) => void;
  className?: string;
}

function SortableHeader({
  label,
  field,
  currentField,
  direction,
  onSort,
  className,
}: SortableHeaderProps) {
  const isActive = currentField === field;

  return (
    <th
      className={`px-3 py-2 text-left font-medium cursor-pointer select-none hover:bg-muted/80 ${className ?? ''}`}
      onClick={() => onSort(field)}
    >
      <span className="inline-flex items-center gap-1">
        {label}
        {isActive &&
          (direction === 'asc' ? (
            <ArrowUp className="h-3 w-3" />
          ) : (
            <ArrowDown className="h-3 w-3" />
          ))}
      </span>
    </th>
  );
}

function EpisodeRow({ episode }: { episode: FeedEpisode }) {
  return (
    <tr className="border-b last:border-b-0 hover:bg-muted/30">
      <td className="px-3 py-2">{episode.title}</td>
      <td className="px-3 py-2 text-center">
        {episode.seasonNumber ?? '-'}
      </td>
      <td className="px-3 py-2 text-center">
        {episode.episodeNumber ?? '-'}
      </td>
      <td className="px-3 py-2">
        {episode.publishedAt ? formatDate(episode.publishedAt) : '-'}
      </td>
    </tr>
  );
}

// -- Helpers --

function compareEpisodes(
  a: FeedEpisode,
  b: FeedEpisode,
  field: SortField,
  direction: SortDirection,
): number {
  const valA = a[field];
  const valB = b[field];

  // Nulls always sort last regardless of direction
  if (valA == null && valB == null) return 0;
  if (valA == null) return 1;
  if (valB == null) return -1;

  let result: number;
  if (typeof valA === 'string' && typeof valB === 'string') {
    result = valA.localeCompare(valB, undefined, { numeric: true });
  } else {
    // number comparison using subtraction (avoids > / >=)
    result = (valA as number) - (valB as number);
  }

  return direction === 'asc' ? result : -result;
}

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  } catch {
    return iso;
  }
}
