import { Controller, useFieldArray, useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { SortRuleCard, SORT_FIELDS, SORT_ORDERS } from '@/components/editor/sort-rule-card.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Plus } from 'lucide-react';

interface SortFormProps {
  index: number;
}

const EMPTY_RULE = { field: 'playlistNumber', order: 'ascending' } as const;

type SortMode = 'none' | 'simple' | 'composite';

export function SortForm({ index }: SortFormProps) {
  const { control, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}.customSort` as const;

  const contentType = watch(`playlists.${index}.contentType`);
  const isGroupsMode = contentType === 'groups';
  const customSort = watch(prefix);

  const { fields, append, remove } = useFieldArray({
    control,
    // useFieldArray requires the path to the array; it is only active in composite mode
    name: `playlists.${index}.customSort.rules` as `playlists.${number}.customSort.rules`,
  });

  const currentMode: SortMode =
    customSort == null
      ? 'none'
      : customSort.type === 'simple'
        ? 'simple'
        : 'composite';

  function handleModeChange(mode: SortMode) {
    if (mode === currentMode) {
      // Deselect current mode
      setValue(prefix, null);
      return;
    }
    if (mode === 'simple') {
      setValue(prefix, { type: 'simple', field: 'playlistNumber', order: 'ascending' });
    } else if (mode === 'composite') {
      setValue(prefix, { type: 'composite', rules: [{ ...EMPTY_RULE }] });
    } else {
      setValue(prefix, null);
    }
  }

  return (
    <div className="space-y-4">
      <h4 className="text-sm font-medium">{t('sortSection')}</h4>

      {!isGroupsMode ? (
        <p className="text-muted-foreground text-sm">{t('sortDisabledNote')}</p>
      ) : (
        <>
          <div className="space-y-1.5">
            <HintLabel hint="customSort">{t('sortType')}</HintLabel>
            <div className="flex gap-2">
              <Button
                type="button"
                variant={currentMode === 'simple' ? 'default' : 'outline'}
                size="sm"
                onClick={() => handleModeChange('simple')}
              >
                {t('sortSimple')}
              </Button>
              <Button
                type="button"
                variant={currentMode === 'composite' ? 'default' : 'outline'}
                size="sm"
                onClick={() => handleModeChange('composite')}
              >
                {t('sortComposite')}
              </Button>
            </div>
          </div>

          {currentMode === 'simple' && (
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <HintLabel
                  htmlFor={`playlist-${index}-sort-field`}
                  hint="sortField"
                >
                  {t('sortField')}
                </HintLabel>
                <Controller
                  control={control}
                  name={`${prefix}.field` as `playlists.${number}.customSort.field`}
                  render={({ field }) => (
                    <Select
                      value={field.value as string | undefined}
                      onValueChange={field.onChange}
                    >
                      <SelectTrigger id={`playlist-${index}-sort-field`} className="w-full">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {SORT_FIELDS.map((f) => (
                          <SelectItem key={f} value={f} disabled={f === 'progress'}>
                            {t(`sortField_${f}`)}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
              </div>

              <div className="space-y-1.5">
                <HintLabel
                  htmlFor={`playlist-${index}-sort-order`}
                  hint="sortOrder"
                >
                  {t('sortOrder')}
                </HintLabel>
                <Controller
                  control={control}
                  name={`${prefix}.order` as `playlists.${number}.customSort.order`}
                  render={({ field }) => (
                    <Select
                      value={field.value as string | undefined}
                      onValueChange={field.onChange}
                    >
                      <SelectTrigger id={`playlist-${index}-sort-order`} className="w-full">
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
                  )}
                />
              </div>
            </div>
          )}

          {currentMode === 'composite' && (
            <div className="space-y-3">
              {fields.map((field, ruleIndex) => (
                <SortRuleCard
                  key={field.id}
                  playlistIndex={index}
                  ruleIndex={ruleIndex}
                  onRemove={() => remove(ruleIndex)}
                />
              ))}

              <Button
                variant="outline"
                size="sm"
                type="button"
                onClick={() => append({ ...EMPTY_RULE })}
              >
                <Plus className="mr-2 h-4 w-4" />
                {t('addSortRule')}
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
