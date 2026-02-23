import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useForm, FormProvider } from 'react-hook-form';
import type { ReactNode } from 'react';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { GroupDefCard } from '../group-def-card.tsx';
import { GroupReorderDialog } from '../group-reorder-dialog.tsx';

// Wrapper that provides FormProvider context for GroupDefCard tests
function FormWrapper({
  children,
  groups,
}: {
  children: (args: { playlistIndex: number }) => ReactNode;
  groups: Array<{ id: string; displayName: string; pattern: string }>;
}) {
  const form = useForm<PatternConfig>({
    defaultValues: {
      id: 'test',
      feedUrls: ['https://example.com/feed.xml'],
      playlists: [
        {
          id: 'playlist-1',
          displayName: 'Test Playlist',
          resolverType: 'category',
          groups,
        },
      ],
    },
  });

  return <FormProvider {...form}>{children({ playlistIndex: 0 })}</FormProvider>;
}

describe('GroupDefCard up/down buttons', () => {
  const groups = [
    { id: 'g1', displayName: 'Group A', pattern: 'a' },
    { id: 'g2', displayName: 'Group B', pattern: 'b' },
    { id: 'g3', displayName: 'Group C', pattern: 'c' },
  ];

  it('disables up button for first item', () => {
    const onMoveUp = vi.fn();
    const onMoveDown = vi.fn();
    render(
      <FormWrapper groups={groups}>
        {({ playlistIndex }) => (
          <GroupDefCard
            playlistIndex={playlistIndex}
            groupIndex={0}
            isFirst={true}
            isLast={false}
            onMoveUp={onMoveUp}
            onMoveDown={onMoveDown}
            onRemove={vi.fn()}
          />
        )}
      </FormWrapper>,
    );

    const upButton = screen.getByRole('button', { name: /move group up/i });
    expect(upButton).toBeDisabled();
  });

  it('disables down button for last item', () => {
    render(
      <FormWrapper groups={groups}>
        {({ playlistIndex }) => (
          <GroupDefCard
            playlistIndex={playlistIndex}
            groupIndex={2}
            isFirst={false}
            isLast={true}
            onMoveUp={vi.fn()}
            onMoveDown={vi.fn()}
            onRemove={vi.fn()}
          />
        )}
      </FormWrapper>,
    );

    const downButton = screen.getByRole('button', { name: /move group down/i });
    expect(downButton).toBeDisabled();
  });

  it('enables both buttons for middle item', () => {
    render(
      <FormWrapper groups={groups}>
        {({ playlistIndex }) => (
          <GroupDefCard
            playlistIndex={playlistIndex}
            groupIndex={1}
            isFirst={false}
            isLast={false}
            onMoveUp={vi.fn()}
            onMoveDown={vi.fn()}
            onRemove={vi.fn()}
          />
        )}
      </FormWrapper>,
    );

    const upButton = screen.getByRole('button', { name: /move group up/i });
    const downButton = screen.getByRole('button', { name: /move group down/i });
    expect(upButton).toBeEnabled();
    expect(downButton).toBeEnabled();
  });

  it('calls onMoveUp when up button is clicked', async () => {
    const onMoveUp = vi.fn();
    render(
      <FormWrapper groups={groups}>
        {({ playlistIndex }) => (
          <GroupDefCard
            playlistIndex={playlistIndex}
            groupIndex={1}
            isFirst={false}
            isLast={false}
            onMoveUp={onMoveUp}
            onMoveDown={vi.fn()}
            onRemove={vi.fn()}
          />
        )}
      </FormWrapper>,
    );

    await userEvent.click(screen.getByRole('button', { name: /move group up/i }));
    expect(onMoveUp).toHaveBeenCalledOnce();
  });

  it('calls onMoveDown when down button is clicked', async () => {
    const onMoveDown = vi.fn();
    render(
      <FormWrapper groups={groups}>
        {({ playlistIndex }) => (
          <GroupDefCard
            playlistIndex={playlistIndex}
            groupIndex={1}
            isFirst={false}
            isLast={false}
            onMoveUp={vi.fn()}
            onMoveDown={onMoveDown}
            onRemove={vi.fn()}
          />
        )}
      </FormWrapper>,
    );

    await userEvent.click(screen.getByRole('button', { name: /move group down/i }));
    expect(onMoveDown).toHaveBeenCalledOnce();
  });
});

describe('GroupReorderDialog', () => {
  const items = [
    { id: 'g1', displayName: 'Group A' },
    { id: 'g2', displayName: 'Group B' },
    { id: 'g3', displayName: 'Group C' },
  ];

  it('renders all group names when open', () => {
    render(
      <GroupReorderDialog
        open={true}
        onOpenChange={vi.fn()}
        items={items}
        onConfirm={vi.fn()}
      />,
    );

    expect(screen.getByText('Group A')).toBeInTheDocument();
    expect(screen.getByText('Group B')).toBeInTheDocument();
    expect(screen.getByText('Group C')).toBeInTheDocument();
  });

  it('calls onConfirm with current order when confirmed', async () => {
    const onConfirm = vi.fn();
    render(
      <GroupReorderDialog
        open={true}
        onOpenChange={vi.fn()}
        items={items}
        onConfirm={onConfirm}
      />,
    );

    await userEvent.click(screen.getByRole('button', { name: /confirm/i }));
    expect(onConfirm).toHaveBeenCalledWith(['g1', 'g2', 'g3']);
  });

  it('does not call onConfirm when cancelled', async () => {
    const onConfirm = vi.fn();
    const onOpenChange = vi.fn();
    render(
      <GroupReorderDialog
        open={true}
        onOpenChange={onOpenChange}
        items={items}
        onConfirm={onConfirm}
      />,
    );

    await userEvent.click(screen.getByRole('button', { name: /cancel/i }));
    expect(onConfirm).not.toHaveBeenCalled();
    expect(onOpenChange).toHaveBeenCalledWith(false);
  });

  it('does not render when closed', () => {
    render(
      <GroupReorderDialog
        open={false}
        onOpenChange={vi.fn()}
        items={items}
        onConfirm={vi.fn()}
      />,
    );

    expect(screen.queryByText('Group A')).not.toBeInTheDocument();
  });
});
