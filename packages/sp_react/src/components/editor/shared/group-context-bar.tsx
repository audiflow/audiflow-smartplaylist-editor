import { Plus } from 'lucide-react';
import { cn } from '@/lib/utils.ts';

export interface GroupChipData {
  id: string;
  displayName: string;
}

interface GroupContextBarProps {
  groups: readonly GroupChipData[];
  active: 'all' | string;
  allLabel: string;
  addLabel: string;
  onSelect: (id: 'all' | string) => void;
  onAdd: () => void;
}

export function GroupContextBar({
  groups,
  active,
  allLabel,
  addLabel,
  onSelect,
  onAdd,
}: GroupContextBarProps) {
  return (
    <div role="toolbar" aria-label="Group context" className="flex flex-wrap items-center gap-2">
      <Chip pressed={active === 'all'} onClick={() => onSelect('all')} variant="default-scope">
        {allLabel}
      </Chip>
      {groups.map((g) => (
        <Chip key={g.id} pressed={active === g.id} onClick={() => onSelect(g.id)}>
          {g.displayName}
        </Chip>
      ))}
      <button
        type="button"
        onClick={onAdd}
        className="inline-flex items-center gap-1 rounded-full border px-3 py-1 text-xs transition-colors bg-background hover:bg-accent"
      >
        <Plus className="h-3.5 w-3.5" />
        {addLabel}
      </button>
    </div>
  );
}

interface ChipProps {
  pressed?: boolean;
  onClick: () => void;
  variant?: 'normal' | 'default-scope';
  children: React.ReactNode;
}

function Chip({ pressed, onClick, variant = 'normal', children }: ChipProps) {
  return (
    <button
      type="button"
      aria-pressed={pressed ? 'true' : 'false'}
      onClick={onClick}
      className={cn(
        'rounded-full border px-3 py-1 text-xs transition-colors',
        variant === 'default-scope' && 'italic',
        pressed
          ? 'bg-amber-600 text-white border-amber-600'
          : 'bg-background hover:bg-accent',
      )}
    >
      {children}
    </button>
  );
}
