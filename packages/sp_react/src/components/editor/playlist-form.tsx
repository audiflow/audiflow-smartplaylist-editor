import { useMemo } from 'react';
import { useFormContext } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { useFeed } from '@/api/queries.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { FIELD_HINTS } from '@/components/editor/field-hints.ts';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { Button } from '@/components/ui/button.tsx';
import {
  AccordionItem,
  AccordionTrigger,
  AccordionContent,
} from '@/components/ui/accordion.tsx';
import { RegexTester } from '@/components/editor/regex-tester.tsx';
import { Trash2 } from 'lucide-react';

const RESOLVER_TYPES = [
  'rss',
  'category',
  'year',
  'titleAppearanceOrder',
] as const;

interface PlaylistFormProps {
  index: number;
  onRemove: () => void;
}

const EMPTY_TITLES: readonly string[] = [];

export function PlaylistForm({ index, onRemove }: PlaylistFormProps) {
  const { watch } = useFormContext<PatternConfig>();
  const prefix = `playlists.${index}` as const;

  const displayName = watch(`${prefix}.displayName`) || `Playlist ${index + 1}`;
  const titleFilter = watch(`${prefix}.titleFilter`) ?? '';
  const excludeFilter = watch(`${prefix}.excludeFilter`) ?? '';
  const requireFilter = watch(`${prefix}.requireFilter`) ?? '';

  const feedUrl = useEditorStore((s) => s.feedUrl);
  const feedQuery = useFeed(feedUrl || null);
  const episodeTitles = useMemo(
    () => feedQuery.data?.map((ep) => ep.title) ?? EMPTY_TITLES,
    [feedQuery.data],
  );

  return (
    <AccordionItem value={`playlist-${index}`}>
      <AccordionTrigger>
        <span className="font-medium">{displayName}</span>
      </AccordionTrigger>
      <AccordionContent className="space-y-4 p-4">
        <BasicSettings index={index} prefix={prefix} />

        <FilterSettings
          prefix={prefix}
          titleFilter={titleFilter}
          excludeFilter={excludeFilter}
          requireFilter={requireFilter}
          episodeTitles={episodeTitles}
        />

        <BooleanSettings index={index} prefix={prefix} />

        <AdvancedNote />

        <RemoveButton onRemove={onRemove} />
      </AccordionContent>
    </AccordionItem>
  );
}

// -- Section components --

function BasicSettings({
  index,
  prefix,
}: {
  index: number;
  prefix: `playlists.${number}`;
}) {
  const { register, watch, setValue } = useFormContext<PatternConfig>();

  return (
    <div className="space-y-3">
      <h4 className="text-sm font-medium">Basic Settings</h4>
      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-id`} hint={FIELD_HINTS.playlistId}>ID</HintLabel>
          <Input
            id={`playlist-${index}-id`}
            {...register(`${prefix}.id`)}
            placeholder="playlist-id"
          />
        </div>
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-displayName`} hint={FIELD_HINTS.displayName}>Display Name</HintLabel>
          <Input
            id={`playlist-${index}-displayName`}
            {...register(`${prefix}.displayName`)}
            placeholder="My Playlist"
          />
        </div>
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-resolverType`} hint={FIELD_HINTS.resolverType}>Resolver Type</HintLabel>
          <Select
            value={watch(`${prefix}.resolverType`) ?? ''}
            onValueChange={(val) => setValue(`${prefix}.resolverType`, val)}
          >
            <SelectTrigger id={`playlist-${index}-resolverType`}>
              <SelectValue placeholder="Select resolver" />
            </SelectTrigger>
            <SelectContent>
              {RESOLVER_TYPES.map((type) => (
                <SelectItem key={type} value={type}>
                  {type}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-priority`} hint={FIELD_HINTS.priority}>Priority</HintLabel>
          <Input
            id={`playlist-${index}-priority`}
            type="number"
            {...register(`${prefix}.priority`, { valueAsNumber: true })}
          />
        </div>
      </div>
    </div>
  );
}

function FilterSettings({
  prefix,
  titleFilter,
  excludeFilter,
  requireFilter,
  episodeTitles,
}: {
  prefix: `playlists.${number}`;
  titleFilter: string;
  excludeFilter: string;
  requireFilter: string;
  episodeTitles: readonly string[];
}) {
  const { register } = useFormContext<PatternConfig>();

  return (
    <div className="space-y-3">
      <h4 className="text-sm font-medium">Filters</h4>
      <div className="space-y-1.5">
        <HintLabel hint={FIELD_HINTS.titleFilter}>Title Filter</HintLabel>
        <Input {...register(`${prefix}.titleFilter`)} placeholder="Regex pattern" />
        {titleFilter && <RegexTester pattern={titleFilter} variant="include" titles={episodeTitles} />}
      </div>
      <div className="space-y-1.5">
        <HintLabel hint={FIELD_HINTS.excludeFilter}>Exclude Filter</HintLabel>
        <Input {...register(`${prefix}.excludeFilter`)} placeholder="Regex pattern" />
        {excludeFilter && <RegexTester pattern={excludeFilter} variant="exclude" titles={episodeTitles} />}
      </div>
      <div className="space-y-1.5">
        <HintLabel hint={FIELD_HINTS.requireFilter}>Require Filter</HintLabel>
        <Input {...register(`${prefix}.requireFilter`)} placeholder="Regex pattern" />
        {requireFilter && <RegexTester pattern={requireFilter} variant="include" titles={episodeTitles} />}
      </div>
    </div>
  );
}

function BooleanSettings({
  index,
  prefix,
}: {
  index: number;
  prefix: `playlists.${number}`;
}) {
  const { watch, setValue } = useFormContext<PatternConfig>();

  return (
    <div className="flex gap-6">
      <div className="flex items-center gap-2">
        <Checkbox
          id={`playlist-${index}-episodeYearHeaders`}
          checked={watch(`${prefix}.episodeYearHeaders`) ?? false}
          onCheckedChange={(checked) =>
            setValue(`${prefix}.episodeYearHeaders`, !!checked)
          }
        />
        <HintLabel htmlFor={`playlist-${index}-episodeYearHeaders`} hint={FIELD_HINTS.episodeYearHeaders}>
          Episode Year Headers
        </HintLabel>
      </div>
      <div className="flex items-center gap-2">
        <Checkbox
          id={`playlist-${index}-showDateRange`}
          checked={watch(`${prefix}.showDateRange`) ?? false}
          onCheckedChange={(checked) =>
            setValue(`${prefix}.showDateRange`, !!checked)
          }
        />
        <HintLabel htmlFor={`playlist-${index}-showDateRange`} hint={FIELD_HINTS.showDateRange}>Show Date Range</HintLabel>
      </div>
    </div>
  );
}

function AdvancedNote() {
  return (
    <p className="text-xs text-muted-foreground">
      Advanced fields (groups, extractors, sort) can be edited in JSON mode.
    </p>
  );
}

function RemoveButton({ onRemove }: { onRemove: () => void }) {
  return (
    <div className="flex justify-end">
      <Button variant="destructive" size="sm" type="button" onClick={onRemove}>
        <Trash2 className="mr-2 h-4 w-4" />
        Remove Playlist
      </Button>
    </div>
  );
}
