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

interface SortFormProps {
  index: number;
}

const SORT_FIELDS = [
  'playlistNumber',
  'newestEpisodeDate',
  'alphabetical',
] as const;

const SORT_ORDERS = ['ascending', 'descending'] as const;

const DEFAULT_SORT_RULE = { field: 'playlistNumber', order: 'ascending' } as const;

export function SortForm({ index }: SortFormProps) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const playlistStructure = watch(`playlists.${index}.playlistStructure`);
  const isGroupedMode = playlistStructure === 'grouped';
  const sort = watch(`playlists.${index}.groupList.sort`);

  const isEnabled = sort != null;

  function handleToggle() {
    if (isEnabled) {
      setValue(`playlists.${index}.groupList.sort`, undefined, { shouldDirty: true });
    } else {
      setValue(`playlists.${index}.groupList.sort`, { ...DEFAULT_SORT_RULE }, { shouldDirty: true });
    }
  }

  return (
    <div className="space-y-4">
      {!isGroupedMode ? (
        <p className="text-muted-foreground text-sm">{t('sortDisabledNote')}</p>
      ) : (
        <>
          <div className="space-y-1.5">
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
                  htmlFor={`sort-${index}-field`}
                  hint="sortField"
                >
                  {t('sortField')}
                </HintLabel>
                <Select
                  value={sort?.field ?? 'playlistNumber'}
                  onValueChange={(val) =>
                    setValue(`playlists.${index}.groupList.sort.field`, val as SortField, { shouldDirty: true })
                  }
                >
                  <SelectTrigger id={`sort-${index}-field`} className="w-full">
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
                  htmlFor={`sort-${index}-order`}
                  hint="sortOrder"
                >
                  {t('sortOrder')}
                </HintLabel>
                <Select
                  value={sort?.order ?? 'ascending'}
                  onValueChange={(val) =>
                    setValue(`playlists.${index}.groupList.sort.order`, val as SortOrder, { shouldDirty: true })
                  }
                >
                  <SelectTrigger id={`sort-${index}-order`} className="w-full">
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
        </>
      )}
    </div>
  );
}
