import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, EpisodeSortField, SortOrder } from '@/schemas/config-schema.ts';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { Button } from '@/components/ui/button.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { cn } from '@/lib/utils.ts';
import { useCallback, useRef, type KeyboardEvent } from 'react';

const EPISODE_SORT_FIELDS = ['publishedAt', 'episodeNumber', 'title'] as const;
const SORT_ORDERS = ['ascending', 'descending'] as const;

interface EpisodeListTabProps {
  index: number;
}

export function EpisodeListTab({ index }: EpisodeListTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const sort = watch(`${prefix}.episodeListing.sort`);
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
                setValue(`${prefix}.episodeListing.sort`, undefined, { shouldDirty: true });
              } else {
                setValue(
                  `${prefix}.episodeListing.sort`,
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
                aria-label={t('episodeSortField')}
                options={EPISODE_SORT_FIELDS.map((f) => ({ value: f, label: t(`episodeSortField_${f}`) }))}
                value={sort?.field ?? 'publishedAt'}
                onChange={(val) => setValue(`${prefix}.episodeListing.sort.field`, val as EpisodeSortField, { shouldDirty: true })}
              />
            </div>
            <div className="space-y-1.5">
              <HintLabel hint="episodeSortOrder">{t('episodeSortOrder')}</HintLabel>
              <ToggleGroup
                aria-label={t('episodeSortOrder')}
                options={SORT_ORDERS.map((o) => ({ value: o, label: t(`sortOrder_${o}`) }))}
                value={sort?.order ?? 'ascending'}
                onChange={(val) => setValue(`${prefix}.episodeListing.sort.order`, val as SortOrder, { shouldDirty: true })}
              />
            </div>
          </div>
        )}
      </div>

      <InteractionNote i18nKey="interactionNote.episodeList.titleExtractorChain" />
      <TitleExtractorForm
        fieldPath={`playlists.${index}.episodeItem.titleExtractor`}
        idPrefix={`ep-list-title-ext-${index}`}
      />
    </div>
  );
}

function ToggleGroup({
  options,
  value,
  onChange,
  'aria-label': ariaLabel,
}: {
  options: ReadonlyArray<{ value: string; label: string }>;
  value: string;
  onChange: (value: string) => void;
  'aria-label': string;
}) {
  const buttonsRef = useRef<(HTMLButtonElement | null)[]>([]);

  const handleKeyDown = useCallback(
    (e: KeyboardEvent<HTMLButtonElement>) => {
      const currentIndex = buttonsRef.current.findIndex((b) => b === e.currentTarget);
      if (0 > currentIndex) return;

      let nextIndex: number | null = null;
      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
        nextIndex = (currentIndex + 1) % options.length;
      } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
        nextIndex = (currentIndex - 1 + options.length) % options.length;
      }

      if (nextIndex !== null) {
        e.preventDefault();
        const nextButton = buttonsRef.current[nextIndex];
        nextButton?.focus();
        onChange(options[nextIndex].value);
      }
    },
    [options, onChange],
  );

  return (
    <div className="inline-flex rounded-lg border border-border" role="radiogroup" aria-label={ariaLabel}>
      {options.map((opt, i) => {
        const isSelected = value === opt.value;
        return (
          <button
            key={opt.value}
            ref={(el) => { buttonsRef.current[i] = el; }}
            type="button"
            role="radio"
            aria-checked={isSelected}
            tabIndex={isSelected ? 0 : -1}
            onClick={() => onChange(opt.value)}
            onKeyDown={handleKeyDown}
            className={cn(
              'px-3 py-1.5 text-sm transition-colors focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:outline-none',
              isSelected
                ? 'bg-primary text-primary-foreground'
                : 'hover:bg-muted',
              0 < i && 'border-l border-border',
            )}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}
