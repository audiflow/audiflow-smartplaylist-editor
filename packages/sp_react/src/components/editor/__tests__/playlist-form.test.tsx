import { describe, it, expect, beforeEach } from 'vitest';
import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useForm, FormProvider } from 'react-hook-form';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';
import { renderWithProviders } from '@/test-utils.tsx';
import { PlaylistForm } from '../playlist-form.tsx';

const DEFAULT_CONFIG: PatternConfig = {
  id: 'test-pattern',
  displayName: 'Test',
  yearGroupedEpisodes: false,
  playlists: [
    {
      id: 'playlist-1',
      displayName: 'Test Playlist',
      resolverType: 'seasonNumber',
      presentation: 'combined',
      priority: 0,
      prependSeasonNumber: false,
      groups: [],
    },
  ],
};

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

function renderPlaylistForm(
  overrides?: Partial<{ index: number; onRemove: () => void; config: PatternConfig; isNewConfig: boolean }>,
) {
  const index = overrides?.index ?? 0;
  const onRemove = overrides?.onRemove ?? vi.fn();
  const config = overrides?.config ?? DEFAULT_CONFIG;
  const isNewConfig = overrides?.isNewConfig;

  return {
    onRemove,
    ...renderWithProviders(
      <FormWrapper defaultValues={config}>
        <PlaylistForm index={index} playlistCount={config.playlists.length} onRemove={onRemove} isNewConfig={isNewConfig} />
      </FormWrapper>,
    ),
  };
}

async function switchToTab(user: ReturnType<typeof userEvent.setup>, tabName: RegExp) {
  const tab = screen.getByRole('tab', { name: tabName });
  await user.click(tab);
}

describe('PlaylistForm', () => {
  beforeEach(() => {
    useEditorStore.getState().reset();
  });

  describe('Tabs', () => {
    it('renders 5 tabs (no separate Groups tab)', () => {
      renderPlaylistForm();
      const tabs = screen.getAllByRole('tab');
      expect(tabs.length).toBe(5);
    });

    it('shows Organize tab as default for saved playlists', () => {
      renderPlaylistForm();
      const resolverTab = screen.getByRole('tab', { name: /organize/i });
      expect(resolverTab).toHaveAttribute('data-state', 'active');
    });

    it('shows Basic tab as default for new configs', () => {
      renderPlaylistForm({ isNewConfig: true });
      const basicTab = screen.getByRole('tab', { name: /basic/i });
      expect(basicTab).toHaveAttribute('data-state', 'active');
    });
  });

  describe('BasicSettings', () => {
    it('renders id input with current value', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /basic/i);
      const input = screen.getByLabelText(/^id$/i);
      expect(input).toBeInTheDocument();
      expect(input).toHaveValue('playlist-1');
    });

    it('renders display name input with current value', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /basic/i);
      const input = screen.getByLabelText(/display name/i);
      expect(input).toHaveValue('Test Playlist');
    });

  });

  describe('StructureSettings', () => {
    it('renders resolver type select', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /organize/i);
      expect(screen.getByText(/how to organize/i)).toBeInTheDocument();
    });

    it('renders presentation select dropdown', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /organize/i);
      expect(screen.getByText(/how groups appear/i)).toBeInTheDocument();
    });

});

  describe('DisplayOptions', () => {
    it('renders showYearHeaders checkbox', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /display/i);
      expect(screen.getByText(/year dividers/i)).toBeInTheDocument();
    });

    it('renders showDateRange checkbox', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /display/i);
      expect(screen.getByText(/date range/i)).toBeInTheDocument();
    });

    it('renders userSortable checkbox', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /display/i);
      expect(screen.getByText(/change sort order/i)).toBeInTheDocument();
    });

    it('renders prependSeasonNumber checkbox', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /display/i);
      expect(
        screen.getByText(/season number to group/i),
      ).toBeInTheDocument();
    });
  });

  describe('RemoveButton', () => {
    it('calls onRemove when danger zone is opened and button clicked', async () => {
      const user = userEvent.setup();
      const { onRemove } = renderPlaylistForm();

      await user.click(screen.getByText(/danger zone/i));
      await user.click(screen.getByText(/remove playlist/i));

      expect(onRemove).toHaveBeenCalledOnce();
    });
  });

  describe('FilterSettings', () => {
    it('renders include and exclude filter sections', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /filters/i);
      expect(screen.getByText(/include episodes/i)).toBeInTheDocument();
      expect(screen.getByText(/exclude episodes/i)).toBeInTheDocument();
    });

    it('adds an include filter entry when add button is clicked', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /filters/i);

      const includeSection = screen
        .getByText(/include episodes/i)
        .closest('div.rounded-lg')!;
      const addButton = within(includeSection).getByText(/add rule/i);

      await user.click(addButton);

      const inputs = within(includeSection).getAllByPlaceholderText(
        /text pattern/i,
      );
      expect(1 <= inputs.length).toBe(true);
    });

    it('adds an exclude filter entry when add button is clicked', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /filters/i);

      const excludeSection = screen
        .getByText(/exclude episodes/i)
        .closest('div.rounded-lg')!;
      const addButton = within(excludeSection).getByText(/add rule/i);

      await user.click(addButton);

      const inputs = within(excludeSection).getAllByPlaceholderText(
        /text pattern/i,
      );
      expect(1 <= inputs.length).toBe(true);
    });
  });
});
