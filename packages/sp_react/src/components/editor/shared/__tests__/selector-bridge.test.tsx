import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { SelectorBridge } from '@/components/editor/shared/selector-bridge.tsx';

vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (k: string, v?: Record<string, string>) => (v ? `${k}:${JSON.stringify(v)}` : k),
  }),
}));

describe('SelectorBridge', () => {
  it('shows the partitionBy value as read-only context', () => {
    render(
      <SelectorBridge partitionBy="seasonNumber" partitionByLabel="seasonNumber">
        <div>title-extractor-form</div>
      </SelectorBridge>,
    );
    expect(screen.getByText(/seasonNumber/)).toBeInTheDocument();
    expect(screen.getByText('title-extractor-form')).toBeInTheDocument();
  });

  it('renders a "not applicable" notice when partitionBy is undefined', () => {
    render(
      <SelectorBridge partitionBy={undefined} partitionByLabel="(none)">
        <div>should-not-render</div>
      </SelectorBridge>,
    );
    expect(screen.queryByText('should-not-render')).not.toBeInTheDocument();
  });
});
