import { useTranslation } from 'react-i18next';
import { Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button.tsx';
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
  onLoadFeed: () => void;
  isLoading: boolean;
}

export function FeedUrlInput({
  feedUrls,
  value,
  onChange,
  onLoadFeed,
  isLoading,
}: FeedUrlInputProps) {
  const { t } = useTranslation('editor');
  const hasPredefined = feedUrls && 0 < feedUrls.length;

  return (
    <div className="flex gap-2 items-end">
      <div className="flex-1 space-y-1.5">
        <Label>{t('feedUrl')}</Label>
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
      <Button onClick={onLoadFeed} disabled={!value || isLoading}>
        {isLoading ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : (
          t('loadFeed')
        )}
      </Button>
    </div>
  );
}
