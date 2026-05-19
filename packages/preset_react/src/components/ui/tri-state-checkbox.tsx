import { Checkbox } from '@/components/ui/checkbox';

export type TriState = boolean | undefined;

export function cycleTriState(value: TriState): TriState {
  if (value === undefined) return true;
  if (value === true) return false;
  return undefined;
}

interface TriStateCheckboxProps {
  id: string;
  value: TriState;
  onChange: (next: TriState) => void;
  title?: string;
  'aria-label'?: string;
}

export function TriStateCheckbox({
  id,
  value,
  onChange,
  title,
  'aria-label': ariaLabel,
}: TriStateCheckboxProps) {
  const checked = value === undefined ? 'indeterminate' : value;
  return (
    <Checkbox
      id={id}
      checked={checked}
      onCheckedChange={() => onChange(cycleTriState(value))}
      title={title}
      aria-label={ariaLabel}
    />
  );
}
