import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, YearBinding } from '@/schemas/config-schema.ts';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';
import { cn } from '@/lib/utils.ts';

interface DisplaySettingsTabProps {
  index: number;
}

export function DisplaySettingsTab({ index }: DisplaySettingsTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.displaySettings" />

      <div className="space-y-4">
        <div className="grid gap-3">
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-showYearHeaders`}
              checked={watch(`${prefix}.episodeList.showYearHeaders`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.episodeList.showYearHeaders`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-showYearHeaders`} hint="showYearHeaders">
              {t('showYearHeaders')}
            </HintLabel>
          </div>
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-showDateRange`}
              checked={watch(`${prefix}.groupList.showDateRange`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.groupList.showDateRange`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-showDateRange`} hint="showDateRange">{t('showDateRange')}</HintLabel>
          </div>
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-userSortable`}
              checked={watch(`${prefix}.groupList.userSortable`) ?? true}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.groupList.userSortable`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-userSortable`} hint="userSortable">{t('userSortable')}</HintLabel>
          </div>
          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-prependSeasonNumber`}
              checked={watch(`${prefix}.prependSeasonNumber`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.prependSeasonNumber`, !!checked, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-prependSeasonNumber`} hint="prependSeasonNumber">{t('prependSeasonNumber')}</HintLabel>
          </div>
        </div>

        <InteractionNote i18nKey="interactionNote.displaySettings.yearBindingHeaders" />

        <div className="space-y-2">
          <HintLabel hint="yearBinding">
            {t('yearBinding')}
          </HintLabel>
          <YearBindingRadio
            value={watch(`${prefix}.groupList.yearBinding`) ?? 'none'}
            onChange={(v) => setValue(`${prefix}.groupList.yearBinding`, v === 'none' ? undefined : v as YearBinding, { shouldDirty: true })}
          />
        </div>
      </div>
    </div>
  );
}

const YEAR_BINDING_OPTIONS = ['none', 'pinToYear', 'splitByYear'] as const;

function YearBindingRadio({
  value,
  onChange,
}: {
  value: string;
  onChange: (value: string) => void;
}) {
  const { t } = useTranslation('editor');

  return (
    <div className="grid gap-2">
      {YEAR_BINDING_OPTIONS.map((option) => (
        <button
          key={option}
          type="button"
          onClick={() => onChange(option)}
          className={cn(
            'flex items-center gap-3 rounded-lg border p-3 text-left transition-colors',
            value === option
              ? 'border-primary bg-primary/5'
              : 'border-border hover:border-muted-foreground/50',
          )}
        >
          <div
            className={cn(
              'h-4 w-4 shrink-0 rounded-full border-2',
              value === option ? 'border-primary bg-primary' : 'border-muted-foreground/40',
            )}
          >
            {value === option && (
              <div className="flex h-full w-full items-center justify-center">
                <div className="h-1.5 w-1.5 rounded-full bg-primary-foreground" />
              </div>
            )}
          </div>
          <span className="text-sm">{t(`yearBinding_${option}`)}</span>
        </button>
      ))}
    </div>
  );
}
