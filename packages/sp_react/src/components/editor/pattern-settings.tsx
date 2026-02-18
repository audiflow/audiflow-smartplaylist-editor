import { useFormContext } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig } from '@/schemas/config-schema.ts';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card.tsx';
import { Input } from '@/components/ui/input.tsx';
import { Textarea } from '@/components/ui/textarea.tsx';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';

export function PatternSettingsCard() {
  const { register, watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('patternSettings')}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <HintLabel htmlFor="config-id" hint="patternId">{t('configId')}</HintLabel>
            <Input
              id="config-id"
              {...register('id')}
              placeholder={t('placeholderPatternId')}
            />
          </div>
          <div className="space-y-1.5">
            <HintLabel htmlFor="config-podcastGuid" hint="podcastGuid">{t('podcastGuid')}</HintLabel>
            <Input
              id="config-podcastGuid"
              {...register('podcastGuid')}
              placeholder={t('placeholderGuid')}
            />
          </div>
        </div>
        <FeedUrlsField />
        <div className="flex items-center gap-2">
          <Checkbox
            id="config-yearGroupedEpisodes"
            checked={watch('yearGroupedEpisodes') ?? false}
            onCheckedChange={(checked) =>
              setValue('yearGroupedEpisodes', !!checked)
            }
          />
          <HintLabel htmlFor="config-yearGroupedEpisodes" hint="yearGroupedEpisodes">
            {t('yearGroupedEpisodes')}
          </HintLabel>
        </div>
      </CardContent>
    </Card>
  );
}

function FeedUrlsField() {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const feedUrls = watch('feedUrls') ?? [];

  return (
    <div className="space-y-1.5">
      <HintLabel htmlFor="config-feedUrls" hint="feedUrls">{t('feedUrlsLabel')}</HintLabel>
      <Textarea
        id="config-feedUrls"
        value={feedUrls.join(', ')}
        onChange={(e) => {
          const urls = e.target.value
            .split(',')
            .map((u) => u.trim())
            .filter(Boolean);
          setValue('feedUrls', urls);
        }}
        placeholder={t('placeholderFeedUrls')}
      />
    </div>
  );
}
