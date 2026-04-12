import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, SortField, SortOrder } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { Button } from '@/components/ui/button.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';

// Legacy props (index-based) are kept for backward compatibility.
// New callers should prefer fieldPath + idPrefix.
type SortFormProps =
  | { index: number; fieldPath?: never; idPrefix?: never }
  | { fieldPath: string; idPrefix: string; index?: never };

const SORT_FIELDS = [
  'playlistNumber',
  'newestEpisodeDate',
  'alphabetical',
] as const;

const SORT_ORDERS = ['ascending', 'descending'] as const;

const DEFAULT_SORT_RULE = { field: 'playlistNumber', order: 'ascending' } as const;

export function SortForm(props: SortFormProps) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  // Resolve the field paths: support legacy index-based and new fieldPath-based calling.
  const resolvedFieldPath = 'fieldPath' in props && props.fieldPath != null
    ? props.fieldPath
    : `playlists.${props.index}.groupListing.sort`;

  const resolvedIdPrefix = 'idPrefix' in props && props.idPrefix != null
    ? props.idPrefix
    : `sort-${'index' in props ? props.index : ''}`;

  const sort = watch(resolvedFieldPath as never) as { field: SortField; order: SortOrder } | undefined;
  const isEnabled = sort != null;

  function handleToggle() {
    if (isEnabled) {
      setValue(resolvedFieldPath as never, undefined as never, { shouldDirty: true });
    } else {
      setValue(resolvedFieldPath as never, { ...DEFAULT_SORT_RULE } as never, { shouldDirty: true });
    }
  }

  return (
    <div className="rounded-lg border border-border p-4 space-y-3">
      <div className="flex items-center justify-between">
        <HintLabel hint="groupListSort">{t('sortToggle')}</HintLabel>
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
              hint="sortField"
            >
              {t('sortField')}
            </HintLabel>
            <Select
              value={sort?.field ?? 'playlistNumber'}
              onValueChange={(val) =>
                setValue(`${resolvedFieldPath}.field` as never, val as SortField, { shouldDirty: true })
              }
            >
              <SelectTrigger id={`${resolvedIdPrefix}-field`} className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {SORT_FIELDS.map((f) => (
                  <SelectItem key={f} value={f}>
                    {t(`sortField_${f}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`${resolvedIdPrefix}-order`}
              hint="sortOrder"
            >
              {t('sortOrder')}
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
