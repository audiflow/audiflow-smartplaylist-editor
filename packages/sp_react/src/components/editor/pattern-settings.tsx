import { useFormContext } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Textarea } from '@/components/ui/textarea.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { FIELD_HINTS } from '@/components/editor/field-hints.ts';

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
            <HintLabel htmlFor="config-id" hint={FIELD_HINTS.patternId}>Config ID</HintLabel>
            <Input
              id="config-id"
              {...register('id')}
              placeholder="pattern-id"
            />
          </div>
          <div className="space-y-1.5">
            <HintLabel htmlFor="config-podcastGuid" hint={FIELD_HINTS.podcastGuid}>Podcast GUID</HintLabel>
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
          <HintLabel htmlFor="config-yearGroupedEpisodes" hint={FIELD_HINTS.yearGroupedEpisodes}>
            Year Grouped Episodes
          </HintLabel>
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
      <HintLabel htmlFor="config-feedUrls" hint={FIELD_HINTS.feedUrls}>Feed URLs (comma-separated)</HintLabel>
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
