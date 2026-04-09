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
  overrides?: Partial<{ index: number; onRemove: () => void; config: PatternConfig }>,
) {
  const index = overrides?.index ?? 0;
  const onRemove = overrides?.onRemove ?? vi.fn();
  const config = overrides?.config ?? DEFAULT_CONFIG;

  return {
    onRemove,
    ...renderWithProviders(
      <FormWrapper defaultValues={config}>
        <PlaylistForm index={index} playlistCount={config.playlists.length} onRemove={onRemove} />
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
    it('hides Groups tab for non-titleClassifier resolvers', () => {
      renderPlaylistForm();
      const tabs = screen.getAllByRole('tab');
      expect(tabs.length).toBe(5);
      expect(screen.queryByRole('tab', { name: /groups/i })).not.toBeInTheDocument();
    });

    it('shows Groups tab for titleClassifier resolver', () => {
      const config: PatternConfig = {
        ...DEFAULT_CONFIG,
        playlists: [{ ...DEFAULT_CONFIG.playlists[0], resolverType: 'titleClassifier' }],
      };
      renderPlaylistForm({ config });
      const tabs = screen.getAllByRole('tab');
      expect(tabs.length).toBe(6);
      expect(screen.getByRole('tab', { name: /groups/i })).toBeInTheDocument();
    });

    it('shows Basic tab as default active tab', () => {
      renderPlaylistForm();
      const basicTab = screen.getByRole('tab', { name: /basic/i });
      expect(basicTab).toHaveAttribute('data-state', 'active');
    });
  });

  describe('BasicSettings', () => {
    it('renders id input with current value', () => {
      renderPlaylistForm();
      const input = screen.getByLabelText(/^id$/i);
      expect(input).toBeInTheDocument();
      expect(input).toHaveValue('playlist-1');
    });

    it('renders display name input with current value', () => {
      renderPlaylistForm();
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

    it('renders presentation radio cards', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /organize/i);
      expect(screen.getByText(/how groups appear/i)).toBeInTheDocument();
    });

    it('shows nullSeasonGroupKey when resolverType is seasonNumber', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /organize/i);
      expect(
        screen.getByLabelText(/group key for episodes without a season/i),
      ).toBeInTheDocument();
    });

    it('hides nullSeasonGroupKey when resolverType is not seasonNumber', async () => {
      const user = userEvent.setup();
      const config: PatternConfig = {
        ...DEFAULT_CONFIG,
        playlists: [
          {
            ...DEFAULT_CONFIG.playlists[0],
            resolverType: 'titleClassifier',
          },
        ],
      };
      renderPlaylistForm({ config });
      await switchToTab(user, /organize/i);
      expect(
        screen.queryByLabelText(/group key for episodes without a season/i),
      ).not.toBeInTheDocument();
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
