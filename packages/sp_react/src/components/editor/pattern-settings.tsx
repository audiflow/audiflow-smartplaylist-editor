import { useFormContext } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Label } from '@/components/ui/label.tsx';
import { Textarea } from '@/components/ui/textarea.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';

export function PatternSettingsCard() {
  const { register, watch, setValue } = useFormContext<PatternConfig>();

  return (
    <Card>
      <CardHeader>
        <CardTitle>Pattern Settings</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <Label htmlFor="config-id">Config ID</Label>
            <Input
              id="config-id"
              {...register('id')}
              placeholder="pattern-id"
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="config-podcastGuid">Podcast GUID</Label>
            <Input
              id="config-podcastGuid"
              {...register('podcastGuid')}
              placeholder="Optional GUID"
            />
          </div>
        </div>
        <FeedUrlsField />
        <div className="flex items-center gap-2">
          <Checkbox
            id="config-yearGroupedEpisodes"
            checked={watch('yearGroupedEpisodes') ?? false}
            onCheckedChange={(checked) =>
              setValue('yearGroupedEpisodes', !!checked)
            }
          />
          <Label htmlFor="config-yearGroupedEpisodes">
            Year Grouped Episodes
          </Label>
        </div>
      </CardContent>
    </Card>
  );
}

function FeedUrlsField() {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const feedUrls = watch('feedUrls') ?? [];

  return (
    <div className="space-y-1.5">
      <Label htmlFor="config-feedUrls">Feed URLs (comma-separated)</Label>
      <Textarea
        id="config-feedUrls"
        value={feedUrls.join(', ')}
        onChange={(e) => {
          const urls = e.target.value
            .split(',')
            .map((u) => u.trim())
            .filter(Boolean);
          setValue('feedUrls', urls);
        }}
        placeholder="https://example.com/feed1.xml, https://example.com/feed2.xml"
      />
    </div>
  );
}
