import { describe, expect, it, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { FormProvider, useForm } from 'react-hook-form';
import type { ReactNode } from 'react';
import { OrganizeTab } from '@/components/editor/tabs/organize-tab.tsx';
import type { PresetConfig } from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';

function Wrapper({ children, defaultValues }: { children: ReactNode; defaultValues: Partial<PresetConfig> }) {
  const methods = useForm<PresetConfig>({ defaultValues: defaultValues as PresetConfig });
  return <FormProvider {...methods}>{children}</FormProvider>;
}

function baseConfig(overrides: Record<string, unknown> = {}): Partial<PresetConfig> {
  return {
    playlists: [
      {
        id: 'pl-1',
        displayName: 'PL',
        priority: 0,
        grouping: { by: 'seasonNumber' },
        ...overrides,
      } as PresetConfig['playlists'][number],
    ],
  } as Partial<PresetConfig>;
}

describe('OrganizeTab', () => {
  beforeEach(() => useEditorStore.getState().reset());

  it('renders blue zone with grouping method and partitionBy when by != titleClassifier', () => {
    render(
      <Wrapper defaultValues={baseConfig()}>
        <OrganizeTab index={0} playlistCount={1} />
      </Wrapper>,
    );
    expect(screen.getByText(/Playlist-level/i)).toBeInTheDocument();
  });

  it('hides the group context bar when by != titleClassifier', () => {
    render(
      <Wrapper defaultValues={baseConfig()}>
        <OrganizeTab index={0} playlistCount={1} />
      </Wrapper>,
    );
    expect(screen.queryByRole('toolbar', { name: /Group context/i })).not.toBeInTheDocument();
  });

  it('shows the group context bar when by == titleClassifier', () => {
    const cfg = baseConfig({
      grouping: {
        by: 'titleClassifier',
        staticClassifiers: [
          { id: 'g1', displayName: 'Group 1' },
        ],
      },
    });
    render(
      <Wrapper defaultValues={cfg}>
        <OrganizeTab index={0} playlistCount={1} />
      </Wrapper>,
    );
    expect(screen.getByRole('toolbar', { name: /Group context/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Group 1' })).toBeInTheDocument();
  });

  it('updates activeGroupContext state when a group chip is clicked', () => {
    const cfg = baseConfig({
      grouping: {
        by: 'titleClassifier',
        staticClassifiers: [
          { id: 'g1', displayName: 'Group 1', pattern: { source: 'title', pattern: 'foo' } },
        ],
      },
    });
    render(
      <Wrapper defaultValues={cfg}>
        <OrganizeTab index={0} playlistCount={1} />
      </Wrapper>,
    );
    fireEvent.click(screen.getByRole('button', { name: 'Group 1' }));
    expect(useEditorStore.getState().getActiveGroupContext('pl-1')).toBe('g1');
  });
});
