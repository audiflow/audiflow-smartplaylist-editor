import { useTranslation } from 'react-i18next';
import { Loader2 } from 'lucide-react';
import { Input } from '@/components/ui/input.tsx';
import { Label } from '@/components/ui/label.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';

interface FeedUrlInputProps {
  feedUrls?: string[];
  value: string;
  onChange: (url: string) => void;
  isLoading: boolean;
}

export function FeedUrlInput({
  feedUrls,
  value,
  onChange,
  isLoading,
}: FeedUrlInputProps) {
  const { t } = useTranslation('editor');
  const hasPredefined = feedUrls && 0 < feedUrls.length;

  return (
    <div className="space-y-1.5">
      <div className="flex items-center gap-2">
        <Label>{t('feedUrl')}</Label>
        {isLoading && (
          <span
            className="inline-flex items-center gap-1.5 text-xs text-muted-foreground"
            aria-live="polite"
          >
            <Loader2 className="h-3.5 w-3.5 animate-spin" />
            {t('feedLoading', 'Loading feed…')}
          </span>
        )}
      </div>
      {hasPredefined ? (
        <Select value={value} onValueChange={onChange}>
          <SelectTrigger className="w-full">
            <SelectValue placeholder={t('selectFeedUrl')} />
          </SelectTrigger>
          <SelectContent>
            {feedUrls.map((url) => (
              <SelectItem key={url} value={url}>
                {url}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      ) : (
        <Input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={t('placeholderFeedUrl')}
        />
      )}
    </div>
  );
}
