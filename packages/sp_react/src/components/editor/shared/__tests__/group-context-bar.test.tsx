import { describe, expect, it, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { GroupContextBar } from '@/components/editor/shared/group-context-bar.tsx';

const GROUPS = [
  { id: 'g1', displayName: 'Group 1' },
  { id: 'g2', displayName: 'Group 2' },
];

describe('GroupContextBar', () => {
  it('renders an "All groups" chip plus one chip per group', () => {
    render(
      <GroupContextBar
        groups={GROUPS}
        active="all"
        allLabel="All groups (edit defaults)"
        addLabel="+ Add group"
        onSelect={() => {}}
        onAdd={() => {}}
      />,
    );
    expect(screen.getByRole('button', { name: 'All groups (edit defaults)' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Group 1' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Group 2' })).toBeInTheDocument();
  });

  it('marks the active chip as selected', () => {
    render(
      <GroupContextBar
        groups={GROUPS}
        active="g2"
        allLabel="All groups"
        addLabel="+ Add"
        onSelect={() => {}}
        onAdd={() => {}}
      />,
    );
    const activeChip = screen.getByRole('button', { name: 'Group 2' });
    expect(activeChip).toHaveAttribute('aria-pressed', 'true');
  });

  it('marks inactive chips with aria-pressed="false"', () => {
    render(
      <GroupContextBar
        groups={GROUPS}
        active="g2"
        allLabel="All groups"
        addLabel="+ Add"
        onSelect={() => {}}
        onAdd={() => {}}
      />,
    );
    const inactiveChip = screen.getByRole('button', { name: 'Group 1' });
    expect(inactiveChip).toHaveAttribute('aria-pressed', 'false');
  });

  it('calls onSelect with the chip id when clicked', () => {
    const onSelect = vi.fn();
    render(
      <GroupContextBar
        groups={GROUPS}
        active="all"
        allLabel="All groups"
        addLabel="+ Add"
        onSelect={onSelect}
        onAdd={() => {}}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: 'Group 1' }));
    expect(onSelect).toHaveBeenCalledWith('g1');
  });

  it('calls onAdd when the add chip is clicked', () => {
    const onAdd = vi.fn();
    render(
      <GroupContextBar
        groups={GROUPS}
        active="all"
        allLabel="All groups"
        addLabel="+ Add"
        onSelect={() => {}}
        onAdd={onAdd}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: '+ Add' }));
    expect(onAdd).toHaveBeenCalledTimes(1);
  });
});
