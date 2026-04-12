import type { ReactNode } from 'react';
import { useTranslation } from 'react-i18next';

type PartitionBy = 'group' | 'seasonNumber' | 'year' | undefined;

interface SelectorBridgeProps {
  partitionBy: PartitionBy;
  partitionByLabel: string;
  children?: ReactNode;
}

export function SelectorBridge({ partitionBy, partitionByLabel, children }: SelectorBridgeProps) {
  const { t } = useTranslation('editor');
  const showTitleExtractor = partitionBy === 'seasonNumber' || partitionBy === 'year';

  return (
    <section
      data-preview-region="selector-bridge"
      className="rounded-lg border border-amber-300 bg-amber-50/50 px-4 py-3 space-y-3"
    >
      <header className="flex items-baseline gap-2">
        <h4 className="text-xs font-semibold uppercase tracking-wider text-amber-800">
          {t('bridge.selector.title')}
        </h4>
        <span className="text-xs text-muted-foreground">
          {t('bridge.selector.partitionBy', { value: partitionByLabel })}
        </span>
      </header>
      {showTitleExtractor ? children : (
        <p className="text-xs italic text-muted-foreground">
          {t('bridge.selector.notApplicable')}
        </p>
      )}
    </section>
  );
}
