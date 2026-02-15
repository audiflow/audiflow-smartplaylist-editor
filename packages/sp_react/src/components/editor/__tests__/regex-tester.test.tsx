import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { RegexTester } from '../regex-tester.tsx';

const TITLES = [
  'Episode 1: The Beginning',
  'Episode 2: Rising Action',
  'S01E03 - The Plot Thickens',
  'Special: Behind the Scenes',
  'Bonus Episode: Interview',
  'Episode 10: Season Finale',
  'Trailer: Coming Soon',
  'S02E01 - New Season',
];

describe('RegexTester', () => {
  it('renders expand button', () => {
    render(<RegexTester pattern="test" variant="include" titles={TITLES} />);
    expect(screen.getByRole('button', { name: /test/i })).toBeInTheDocument();
  });

  it('shows match count when expanded', async () => {
    render(<RegexTester pattern="Episode" variant="include" titles={TITLES} />);
    await userEvent.click(screen.getByRole('button'));
    expect(screen.getByText(/matches/i)).toBeInTheDocument();
  });

  it('shows error for invalid regex', async () => {
    render(<RegexTester pattern="[invalid" variant="include" titles={TITLES} />);
    await userEvent.click(screen.getByRole('button'));
    expect(screen.getByText(/invalid/i)).toBeInTheDocument();
  });

  it('highlights matches with green for include variant', async () => {
    render(<RegexTester pattern="Episode" variant="include" titles={TITLES} />);
    await userEvent.click(screen.getByRole('button'));
    const highlights = document.querySelectorAll('.bg-green-200');
    expect(0 < highlights.length).toBe(true);
  });

  it('highlights matches with red for exclude variant', async () => {
    render(<RegexTester pattern="Episode" variant="exclude" titles={TITLES} />);
    await userEvent.click(screen.getByRole('button'));
    const highlights = document.querySelectorAll('.bg-red-200');
    expect(0 < highlights.length).toBe(true);
  });

  it('renders nothing when pattern is empty', () => {
    render(<RegexTester pattern="" variant="include" titles={TITLES} />);
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });

  it('shows correct match count', async () => {
    // "Episode" matches: Episode 1, Episode 2, Bonus Episode, Episode 10 = 4
    render(<RegexTester pattern="Episode" variant="include" titles={TITLES} />);
    await userEvent.click(screen.getByRole('button'));
    expect(screen.getByText(/4 matches/i)).toBeInTheDocument();
  });

  it('collapses when clicking the button again', async () => {
    render(<RegexTester pattern="Episode" variant="include" titles={TITLES} />);
    const button = screen.getByRole('button');
    await userEvent.click(button);
    expect(screen.getByText(/matches/i)).toBeInTheDocument();
    await userEvent.click(button);
    expect(screen.queryByText('Episode 1: The Beginning')).not.toBeInTheDocument();
  });

  it('shows load-feed message when titles is empty', async () => {
    render(<RegexTester pattern="test" variant="include" titles={[]} />);
    await userEvent.click(screen.getByRole('button'));
    expect(screen.getByText(/load a feed/i)).toBeInTheDocument();
  });

  it('shows 0 matches when titles is empty', () => {
    render(<RegexTester pattern="test" variant="include" titles={[]} />);
    expect(screen.getByText(/0 matches/i)).toBeInTheDocument();
  });
});
