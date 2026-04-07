import { useTranslation } from 'react-i18next';
import type { PodcastSearchResult } from '@/schemas/api-schema.ts';
import type { PodcastSelection } from './search-dialog.tsx';

interface SearchResultItemProps {
  result: PodcastSearchResult;
  onSelect: (selection: PodcastSelection) => void;
}

export function SearchResultItem({ result, onSelect }: SearchResultItemProps) {
  const { t } = useTranslation('common');
  if (!result.feedUrl) return null;

  return (
    <button
      type="button"
      className="flex items-center gap-3 w-full rounded-md p-2 text-left hover:bg-accent/50 transition-colors"
      onClick={() =>
        onSelect({ feedUrl: result.feedUrl!, trackName: result.trackName })
      }
    >
      {result.artworkUrl100 ? (
        <img
          src={result.artworkUrl100}
          alt=""
          className="h-12 w-12 rounded-md object-cover flex-shrink-0"
        />
      ) : (
        <div className="h-12 w-12 rounded-md bg-muted flex-shrink-0" />
      )}
      <div className="min-w-0 flex-1">
        <p className="text-sm font-medium truncate">{result.trackName}</p>
        <p className="text-xs text-muted-foreground truncate">
          {result.artistName}
          {result.primaryGenreName && ` · ${result.primaryGenreName}`}
          {result.trackCount != null &&
            ` · ${t('episodeCount', { count: result.trackCount })}`}
        </p>
      </div>
    </button>
  );
}
