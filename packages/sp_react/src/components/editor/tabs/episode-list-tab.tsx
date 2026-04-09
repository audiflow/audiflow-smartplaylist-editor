import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, EpisodeSortField, SortOrder } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { Button } from '@/components/ui/button.tsx';
import { SectionNote } from '@/components/editor/note-blocks.tsx';
import { cn } from '@/lib/utils.ts';

const EPISODE_SORT_FIELDS = ['publishedAt', 'episodeNumber', 'title'] as const;
const SORT_ORDERS = ['ascending', 'descending'] as const;

interface EpisodeListTabProps {
  index: number;
}

export function EpisodeListTab({ index }: EpisodeListTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const sort = watch(`${prefix}.episodeList.sort`);
  const isSortEnabled = sort != null;

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.episodeList" />

      <div className="rounded-lg border border-border p-4 space-y-3">
        <div className="flex items-center justify-between">
          <HintLabel hint="episodeListSort">{t('episodeListSort')}</HintLabel>
          <Button
            type="button"
            variant={isSortEnabled ? 'default' : 'outline'}
            size="sm"
            onClick={() => {
              if (isSortEnabled) {
                setValue(`${prefix}.episodeList.sort`, undefined, { shouldDirty: true });
              } else {
                setValue(
                  `${prefix}.episodeList.sort`,
                  { field: 'publishedAt', order: 'ascending' },
                  { shouldDirty: true },
                );
              }
            }}
          >
            {isSortEnabled ? t('sortEnabled') : t('sortDisabled')}
          </Button>
        </div>

        {isSortEnabled && (
          <div className="space-y-3">
            <div className="space-y-1.5">
              <HintLabel hint="episodeSortField">{t('episodeSortField')}</HintLabel>
              <ToggleGroup
                options={EPISODE_SORT_FIELDS.map((f) => ({ value: f, label: t(`episodeSortField_${f}`) }))}
                value={sort?.field ?? 'publishedAt'}
                onChange={(val) => setValue(`${prefix}.episodeList.sort.field`, val as EpisodeSortField, { shouldDirty: true })}
              />
            </div>
            <div className="space-y-1.5">
              <HintLabel hint="episodeSortOrder">{t('episodeSortOrder')}</HintLabel>
              <ToggleGroup
                options={SORT_ORDERS.map((o) => ({ value: o, label: t(`sortOrder_${o}`) }))}
                value={sort?.order ?? 'ascending'}
                onChange={(val) => setValue(`${prefix}.episodeList.sort.order`, val as SortOrder, { shouldDirty: true })}
              />
            </div>
          </div>
        )}
      </div>

    </div>
  );
}

function ToggleGroup({
  options,
  value,
  onChange,
}: {
  options: ReadonlyArray<{ value: string; label: string }>;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <div className="inline-flex rounded-lg border border-border">
      {options.map((opt, i) => (
        <button
          key={opt.value}
          type="button"
          onClick={() => onChange(opt.value)}
          className={cn(
            'px-3 py-1.5 text-sm transition-colors',
            value === opt.value
              ? 'bg-primary text-primary-foreground'
              : 'hover:bg-muted',
            0 < i && 'border-l border-border',
          )}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}
