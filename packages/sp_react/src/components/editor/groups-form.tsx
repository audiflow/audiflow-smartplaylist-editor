import { useFormContext, useFieldArray, Controller } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { GroupDefCard } from '@/components/editor/group-def-card.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Plus } from 'lucide-react';

interface GroupsFormProps {
  index: number;
}

const CONTENT_TYPES = ['episodes', 'groups'] as const;

const EMPTY_GROUP = { id: '', displayName: '', pattern: '' };

export function GroupsForm({ index }: GroupsFormProps) {
  const { register, watch, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}` as const;

  const resolverType = watch(`${prefix}.resolverType`);

  const { fields, append, remove } = useFieldArray({
    control,
    name: `${prefix}.groups`,
  });

  return (
    <div className="space-y-4">
      <h4 className="text-sm font-medium">{t('groupsSection')}</h4>

      <div className="space-y-1.5">
        <HintLabel htmlFor={`playlist-${index}-contentType`} hint="contentType">
          {t('contentType')}
        </HintLabel>
        <Controller
          control={control}
          name={`${prefix}.contentType`}
          render={({ field }) => (
            <Select
              value={field.value ?? 'episodes'}
              onValueChange={(val) => {
                // Store null for the default 'episodes' value to keep JSON clean
                field.onChange(val === 'episodes' ? null : val);
              }}
            >
              <SelectTrigger id={`playlist-${index}-contentType`} className="w-full">
                <SelectValue placeholder={t('contentType_episodes')} />
              </SelectTrigger>
              <SelectContent>
                {CONTENT_TYPES.map((type) => (
                  <SelectItem key={type} value={type}>
                    {t(`contentType_${type}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
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
            {...register(`${prefix}.nullSeasonGroupKey`, { valueAsNumber: true })}
          />
        </div>
      )}

      <div className="space-y-2">
        {fields.map((field, groupIndex) => (
          <GroupDefCard
            key={field.id}
            playlistIndex={index}
            groupIndex={groupIndex}
            onRemove={() => remove(groupIndex)}
          />
        ))}
      </div>

      <Button
        variant="outline"
        size="sm"
        type="button"
        onClick={() => append(EMPTY_GROUP)}
      >
        <Plus className="mr-2 h-4 w-4" />
        {t('addGroup')}
      </Button>
    </div>
  );
}
