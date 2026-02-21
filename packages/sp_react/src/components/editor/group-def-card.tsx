import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import { Input } from '@/components/ui/input.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { Button } from '@/components/ui/button.tsx';
import { Card, CardContent } from '@/components/ui/card.tsx';
import { Trash2 } from 'lucide-react';

interface GroupDefCardProps {
  playlistIndex: number;
  groupIndex: number;
  onRemove: () => void;
}

export function GroupDefCard({ playlistIndex, groupIndex, onRemove }: GroupDefCardProps) {
  const { register, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${playlistIndex}.groups.${groupIndex}` as const;

  return (
    <Card className="py-4">
      <CardContent className="space-y-3 px-4">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium">
            {watch(`${prefix}.displayName`) || t('groupDisplayName')}
          </span>
          <Button variant="ghost" size="sm" type="button" onClick={onRemove}>
            <Trash2 className="h-4 w-4" />
            <span className="sr-only">{t('removeGroup')}</span>
          </Button>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <HintLabel htmlFor={`group-${playlistIndex}-${groupIndex}-id`} hint="groupId">
              {t('groupId')}
            </HintLabel>
            <Input
              id={`group-${playlistIndex}-${groupIndex}-id`}
              {...register(`${prefix}.id`)}
            />
          </div>

          <div className="space-y-1.5">
            <HintLabel
              htmlFor={`group-${playlistIndex}-${groupIndex}-displayName`}
              hint="groupDisplayName"
            >
              {t('groupDisplayName')}
            </HintLabel>
            <Input
              id={`group-${playlistIndex}-${groupIndex}-displayName`}
              {...register(`${prefix}.displayName`)}
            />
          </div>
        </div>

        <div className="space-y-1.5">
          <HintLabel
            htmlFor={`group-${playlistIndex}-${groupIndex}-pattern`}
            hint="groupPattern"
          >
            {t('groupPattern')}
          </HintLabel>
          <Input
            id={`group-${playlistIndex}-${groupIndex}-pattern`}
            {...register(`${prefix}.pattern`)}
            placeholder={t('placeholderRegex')}
          />
        </div>

        <div className="flex gap-6">
          <div className="flex items-center gap-2">
            <Checkbox
              id={`group-${playlistIndex}-${groupIndex}-episodeYearHeaders`}
              checked={watch(`${prefix}.episodeYearHeaders`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.episodeYearHeaders`, !!checked)
              }
            />
            <HintLabel
              htmlFor={`group-${playlistIndex}-${groupIndex}-episodeYearHeaders`}
              hint="episodeYearHeaders"
            >
              {t('episodeYearHeaders')}
            </HintLabel>
          </div>

          <div className="flex items-center gap-2">
            <Checkbox
              id={`group-${playlistIndex}-${groupIndex}-showDateRange`}
              checked={watch(`${prefix}.showDateRange`) ?? false}
              onCheckedChange={(checked) =>
                setValue(`${prefix}.showDateRange`, !!checked)
              }
            />
            <HintLabel
              htmlFor={`group-${playlistIndex}-${groupIndex}-showDateRange`}
              hint="showDateRange"
            >
              {t('showDateRange')}
            </HintLabel>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
