import { useMemo } from 'react';
import { useFieldArray, useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, YearBinding } from '@/schemas/config-schema.ts';
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
import { Plus, Trash2 } from 'lucide-react';

const RESOLVER_TYPES = [
  'rss',
  'category',
  'year',
  'titleAppearanceOrder',
] as const;

const PLAYLIST_STRUCTURES = ['split', 'grouped'] as const;

interface PlaylistFormProps {
  index: number;
  onRemove: () => void;
}

const EMPTY_TITLES: readonly string[] = [];

export function PlaylistForm({ index, onRemove }: PlaylistFormProps) {
  const prefix = `playlists.${index}` as const;

  const feedUrl = useEditorStore((s) => s.feedUrl);
  const feedQuery = useFeed(feedUrl || null);
  const episodeTitles = useMemo(
    () => feedQuery.data?.map((ep) => ep.title) ?? EMPTY_TITLES,
    [feedQuery.data],
  );

  return (
    <div className="space-y-4">
      <BasicSettings index={index} prefix={prefix} />
      <StructureSettings index={index} prefix={prefix} />

      <FilterSettings
        index={index}
        episodeTitles={episodeTitles}
      />

      <DisplayOptions index={index} prefix={prefix} />

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
  const { register } = useFormContext<PatternConfig>();
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
          <HintLabel htmlFor={`playlist-${index}-priority`} hint="priority">{t('priority')}</HintLabel>
          <Input
            id={`playlist-${index}-priority`}
            type="number"
            {...register(`${prefix}.priority`, {
              setValueAs: (v) =>
                v === '' || v === null || v === undefined
                  ? null
                  : Number(v),
            })}
          />
        </div>
      </div>
    </div>
  );
}

function FilterSettings({
  index,
  episodeTitles,
}: {
  index: number;
  episodeTitles: readonly string[];
}) {
  const { register, watch, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const { fields: requireFields, append: appendRequire, remove: removeRequire } = useFieldArray({
    control,
    name: `playlists.${index}.episodeFilters.require` as `playlists.${number}.episodeFilters.require`,
  });

  const { fields: excludeFields, append: appendExclude, remove: removeExclude } = useFieldArray({
    control,
    name: `playlists.${index}.episodeFilters.exclude` as `playlists.${number}.episodeFilters.exclude`,
  });

  return (
    <div className="space-y-3">
      <h4 className="text-sm font-medium">{t('episodeFilters')}</h4>

      <div className="space-y-3">
        <h5 className="text-xs font-medium text-muted-foreground">{t('requireFilters')}</h5>
        {requireFields.map((field, filterIndex) => {
          const titleValue = watch(`playlists.${index}.episodeFilters.require.${filterIndex}.title`) ?? '';
          return (
            <div key={field.id} className="space-y-1.5">
              <div className="flex items-center gap-2">
                <div className="flex-1 space-y-1.5">
                  <HintLabel hint="filterTitle">{t('filterTitle')}</HintLabel>
                  <Input
                    {...register(`playlists.${index}.episodeFilters.require.${filterIndex}.title`)}
                    placeholder={t('placeholderRegex')}
                  />
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="mt-5"
                  onClick={() => removeRequire(filterIndex)}
                >
                  <Trash2 className="h-4 w-4" />
                  <span className="sr-only">{t('removeFilter')}</span>
                </Button>
              </div>
              {titleValue && <RegexTester pattern={titleValue} variant="include" titles={episodeTitles} />}
            </div>
          );
        })}
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => appendRequire({ title: '' })}
        >
          <Plus className="mr-2 h-4 w-4" />
          {t('addFilter')}
        </Button>
      </div>

      <div className="space-y-3">
        <h5 className="text-xs font-medium text-muted-foreground">{t('excludeFilters')}</h5>
        {excludeFields.map((field, filterIndex) => {
          const titleValue = watch(`playlists.${index}.episodeFilters.exclude.${filterIndex}.title`) ?? '';
          return (
            <div key={field.id} className="space-y-1.5">
              <div className="flex items-center gap-2">
                <div className="flex-1 space-y-1.5">
                  <HintLabel hint="filterTitle">{t('filterTitle')}</HintLabel>
                  <Input
                    {...register(`playlists.${index}.episodeFilters.exclude.${filterIndex}.title`)}
                    placeholder={t('placeholderRegex')}
                  />
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="mt-5"
                  onClick={() => removeExclude(filterIndex)}
                >
                  <Trash2 className="h-4 w-4" />
                  <span className="sr-only">{t('removeFilter')}</span>
                </Button>
              </div>
              {titleValue && <RegexTester pattern={titleValue} variant="exclude" titles={episodeTitles} />}
            </div>
          );
        })}
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => appendExclude({ title: '' })}
        >
          <Plus className="mr-2 h-4 w-4" />
          {t('addFilter')}
        </Button>
      </div>
    </div>
  );
}

