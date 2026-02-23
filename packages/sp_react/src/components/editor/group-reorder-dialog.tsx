import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core';
import type { DragEndEvent } from '@dnd-kit/core';
import {
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
  arrayMove,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog.tsx';
import { Button } from '@/components/ui/button.tsx';
import { GripVertical } from 'lucide-react';

interface ReorderItem {
  id: string;
  displayName: string;
}

interface GroupReorderDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  items: ReadonlyArray<ReorderItem>;
  onConfirm: (orderedIds: string[]) => void;
}

function SortableGroupItem({ id, displayName }: ReorderItem) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={`flex items-center gap-2 rounded-md border bg-background px-3 py-2 ${isDragging ? 'cursor-grabbing' : 'cursor-grab'}`}
      {...attributes}
      {...listeners}
    >
      <GripVertical className="h-4 w-4 shrink-0 text-muted-foreground" />
      <span className="text-sm">{displayName}</span>
    </div>
  );
}

export function GroupReorderDialog({
  open,
  onOpenChange,
  items,
  onConfirm,
}: GroupReorderDialogProps) {
  const { t } = useTranslation('editor');
  const { t: tc } = useTranslation('common');
  const [localOrder, setLocalOrder] = useState<ReorderItem[]>([]);

  useEffect(() => {
    if (open) {
      setLocalOrder([...items]);
    }
  }, [open, items]);

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    }),
  );

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (over && active.id !== over.id) {
      setLocalOrder((prev) => {
        const oldIndex = prev.findIndex((item) => item.id === active.id);
        const newIndex = prev.findIndex((item) => item.id === over.id);
        return arrayMove(prev, oldIndex, newIndex);
      });
    }
  }

  function handleConfirm() {
    onConfirm(localOrder.map((item) => item.id));
    onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('reorderGroupsTitle')}</DialogTitle>
          <DialogDescription>{t('reorderGroupsDescription')}</DialogDescription>
        </DialogHeader>

        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragEnd={handleDragEnd}
        >
          <SortableContext
            items={localOrder.map((item) => item.id)}
            strategy={verticalListSortingStrategy}
          >
            <div className="space-y-1">
              {localOrder.map((item) => (
                <SortableGroupItem
                  key={item.id}
                  id={item.id}
                  displayName={item.displayName}
                />
              ))}
            </div>
          </SortableContext>
        </DndContext>

        <DialogFooter>
          <Button variant="outline" type="button" onClick={() => onOpenChange(false)}>
            {tc('cancel')}
          </Button>
          <Button type="button" onClick={handleConfirm}>
            {tc('confirm')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
