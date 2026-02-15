import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { RegexTester } from '../regex-tester.tsx';

describe('RegexTester', () => {
  it('renders expand button', () => {
    render(<RegexTester pattern="test" variant="include" />);
    expect(screen.getByRole('button', { name: /test/i })).toBeInTheDocument();
  });

  it('shows match count when expanded', async () => {
    render(<RegexTester pattern="Episode" variant="include" />);
    await userEvent.click(screen.getByRole('button'));
    // "Episode" should match several of the hardcoded sample titles
    expect(screen.getByText(/matches/i)).toBeInTheDocument();
  });

  it('shows error for invalid regex', async () => {
    render(<RegexTester pattern="[invalid" variant="include" />);
    await userEvent.click(screen.getByRole('button'));
    expect(screen.getByText(/invalid/i)).toBeInTheDocument();
  });

  it('highlights matches with green for include variant', async () => {
    render(<RegexTester pattern="Episode" variant="include" />);
    await userEvent.click(screen.getByRole('button'));
    const highlights = document.querySelectorAll('.bg-green-200');
    expect(0 < highlights.length).toBe(true);
  });

  it('highlights matches with red for exclude variant', async () => {
    render(<RegexTester pattern="Episode" variant="exclude" />);
    await userEvent.click(screen.getByRole('button'));
    const highlights = document.querySelectorAll('.bg-red-200');
    expect(0 < highlights.length).toBe(true);
  });

  it('renders nothing when pattern is empty', () => {
    render(<RegexTester pattern="" variant="include" />);
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });

  it('shows correct match count', async () => {
    // "Episode" matches: Episode 1, Episode 2, Bonus Episode, Episode 10 = 4
    render(<RegexTester pattern="Episode" variant="include" />);
    await userEvent.click(screen.getByRole('button'));
    expect(screen.getByText(/4 matches/i)).toBeInTheDocument();
  });

  it('collapses when clicking the button again', async () => {
    render(<RegexTester pattern="Episode" variant="include" />);
    const button = screen.getByRole('button');
    await userEvent.click(button);
    expect(screen.getByText(/matches/i)).toBeInTheDocument();
    await userEvent.click(button);
    // Sample titles should no longer be visible
    expect(screen.queryByText('Episode 1: The Beginning')).not.toBeInTheDocument();
  });
});