function StructureSettings({
  index,
  prefix,
}: {
  index: number;
  prefix: `playlists.${number}`;
}) {
  const { register, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const resolverType = watch(`${prefix}.resolverType`);

  return (
    <div className="space-y-3">
      <h4 className="text-sm font-medium">{t('structureSettings')}</h4>
      <div className="space-y-4">
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-resolverType`} hint="resolverType">
            {t('resolverType')}
          </HintLabel>
          <Select
            value={resolverType ?? ''}
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
          <HintLabel htmlFor={`playlist-${index}-playlistStructure`} hint="playlistStructure">
            {t('playlistStructure')}
          </HintLabel>
          <Select
            value={watch(`${prefix}.playlistStructure`) ?? 'grouped'}
            onValueChange={(val) => setValue(`${prefix}.playlistStructure`, val, { shouldDirty: true })}
          >
            <SelectTrigger id={`playlist-${index}-playlistStructure`} className="w-full">
              <SelectValue placeholder={t('playlistStructure_grouped')} />
            </SelectTrigger>
            <SelectContent>
              {PLAYLIST_STRUCTURES.map((type) => (
                <SelectItem key={type} value={type}>
                  {t(`playlistStructure_${type}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        {resolverType === 'rss' && (
          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`playlist-${index}-nullSeasonGroupKey`}
              hint="nullSeasonGroupKey"
            >
              {t('nullSeasonGroupKey')}
            </HintLabel>
            <Input
              id={`playlist-${index}-nullSeasonGroupKey`}
              type="number"
              {...register(`${prefix}.nullSeasonGroupKey`, {
                setValueAs: (v) =>
                  v === '' || v === null || v === undefined
                    ? null
                    : Number(v),
              })}
            />
          </div>
        )}
      </div>
    </div>
  );
}

function DisplayOptions({
  index,
  prefix,
}: {
  index: number;
  prefix: `playlists.${number}`;
}) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-3">
      <h4 className="text-sm font-medium">{t('displayOptions')}</h4>
      <div className="space-y-4">
        <div className="flex gap-6">
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-showYearHeaders`}
              checked={watch(`${prefix}.episodeList.showYearHeaders`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.episodeList.showYearHeaders`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-showYearHeaders`} hint="showYearHeaders">
              {t('showYearHeaders')}
            </HintLabel>
          </div>
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-showDateRange`}
              checked={watch(`${prefix}.groupList.showDateRange`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.groupList.showDateRange`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-showDateRange`} hint="showDateRange">{t('showDateRange')}</HintLabel>
          </div>
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-userSortable`}
              checked={watch(`${prefix}.groupList.userSortable`) ?? true}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.groupList.userSortable`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-userSortable`} hint="userSortable">{t('userSortable')}</HintLabel>
          </div>
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-prependSeasonNumber`}
              checked={watch(`${prefix}.prependSeasonNumber`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.prependSeasonNumber`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-prependSeasonNumber`} hint="prependSeasonNumber">{t('prependSeasonNumber')}</HintLabel>
          </div>
        </div>
        <div className="space-y-2">
          <HintLabel htmlFor={`${prefix}.groupList.yearBinding`} hint="yearBinding">
            {t('yearBinding')}
          </HintLabel>
          <Select
            value={watch(`${prefix}.groupList.yearBinding`) ?? 'none'}
            onValueChange={(v) => setValue(`${prefix}.groupList.yearBinding`, v === 'none' ? undefined : v as YearBinding, { shouldDirty: true })}
          >
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="none">{t('yearBinding_none')}</SelectItem>
              <SelectItem value="pinToYear">{t('yearBinding_pinToYear')}</SelectItem>
              <SelectItem value="splitByYear">{t('yearBinding_splitByYear')}</SelectItem>
            </SelectContent>
          </Select>
        </div>
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
