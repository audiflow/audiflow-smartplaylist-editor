import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PresetConfig } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { SectionNote } from '@/components/editor/note-blocks.tsx';
import { usePreviewHighlight } from '@/hooks/use-preview-highlight.ts';
import { PREVIEW_FIELDS } from '@/components/editor/preview/preview-field-ids.ts';

interface BasicSettingsTabProps {
  index: number;
}

export function BasicSettingsTab({ index }: BasicSettingsTabProps) {
  const prefix = `playlists.${index}` as const;
  const { register } = useFormContext<PresetConfig>();
  const { t } = useTranslation('editor');
  const displayNameHl = usePreviewHighlight(PREVIEW_FIELDS.playlistDisplayName);

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.basicSettings" />

      <div className="space-y-4">
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-id`} hint="playlistId">{t('playlistId')}</HintLabel>
          <Input
            id={`playlist-${index}-id`}
            {...register(`${prefix}.id`)}
            placeholder={t('placeholderPlaylistId')}
          />
        </div>
        <div className="space-y-1.5">
          <HintLabel htmlFor={`playlist-${index}-displayName`} hint="displayName">{t('displayName')}</HintLabel>
          <Input
            id={`playlist-${index}-displayName`}
            {...register(`${prefix}.displayName`)}
            {...displayNameHl}
            placeholder={t('placeholderDisplayName')}
          />
        </div>
      </div>
    </div>
  );
}
