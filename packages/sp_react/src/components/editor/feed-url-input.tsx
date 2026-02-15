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
  const hasPredefined = feedUrls && 0 < feedUrls.length;

  return (
    <div className="flex gap-2 items-end">
      <div className="flex-1 space-y-1.5">
        <Label>Feed URL</Label>
        {hasPredefined ? (
          <Select value={value} onValueChange={onChange}>
            <SelectTrigger className="w-full">
              <SelectValue placeholder="Select feed URL" />
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
            placeholder="https://example.com/feed.xml"
          />
        )}
      </div>
      <Button onClick={onLoadFeed} disabled={!value || isLoading}>
        {isLoading ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : (
          'Load Feed'
        )}
      </Button>
    </div>
  );
}
