import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ScopeZone } from '@/components/editor/shared/scope-zone.tsx';

describe('ScopeZone', () => {
  it('renders the title, hint, and children', () => {
    render(
      <ScopeZone tone="playlist" title="Playlist-level" hint="Applies to entire playlist">
        <div>child content</div>
      </ScopeZone>,
    );
    expect(screen.getByText('Playlist-level')).toBeInTheDocument();
    expect(screen.getByText('Applies to entire playlist')).toBeInTheDocument();
    expect(screen.getByText('child content')).toBeInTheDocument();
  });

  it('applies distinct styling classes per tone', () => {
    const { container, rerender } = render(
      <ScopeZone tone="playlist" title="P">x</ScopeZone>,
    );
    const playlistZone = container.firstChild as HTMLElement;
    expect(playlistZone.className).toMatch(/playlist/);

    rerender(<ScopeZone tone="pergroup" title="G">y</ScopeZone>);
    const pergroupZone = container.firstChild as HTMLElement;
    expect(pergroupZone.className).toMatch(/pergroup/);
  });
});
