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
        <PlaylistForm index={index} onRemove={onRemove} />
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
    it('renders all 6 tab triggers', () => {
      renderPlaylistForm();
      const tabs = screen.getAllByRole('tab');
      expect(tabs.length).toBe(6);
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

    it('renders priority input with current value', () => {
      renderPlaylistForm();
      const input = screen.getByLabelText(/priority/i);
      expect(input).toHaveValue(0);
    });
  });

  describe('StructureSettings', () => {
    it('renders resolver type select', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /resolver/i);
      expect(screen.getByText(/resolver type/i)).toBeInTheDocument();
    });

    it('renders presentation select', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /resolver/i);
      expect(screen.getByText(/presentation/i)).toBeInTheDocument();
    });

    it('shows nullSeasonGroupKey when resolverType is seasonNumber', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /resolver/i);
      expect(
        screen.getByLabelText(/null season group key/i),
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
      await switchToTab(user, /resolver/i);
      expect(
        screen.queryByLabelText(/null season group key/i),
      ).not.toBeInTheDocument();
    });
  });

  describe('DisplayOptions', () => {
    it('renders showYearHeaders checkbox', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /display/i);
      expect(screen.getByText(/show year headers/i)).toBeInTheDocument();
    });

    it('renders showDateRange checkbox', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /display/i);
      expect(screen.getByText(/show date range/i)).toBeInTheDocument();
    });

    it('renders userSortable checkbox', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /display/i);
      expect(screen.getByText(/user sortable/i)).toBeInTheDocument();
    });

    it('renders prependSeasonNumber checkbox', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /display/i);
      expect(
        screen.getByText(/prepend season number/i),
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
    it('renders require and exclude filter sections', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /filters/i);
      expect(screen.getByText(/require filters/i)).toBeInTheDocument();
      expect(screen.getByText(/exclude filters/i)).toBeInTheDocument();
    });

    it('adds a require filter entry when add button is clicked', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /filters/i);

      const requireSection = screen
        .getByText(/require filters/i)
        .closest('div.rounded-lg')!;
      const addButton = within(requireSection).getByText(/add filter/i);

      await user.click(addButton);

      const inputs = within(requireSection).getAllByPlaceholderText(
        /regex pattern/i,
      );
      expect(1 <= inputs.length).toBe(true);
    });

    it('adds an exclude filter entry when add button is clicked', async () => {
      const user = userEvent.setup();
      renderPlaylistForm();
      await switchToTab(user, /filters/i);

      const excludeSection = screen
        .getByText(/exclude filters/i)
        .closest('div.rounded-lg')!;
      const addButton = within(excludeSection).getByText(/add filter/i);

      await user.click(addButton);

      const inputs = within(excludeSection).getAllByPlaceholderText(
        /regex pattern/i,
      );
      expect(1 <= inputs.length).toBe(true);
    });
  });
});
