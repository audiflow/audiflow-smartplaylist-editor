import { useFormContext, useFieldArray } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Label } from '@/components/ui/label.tsx';
import { Textarea } from '@/components/ui/textarea.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Accordion } from '@/components/ui/accordion.tsx';
import { Separator } from '@/components/ui/separator.tsx';
import { PlaylistForm } from '@/components/editor/playlist-form.tsx';
import { Plus } from 'lucide-react';

const DEFAULT_PLAYLIST = {
  id: '',
  displayName: '',
  resolverType: '',
  priority: 0,
  episodeYearHeaders: false,
  showDateRange: false,
} as const;

export function ConfigForm() {
  const { control } = useFormContext<PatternConfig>();
  const { fields, append, remove } = useFieldArray({ control, name: 'playlists' });

  return (
    <div className="space-y-6">
      <PatternSettingsCard />

      <Separator />

      <PlaylistsSection
        fields={fields}
        onAdd={() => append({ ...DEFAULT_PLAYLIST })}
        onRemove={remove}
      />
    </div>
  );
}

// -- Section components --

function PatternSettingsCard() {
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
            <Input id="config-id" {...register('id')} placeholder="pattern-id" />
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
            onCheckedChange={(checked) => setValue('yearGroupedEpisodes', !!checked)}
          />
          <Label htmlFor="config-yearGroupedEpisodes">Year Grouped Episodes</Label>
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

interface PlaylistsSectionProps {
  fields: { id: string }[];
  onAdd: () => void;
  onRemove: (index: number) => void;
}

function PlaylistsSection({ fields, onAdd, onRemove }: PlaylistsSectionProps) {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">Playlists ({fields.length})</h2>
        <Button type="button" variant="outline" onClick={onAdd}>
          <Plus className="mr-2 h-4 w-4" />
          Add Playlist
        </Button>
      </div>

      {0 < fields.length ? (
        <Accordion
          type="multiple"
          defaultValue={fields.map((_, i) => `playlist-${i}`)}
        >
          {fields.map((field, index) => (
            <PlaylistForm
              key={field.id}
              index={index}
              onRemove={() => onRemove(index)}
            />
          ))}
        </Accordion>
      ) : (
        <p className="text-sm text-muted-foreground text-center py-8">
          No playlists yet. Add one to get started.
        </p>
      )}
    </div>
  );
}
