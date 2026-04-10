import { render, screen } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { SectionNote, InteractionNote } from '../note-blocks.tsx';

vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string) => key,
  }),
}));

describe('SectionNote', () => {
  it('renders with blue styling and section label', () => {
    render(<SectionNote i18nKey="sectionNote.basicSettings" />);
    expect(screen.getByText('sectionNote.basicSettings')).toBeInTheDocument();
  });
});

describe('InteractionNote', () => {
  it('renders with amber styling and interaction label', () => {
    render(<InteractionNote i18nKey="interactionNote.episodeFilters.requireExclude" />);
    expect(screen.getByText('interactionNote.episodeFilters.requireExclude')).toBeInTheDocument();
  });
});
