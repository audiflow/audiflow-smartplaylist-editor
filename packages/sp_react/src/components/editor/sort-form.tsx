import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, SortOrder } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { Button } from '@/components/ui/button.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';

type SortScope = 'group' | 'episode';

// Legacy props (index-based) are kept for backward compatibility.
// New callers should prefer fieldPath + idPrefix.
type SortFormProps =
  | { index: number; fieldPath?: never; idPrefix?: never; scope?: SortScope }
  | { fieldPath: string; idPrefix: string; scope?: SortScope; index?: never };

const GROUP_SORT_FIELDS = ['playlistNumber', 'newestEpisodeDate', 'alphabetical'] as const;
const EPISODE_SORT_FIELDS = ['publishedAt', 'episodeNumber', 'title'] as const;

const SORT_ORDERS = ['ascending', 'descending'] as const;

type GroupSortField = (typeof GROUP_SORT_FIELDS)[number];
type EpisodeSortField = (typeof EPISODE_SORT_FIELDS)[number];

const LABELS = {
  group: {
    toggle: 'sortToggle',
    field: 'sortField',
    order: 'sortOrder',
    fieldPrefix: 'sortField_',
    hint: 'groupListSort',
    defaultField: 'playlistNumber' as GroupSortField,
  },
  episode: {
    toggle: 'episodeListSort',
    field: 'episodeSortField',
    order: 'episodeSortOrder',
    fieldPrefix: 'episodeSortField_',
    hint: 'episodeListSort',
    defaultField: 'publishedAt' as EpisodeSortField,
  },
} as const;

export function SortForm(props: SortFormProps) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const scope: SortScope = props.scope ?? 'group';
  const labels = LABELS[scope];
  const sortFields = scope === 'episode' ? EPISODE_SORT_FIELDS : GROUP_SORT_FIELDS;

  // Resolve the field paths: support legacy index-based and new fieldPath-based calling.
  const resolvedFieldPath = 'fieldPath' in props && props.fieldPath != null
    ? props.fieldPath
    : `playlists.${props.index}.groupListing.sort`;

  const resolvedIdPrefix = 'idPrefix' in props && props.idPrefix != null
    ? props.idPrefix
    : `sort-${'index' in props ? props.index : ''}`;

  const sort = watch(resolvedFieldPath as never) as { field: string; order: SortOrder } | undefined;
  const isEnabled = sort != null;

  function handleToggle() {
    if (isEnabled) {
      setValue(resolvedFieldPath as never, undefined as never, { shouldDirty: true });
    } else {
      setValue(
        resolvedFieldPath as never,
        { field: labels.defaultField, order: 'ascending' } as never,
        { shouldDirty: true },
      );
    }
  }

  return (
    <div className="rounded-lg border border-border p-4 space-y-3">
      <div className="flex items-center justify-between">
        <HintLabel hint={labels.hint}>{t(labels.toggle)}</HintLabel>
        <Button
          type="button"
          variant={isEnabled ? 'default' : 'outline'}
          size="sm"
          onClick={handleToggle}
        >
          {isEnabled ? t('sortEnabled') : t('sortDisabled')}
        </Button>
      </div>

      {isEnabled && (
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`${resolvedIdPrefix}-field`}
              hint={labels.field}
            >
              {t(labels.field)}
            </HintLabel>
            <Select
              value={sort?.field ?? labels.defaultField}
              onValueChange={(val) =>
                setValue(`${resolvedFieldPath}.field` as never, val as never, { shouldDirty: true })
              }
            >
              <SelectTrigger id={`${resolvedIdPrefix}-field`} className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {sortFields.map((f) => (
                  <SelectItem key={f} value={f}>
                    {t(`${labels.fieldPrefix}${f}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`${resolvedIdPrefix}-order`}
              hint={labels.order}
            >
              {t(labels.order)}
            </HintLabel>
            <Select
              value={sort?.order ?? 'ascending'}
              onValueChange={(val) =>
                setValue(`${resolvedFieldPath}.order` as never, val as SortOrder, { shouldDirty: true })
              }
            >
              <SelectTrigger id={`${resolvedIdPrefix}-order`} className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {SORT_ORDERS.map((o) => (
                  <SelectItem key={o} value={o}>
                    {t(`sortOrder_${o}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>
      )}
    </div>
  );
}
