import { useState, useEffect, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { useSearchPodcasts } from '@/api/queries.ts';
import { useDebounce } from '@/hooks/use-debounce.ts';
import { SearchResultItem } from './search-result-item.tsx';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog.tsx';
import { Input } from '@/components/ui/input.tsx';
import { AlertCircle, Loader2, Search } from 'lucide-react';
import { Label } from '@/components/ui/label.tsx';

export interface PodcastSelection {
  feedUrl: string;
  trackName: string;
}

interface SearchDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSelect: (selection: PodcastSelection) => void;
}

export function SearchDialog({
  open,
  onOpenChange,
  onSelect,
}: SearchDialogProps) {
  const { t } = useTranslation('common');
  const [searchTerm, setSearchTerm] = useState('');
  const debouncedTerm = useDebounce(searchTerm, 300);
  const inputRef = useRef<HTMLInputElement>(null);

  const effectiveTerm = open ? debouncedTerm : '';
  const { data, isLoading, isError } = useSearchPodcasts(effectiveTerm);

  // Filter results to only those with a feedUrl
  const results = data?.results.filter((r) => r.feedUrl) ?? [];

  // Reset search when dialog closes
  useEffect(() => {
    if (!open) {
      setSearchTerm('');
    }
  }, [open]);

  // Auto-focus input when dialog opens
  useEffect(() => {
    if (open) {
      // Small delay to wait for dialog animation
      const timer = setTimeout(() => inputRef.current?.focus(), 100);
      return () => clearTimeout(timer);
    }
  }, [open]);

  const handleSelect = (selection: PodcastSelection) => {
    onSelect(selection);
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg h-[80vh] flex flex-col">
        <DialogHeader>
          <DialogTitle>{t('searchPodcasts')}</DialogTitle>
        </DialogHeader>

        <div className="relative">
          <Label htmlFor="podcast-search-input" className="sr-only">
            {t('searchPodcasts')}
          </Label>
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            id="podcast-search-input"
            ref={inputRef}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder={t('searchPodcastsPlaceholder')}
            className="pl-9"
          />
        </div>

        <div className="flex-1 overflow-y-auto min-h-0">
          {isLoading && (
            <div className="flex justify-center py-8">
              <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
            </div>
          )}

          {isError && (
            <div className="flex items-center justify-center gap-2 py-8 text-sm text-destructive">
              <AlertCircle className="h-4 w-4" />
              <span>{t('searchError')}</span>
            </div>
          )}

          {!isLoading && !isError && 0 < effectiveTerm.length && results.length === 0 && (
            <p className="text-center py-8 text-sm text-muted-foreground">
              {t('noSearchResults')}
            </p>
          )}

          {!isLoading && !isError && 0 < results.length && (
            <div className="flex flex-col gap-1">
              {results.map((result) => (
                <SearchResultItem
                  key={result.feedUrl}
                  result={result}
                  onSelect={handleSelect}
                />
              ))}
            </div>
          )}

          {!isLoading && !isError && effectiveTerm.length < 1 && (
            <p className="text-center py-8 text-sm text-muted-foreground">
              {t('searchPodcastsHint')}
            </p>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
