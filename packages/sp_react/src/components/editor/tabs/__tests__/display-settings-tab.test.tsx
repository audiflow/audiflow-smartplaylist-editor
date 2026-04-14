import { describe, expect, it, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { FormProvider, useForm } from 'react-hook-form';
import type { ReactNode } from 'react';
import { DisplaySettingsTab } from '@/components/editor/tabs/display-settings-tab.tsx';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { useEditorStore } from '@/stores/editor-store.ts';

function Wrapper({ children, defaultValues }: { children: ReactNode; defaultValues: Partial<PatternConfig> }) {
  const methods = useForm<PatternConfig>({ defaultValues: defaultValues as PatternConfig });
  return <FormProvider {...methods}>{children}</FormProvider>;
}

function cfg(overrides: Record<string, unknown> = {}): Partial<PatternConfig> {
  return {
    playlists: [
      {
        id: 'pl-1', displayName: 'PL', priority: 0,
        grouping: { by: 'seasonNumber' },
        ...overrides,
      } as PatternConfig['playlists'][number],
    ],
  } as Partial<PatternConfig>;
}

describe('DisplaySettingsTab', () => {
  beforeEach(() => useEditorStore.getState().reset());

  it('renders the playlist-level zone and the group-settings zone', () => {
    render(<Wrapper defaultValues={cfg()}><DisplaySettingsTab index={0} /></Wrapper>);
    expect(screen.getByText(/Playlist-level/i)).toBeInTheDocument();
    expect(screen.getByText(/Group settings/i)).toBeInTheDocument();
  });

  it('hides context bar when grouping.by != titleClassifier', () => {
    render(<Wrapper defaultValues={cfg()}><DisplaySettingsTab index={0} /></Wrapper>);
    expect(screen.queryByRole('toolbar', { name: /Group context/i })).not.toBeInTheDocument();
  });

  it('shows Groups and Episodes subsection headings', () => {
    render(<Wrapper defaultValues={cfg()}><DisplaySettingsTab index={0} /></Wrapper>);
    expect(screen.getByRole('heading', { name: /^Groups$/i, level: 5 })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /^Episodes$/i, level: 5 })).toBeInTheDocument();
  });
});
