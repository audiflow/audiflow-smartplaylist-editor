import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, YearBinding } from '@/schemas/config-schema.ts';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';

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
          <HintLabel htmlFor={`${prefix}.groupList.yearBinding`} hint="yearBinding">
            {t('yearBinding')}
          </HintLabel>
          <Select
            value={watch(`${prefix}.groupList.yearBinding`) ?? 'none'}
            onValueChange={(v) => setValue(`${prefix}.groupList.yearBinding`, v === 'none' ? undefined : v as YearBinding, { shouldDirty: true })}
          >
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="none">{t('yearBinding_none')}</SelectItem>
              <SelectItem value="pinToYear">{t('yearBinding_pinToYear')}</SelectItem>
              <SelectItem value="splitByYear">{t('yearBinding_splitByYear')}</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>
    </div>
  );
}
