import { useRef, useEffect } from 'react';
import { useFormContext, useWatch } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { Link } from '@tanstack/react-router';
import { Loader2, TriangleAlert } from 'lucide-react';
import { useDerivedPatternId } from '@/hooks/use-derive-pattern-id.ts';
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
import { useDuplicateCheck } from '@/hooks/use-duplicate-check.ts';
import type { DuplicateConflict } from '@/hooks/use-duplicate-check.ts';

export function PatternSettingsCard({
  configId,
}: {
  configId: string | null;
}) {
  const { register, watch, setValue, control } =
    useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const podcastGuid = useWatch({ control, name: 'podcastGuid' });
  const feedUrls = useWatch({ control, name: 'feedUrls' });
  const conflicts = useDuplicateCheck(configId, podcastGuid, feedUrls);

  const isNewConfig = configId === null;
  const derived = useDerivedPatternId(
    isNewConfig ? podcastGuid : undefined,
    isNewConfig ? feedUrls : undefined,
  );

  // Auto-populate ID when derived value changes (new config only)
  const prevDerivedId = useRef<string | null>(null);
  useEffect(() => {
    if (!isNewConfig) return;
    if (!derived.id) {
      // Clear stale ID when inputs are emptied
      if (prevDerivedId.current !== null) {
        prevDerivedId.current = null;
        setValue('id', '', { shouldDirty: true });
      }
      return;
    }
    if (derived.id === prevDerivedId.current) return;
    prevDerivedId.current = derived.id;
    setValue('id', derived.id, { shouldDirty: true });
  }, [isNewConfig, derived.id, setValue]);

  const guidConflicts = conflicts.filter((c) => c.field === 'podcastGuid');
  const feedUrlConflicts = conflicts.filter((c) => c.field === 'feedUrls');

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('patternSettings')}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <HintLabel htmlFor="config-id" hint="patternId">
              {t('configId')}
            </HintLabel>
            {isNewConfig ? (
              <div className="relative">
                <Input
                  id="config-id"
                  {...register('id')}
                  readOnly
                  className="bg-muted"
                  placeholder={t('placeholderDerivedId')}
                />
                {derived.isLoading && (
                  <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 animate-spin text-muted-foreground" />
                )}
              </div>
            ) : (
              <Input
                id="config-id"
                {...register('id')}
                readOnly
                className="bg-muted"
              />
            )}
            {isNewConfig && derived.source && (
              <p className="text-xs text-muted-foreground">
                {t('derivedFrom', { source: derived.source === 'podcastGuid' ? t('podcastGuid') : t('feedUrlsLabel') })}
              </p>
            )}
          </div>
          <div className="space-y-1.5">
            <HintLabel htmlFor="config-displayName" hint="patternDisplayName">
              {t('patternDisplayName')}
            </HintLabel>
            <Input
              id="config-displayName"
              {...register('displayName')}
              placeholder={t('placeholderPatternDisplayName')}
            />
          </div>
        </div>
        <div className="space-y-1.5">
          <HintLabel htmlFor="config-podcastGuid" hint="podcastGuid">
            {t('podcastGuid')}
          </HintLabel>
          <Input
            id="config-podcastGuid"
            {...register('podcastGuid')}
            placeholder={t('placeholderGuid')}
          />
          {guidConflicts.map((c) => (
            <DuplicateWarning key={c.claimedBy} conflict={c} />
          ))}
        </div>
        <FeedUrlsField conflicts={feedUrlConflicts} />
        <div className="flex items-center gap-2">
          <Checkbox
            id="config-yearGroupedEpisodes"
            checked={watch('yearGroupedEpisodes') ?? false}
            onCheckedChange={(checked) =>
              setValue('yearGroupedEpisodes', !!checked, { shouldDirty: true })
            }
          />
          <HintLabel
            htmlFor="config-yearGroupedEpisodes"
            hint="yearGroupedEpisodes"
          >
            {t('yearGroupedEpisodes')}
          </HintLabel>
        </div>
      </CardContent>
    </Card>
  );
}

function FeedUrlsField({
  conflicts,
}: {
  conflicts: DuplicateConflict[];
}) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const feedUrls = watch('feedUrls') ?? [];

  return (
    <div className="space-y-1.5">
      <HintLabel htmlFor="config-feedUrls" hint="feedUrls">
        {t('feedUrlsLabel')}
      </HintLabel>
      <Textarea
        id="config-feedUrls"
        value={feedUrls.join(', ')}
        onChange={(e) => {
          const urls = e.target.value
            .split(',')
            .map((u) => u.trim())
            .filter(Boolean);
          setValue('feedUrls', urls, { shouldDirty: true });
        }}
        placeholder={t('placeholderFeedUrls')}
      />
      {conflicts.map((c) => (
        <DuplicateWarning key={`${c.claimedBy}-${c.value}`} conflict={c} />
      ))}
    </div>
  );
}

function DuplicateWarning({ conflict }: { conflict: DuplicateConflict }) {
  const { t } = useTranslation('editor');

  const message =
    conflict.field === 'podcastGuid'
      ? t('duplicateGuid', { patternId: conflict.claimedBy })
      : t('duplicateFeedUrl', {
          url: conflict.value,
          patternId: conflict.claimedBy,
        });

  return (
    <p className="flex items-center gap-1.5 text-sm text-amber-600 dark:text-amber-400">
      <TriangleAlert className="h-3.5 w-3.5 shrink-0" />
      <span>
        {message}{' '}
        <Link
          to="/editor/$id"
          params={{ id: conflict.claimedBy }}
          className="underline underline-offset-2 hover:text-amber-800 dark:hover:text-amber-200"
        >
          {t('duplicateGoToPattern')}
        </Link>
      </span>
    </p>
  );
}
