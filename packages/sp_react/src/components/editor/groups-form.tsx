import { useState } from 'react';
import { useFormContext, useFieldArray } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { GroupDefCard } from '@/components/editor/group-def-card.tsx';
import { GroupReorderDialog } from '@/components/editor/group-reorder-dialog.tsx';
import { SortForm } from '@/components/editor/sort-form.tsx';
import { Button } from '@/components/ui/button.tsx';
import { ArrowUpDown, Plus } from 'lucide-react';

interface GroupsFormProps {
  index: number;
}

const EMPTY_GROUP = { id: '', displayName: '', pattern: '' };

export function GroupsForm({ index }: GroupsFormProps) {
  const { watch, control, getValues } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}` as const;

  const { fields, append, remove, move, replace } = useFieldArray({
    control,
    name: `${prefix}.groups`,
  });

  const [reorderDialogOpen, setReorderDialogOpen] = useState(false);

  const dialogItems = fields.map((field, index) => ({
    id: field.id,
    displayName:
      watch(
        `${prefix}.groups.${index}.displayName` as `playlists.${number}.groups.${number}.displayName`,
      ) || field.id,
  }));

  function handleReorderConfirm(orderedIds: string[]) {
    const currentGroups = getValues(`${prefix}.groups`) ?? [];
    const idToIndex = new Map(fields.map((f, i) => [f.id, i]));
    const reordered = orderedIds.map((id) => currentGroups[idToIndex.get(id)!]);
    replace(reordered);
  }

  return (
    <div className="space-y-4">
      <h4 className="text-sm font-medium">{t('groupsSection')}</h4>

      <SortForm index={index} />

      {1 < fields.length && (
        <Button
          variant="outline"
          size="sm"
          type="button"
          onClick={() => setReorderDialogOpen(true)}
        >
          <ArrowUpDown className="mr-2 h-4 w-4" />
          {t('reorderGroups')}
        </Button>
      )}

      <div className="space-y-2">
        {fields.map((field, groupIndex) => (
          <GroupDefCard
            key={field.id}
            playlistIndex={index}
            groupIndex={groupIndex}
            isFirst={groupIndex === 0}
            isLast={groupIndex === fields.length - 1}
            onMoveUp={() => move(groupIndex, groupIndex - 1)}
            onMoveDown={() => move(groupIndex, groupIndex + 1)}
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

      <GroupReorderDialog
        open={reorderDialogOpen}
        onOpenChange={setReorderDialogOpen}
        items={dialogItems}
        onConfirm={handleReorderConfirm}
      />
    </div>
  );
}
