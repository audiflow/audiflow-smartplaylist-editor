import { useMemo } from 'react';
import { Controller, useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { useFeed } from '@/api/queries.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { Button } from '@/components/ui/button.tsx';
import { RegexTester } from '@/components/editor/regex-tester.tsx';
import { GroupsForm } from '@/components/editor/groups-form.tsx';
import { SortForm } from '@/components/editor/sort-form.tsx';
import { ExtractorsForm } from '@/components/editor/extractors-form.tsx';
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
    <div className="space-y-4">
      <BasicSettings index={index} prefix={prefix} />

      <FilterSettings
        prefix={prefix}
        titleFilter={titleFilter}
        excludeFilter={excludeFilter}
        requireFilter={requireFilter}
        episodeTitles={episodeTitles}
      />

      <BooleanSettings index={index} prefix={prefix} />

      <SortForm index={index} />
      <GroupsForm index={index} />
      <ExtractorsForm index={index} />

      <RemoveButton onRemove={onRemove} />
    </div>
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
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-3">
      <h4 className="text-sm font-medium">{t('basicSettings')}</h4>
      <div className="space-y-4">
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-id`} hint="playlistId">{t('playlistId')}</HintLabel>
          <Input
            id={`playlist-${index}-id`}
            {...register(`${prefix}.id`)}
            placeholder={t('placeholderPlaylistId')}
          />
        </div>
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-displayName`} hint="displayName">{t('displayName')}</HintLabel>
          <Input
            id={`playlist-${index}-displayName`}
            {...register(`${prefix}.displayName`)}
            placeholder={t('placeholderDisplayName')}
          />
        </div>
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-resolverType`} hint="resolverType">{t('resolverType')}</HintLabel>
          <Select
            value={watch(`${prefix}.resolverType`) ?? ''}
            onValueChange={(val) => setValue(`${prefix}.resolverType`, val, { shouldDirty: true })}
          >
            <SelectTrigger id={`playlist-${index}-resolverType`}>
              <SelectValue placeholder={t('selectResolver')} />
            </SelectTrigger>
            <SelectContent className="min-w-[280px]">
              {RESOLVER_TYPES.map((type) => (
                <SelectItem
                  key={type}
                  value={type}
                  description={t(`resolverDesc_${type}`)}
                >
                  {t(`resolverLabel_${type}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-priority`} hint="priority">{t('priority')}</HintLabel>
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
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-3">
      <h4 className="text-sm font-medium">{t('filters')}</h4>
      <div className="space-y-1.5">
        <HintLabel hint="titleFilter">{t('titleFilter')}</HintLabel>
        <Input {...register(`${prefix}.titleFilter`)} placeholder={t('placeholderRegex')} />
        {titleFilter && <RegexTester pattern={titleFilter} variant="include" titles={episodeTitles} />}
      </div>
      <div className="space-y-1.5">
        <HintLabel hint="excludeFilter">{t('excludeFilter')}</HintLabel>
        <Input {...register(`${prefix}.excludeFilter`)} placeholder={t('placeholderRegex')} />
        {excludeFilter && <RegexTester pattern={excludeFilter} variant="exclude" titles={episodeTitles} />}
      </div>
      <div className="space-y-1.5">
        <HintLabel hint="requireFilter">{t('requireFilter')}</HintLabel>
        <Input {...register(`${prefix}.requireFilter`)} placeholder={t('placeholderRegex')} />
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
  const { watch, setValue, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-4">
      <div className="flex gap-6">
        <div className="flex items-center gap-2">
          <Checkbox
            id={`playlist-${index}-episodeYearHeaders`}
            checked={watch(`${prefix}.episodeYearHeaders`) ?? false}
            onCheckedChange={(checked) =>
              setValue(`${prefix}.episodeYearHeaders`, !!checked, { shouldDirty: true })
            }
          />
          <HintLabel htmlFor={`playlist-${index}-episodeYearHeaders`} hint="episodeYearHeaders">
            {t('episodeYearHeaders')}
          </HintLabel>
        </div>
        <div className="flex items-center gap-2">
          <Checkbox
            id={`playlist-${index}-showDateRange`}
            checked={watch(`${prefix}.showDateRange`) ?? false}
            onCheckedChange={(checked) =>
              setValue(`${prefix}.showDateRange`, !!checked, { shouldDirty: true })
            }
          />
          <HintLabel htmlFor={`playlist-${index}-showDateRange`} hint="showDateRange">{t('showDateRange')}</HintLabel>
        </div>
        <div className="flex items-center gap-2">
          <Checkbox
            id={`playlist-${index}-showSortOrderToggle`}
            checked={watch(`${prefix}.showSortOrderToggle`) ?? false}
            onCheckedChange={(checked) =>
              setValue(`${prefix}.showSortOrderToggle`, !!checked, { shouldDirty: true })
            }
          />
          <HintLabel htmlFor={`playlist-${index}-showSortOrderToggle`} hint="showSortOrderToggle">{t('showSortOrderToggle')}</HintLabel>
        </div>
      </div>
      <div className="space-y-2">
        <HintLabel htmlFor={`${prefix}.yearHeaderMode`} hint="yearHeaderMode">
          {t('yearHeaderMode')}
        </HintLabel>
        <Controller
          name={`${prefix}.yearHeaderMode`}
          control={control}
          render={({ field }) => (
            <Select
              value={field.value ?? 'none'}
              onValueChange={(v) => field.onChange(v === 'none' ? null : v)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">{t('yearHeaderMode_none')}</SelectItem>
                <SelectItem value="firstEpisode">{t('yearHeaderMode_firstEpisode')}</SelectItem>
                <SelectItem value="perEpisode">{t('yearHeaderMode_perEpisode')}</SelectItem>
              </SelectContent>
            </Select>
          )}
        />
      </div>
    </div>
  );
}

function RemoveButton({ onRemove }: { onRemove: () => void }) {
  const { t } = useTranslation('editor');

  return (
    <div className="flex justify-end">
      <Button variant="destructive" size="sm" type="button" onClick={onRemove}>
        <Trash2 className="mr-2 h-4 w-4" />
        {t('removePlaylist')}
      </Button>
    </div>
  );
}
