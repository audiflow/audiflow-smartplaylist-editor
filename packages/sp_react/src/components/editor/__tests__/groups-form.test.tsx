import { describe, it, expect } from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useForm, FormProvider } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { renderWithProviders } from '@/test-utils.tsx';
import { GroupsForm } from '../groups-form.tsx';

const CONFIG_WITH_GROUPS: PatternConfig = {
  id: 'test',
  displayName: '',
  yearGroupedEpisodes: false,
  playlists: [
    {
      id: 'playlist-1',
      displayName: 'Test Playlist',
      resolverType: 'category',
      playlistStructure: 'grouped',
      priority: 0,
      prependSeasonNumber: false,
      groups: [
        { id: 'group-a', displayName: 'Group A', pattern: 'pattern-a' },
        { id: 'group-b', displayName: 'Group B', pattern: 'pattern-b' },
        { id: 'group-c', displayName: 'Group C', pattern: 'pattern-c' },
      ],
    },
  ],
};

function buildSingleGroupConfig(): PatternConfig {
  return {
    ...CONFIG_WITH_GROUPS,
    playlists: [
      {
        ...CONFIG_WITH_GROUPS.playlists[0],
        groups: [
          { id: 'only', displayName: 'Only Group', pattern: 'p' },
        ],
      },
    ],
  };
}

function FormWrapper({
  children,
  defaultValues,
}: {
  children: React.ReactNode;
  defaultValues: PatternConfig;
}) {
  const form = useForm<PatternConfig>({ defaultValues });
  return <FormProvider {...form}>{children}</FormProvider>;
}

function renderGroupsForm(config: PatternConfig) {
  return renderWithProviders(
    <FormWrapper defaultValues={config}>
      <GroupsForm index={0} />
    </FormWrapper>,
  );
}

describe('GroupsForm', () => {
  it('renders all group cards', () => {
    renderGroupsForm(CONFIG_WITH_GROUPS);

    expect(screen.getByText('Group A')).toBeInTheDocument();
    expect(screen.getByText('Group B')).toBeInTheDocument();
    expect(screen.getByText('Group C')).toBeInTheDocument();
  });

  it('appends a new empty group when add button is clicked', async () => {
    const user = userEvent.setup();
    renderGroupsForm(CONFIG_WITH_GROUPS);

    const addButton = screen.getByRole('button', { name: /add group/i });
    await user.click(addButton);

    // The new card shows the fallback "Display Name" label
    // since displayName is empty
    const displayNameInputs = screen.getAllByRole('textbox');
    const inputCount = displayNameInputs.length;
    // Original 3 groups each have 3 inputs (id, displayName, pattern) = 9
    // New group adds 3 more = 12
    expect(12 <= inputCount).toBe(true);
  });

  it('removes a group card when remove button is clicked', async () => {
    const user = userEvent.setup();
    renderGroupsForm(CONFIG_WITH_GROUPS);

    // Find all remove buttons (sr-only text "Remove")
    const removeButtons = screen.getAllByRole('button', { name: /remove/i });
    // Remove the first group (Group A)
    await user.click(removeButtons[0]);

    await waitFor(() => {
      expect(screen.queryByText('Group A')).not.toBeInTheDocument();
    });
    expect(screen.getByText('Group B')).toBeInTheDocument();
    expect(screen.getByText('Group C')).toBeInTheDocument();
  });

  it('shows reorder button when 2+ groups exist', () => {
    renderGroupsForm(CONFIG_WITH_GROUPS);

    expect(
      screen.getByRole('button', { name: /reorder/i }),
    ).toBeInTheDocument();
  });

  it('hides reorder button when only 1 group exists', () => {
    renderGroupsForm(buildSingleGroupConfig());

    expect(
      screen.queryByRole('button', { name: /reorder/i }),
    ).not.toBeInTheDocument();
  });

  it('allows editing a group id input', async () => {
    const user = userEvent.setup();
    renderGroupsForm(CONFIG_WITH_GROUPS);

    const idInput = screen.getByDisplayValue('group-a');
    await user.clear(idInput);
    await user.type(idInput, 'new-id');

    expect(idInput).toHaveValue('new-id');
  });
});

describe('GroupDefCard via GroupsForm', () => {
  it('disables move up button for the first group', () => {
    renderGroupsForm(CONFIG_WITH_GROUPS);

    const upButtons = screen.getAllByRole('button', {
      name: /move group up/i,
    });
    expect(upButtons[0]).toBeDisabled();
  });

  it('disables move down button for the last group', () => {
    renderGroupsForm(CONFIG_WITH_GROUPS);

    const downButtons = screen.getAllByRole('button', {
      name: /move group down/i,
    });
    const lastIndex = downButtons.length - 1;
    expect(downButtons[lastIndex]).toBeDisabled();
  });

  it('moves a group up when move up is clicked', async () => {
    const user = userEvent.setup();
    renderGroupsForm(CONFIG_WITH_GROUPS);

    // Move Group B (index 1) up
    const upButtons = screen.getAllByRole('button', {
      name: /move group up/i,
    });
    await user.click(upButtons[1]);

    // After moving, Group B should appear before Group A
    // Get all id inputs to check ordering
    await waitFor(() => {
      const idInputs = screen.getAllByDisplayValue(/^group-/);
      expect(idInputs[0]).toHaveValue('group-b');
      expect(idInputs[1]).toHaveValue('group-a');
      expect(idInputs[2]).toHaveValue('group-c');
    });
  });
});
