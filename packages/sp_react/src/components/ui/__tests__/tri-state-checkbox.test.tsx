import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { TriStateCheckbox, cycleTriState } from '../tri-state-checkbox';

describe('cycleTriState', () => {
  it('cycles undefined -> true -> false -> undefined', () => {
    expect(cycleTriState(undefined)).toBe(true);
    expect(cycleTriState(true)).toBe(false);
    expect(cycleTriState(false)).toBeUndefined();
  });

  it('returns to undefined after a full loop', () => {
    let v: boolean | undefined = undefined;
    v = cycleTriState(v);
    v = cycleTriState(v);
    v = cycleTriState(v);
    expect(v).toBeUndefined();
  });
});

describe('TriStateCheckbox', () => {
  it('renders data-state=indeterminate when value is undefined', () => {
    render(<TriStateCheckbox id="t" value={undefined} onChange={() => {}} />);
    expect(screen.getByRole('checkbox')).toHaveAttribute('data-state', 'indeterminate');
  });

  it('renders data-state=checked when value is true', () => {
    render(<TriStateCheckbox id="t" value={true} onChange={() => {}} />);
    expect(screen.getByRole('checkbox')).toHaveAttribute('data-state', 'checked');
  });

  it('renders data-state=unchecked when value is false', () => {
    render(<TriStateCheckbox id="t" value={false} onChange={() => {}} />);
    expect(screen.getByRole('checkbox')).toHaveAttribute('data-state', 'unchecked');
  });

  it('cycles on click: undefined -> true -> false -> undefined', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const { rerender } = render(
      <TriStateCheckbox id="t" value={undefined} onChange={onChange} />,
    );
    await user.click(screen.getByRole('checkbox'));
    expect(onChange).toHaveBeenLastCalledWith(true);

    rerender(<TriStateCheckbox id="t" value={true} onChange={onChange} />);
    await user.click(screen.getByRole('checkbox'));
    expect(onChange).toHaveBeenLastCalledWith(false);

    rerender(<TriStateCheckbox id="t" value={false} onChange={onChange} />);
    await user.click(screen.getByRole('checkbox'));
    expect(onChange).toHaveBeenLastCalledWith(undefined);
  });
});
