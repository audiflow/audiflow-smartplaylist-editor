import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ConflictDialog } from '../conflict-dialog.tsx';

describe('ConflictDialog', () => {
  const defaultProps = {
    open: true,
    filePath: 'presets/test-pattern',
    onReload: vi.fn(),
    onKeepChanges: vi.fn(),
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders title and description when open', () => {
    render(<ConflictDialog {...defaultProps} />);
    expect(screen.getByText(/file changed externally/i)).toBeInTheDocument();
    expect(screen.getByText(/presets\/test-pattern/)).toBeInTheDocument();
  });

  it('does not render content when closed', () => {
    render(<ConflictDialog {...defaultProps} open={false} />);
    expect(screen.queryByText(/file changed externally/i)).not.toBeInTheDocument();
  });

  it('calls onReload when reload button is clicked', async () => {
    const user = userEvent.setup();
    render(<ConflictDialog {...defaultProps} />);
    await user.click(screen.getByText(/reload from disk/i));
    expect(defaultProps.onReload).toHaveBeenCalledOnce();
  });

  it('calls onKeepChanges when keep button is clicked', async () => {
    const user = userEvent.setup();
    render(<ConflictDialog {...defaultProps} />);
    await user.click(screen.getByText(/keep my changes/i));
    expect(defaultProps.onKeepChanges).toHaveBeenCalledOnce();
  });
});
