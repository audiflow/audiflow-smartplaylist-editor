import { useFieldArray, useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { SortRuleCard } from '@/components/editor/sort-rule-card.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Plus } from 'lucide-react';

interface SortFormProps {
  index: number;
}

const EMPTY_RULE = { field: 'playlistNumber', order: 'ascending' } as const;

export function SortForm({ index }: SortFormProps) {
  const { control, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}.customSort` as const;

  const contentType = watch(`playlists.${index}.contentType`);
  const isGroupsMode = contentType === 'groups';
  const customSort = watch(prefix);

  const { fields, append, remove } = useFieldArray({
    control,
    name: `playlists.${index}.customSort.rules` as `playlists.${number}.customSort.rules`,
  });

  const isEnabled = customSort != null;

  function handleToggle() {
    if (isEnabled) {
      setValue(prefix, null, { shouldDirty: true });
    } else {
      setValue(prefix, { rules: [{ ...EMPTY_RULE }] }, { shouldDirty: true });
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
            <HintLabel hint="customSort">{t('sortToggle')}</HintLabel>
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
