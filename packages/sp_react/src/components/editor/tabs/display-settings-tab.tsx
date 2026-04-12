import { useFormContext, useWatch } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, YearBinding } from '@/schemas/config-schema.ts';
import { Checkbox } from '@/components/ui/checkbox.tsx';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';
import { ScopeZone } from '@/components/editor/shared/scope-zone.tsx';
import { GroupContextBar } from '@/components/editor/shared/group-context-bar.tsx';
import { SelectorBridge } from '@/components/editor/shared/selector-bridge.tsx';
import { TitleExtractorForm } from '@/components/editor/title-extractor-form.tsx';
import { SortForm } from '@/components/editor/sort-form.tsx';
import { useEditorStore } from '@/stores/editor-store.ts';

const YEAR_BINDING_OPTIONS = ['none', 'pinToYear', 'splitByYear'] as const;

interface DisplaySettingsTabProps {
  index: number;
}

export function DisplaySettingsTab({ index }: DisplaySettingsTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const playlistId = useWatch({ control, name: `${prefix}.id` as const });
  const partitionBy = watch(`${prefix}.selector.partitionBy` as never) as string | undefined;
  const resolverType = watch(`${prefix}.grouping.by` as never) as string | undefined;
  const staticClassifiers = (
    watch(`${prefix}.grouping.staticClassifiers` as never) ?? []
  ) as Array<{ id: string; displayName: string }>;

  const activeContext = useEditorStore((s) => s.getActiveGroupContext(playlistId ?? ''));
  const setActiveContext = useEditorStore((s) => s.setActiveGroupContext);
  const selectedIdx = staticClassifiers.findIndex((g) => g.id === activeContext);
  const isTitleClassifier = resolverType === 'titleClassifier';

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.displaySettings" />

      <SelectorBridge
        partitionBy={partitionBy as 'group' | 'seasonNumber' | 'year' | undefined}
        partitionByLabel={t(`partitionBy_${partitionBy ?? 'group'}`)}
      >
        <TitleExtractorForm
          fieldPath={`${prefix}.selector.titleExtractor`}
          idPrefix={`selector-title-${index}`}
        />
      </SelectorBridge>

      <ScopeZone tone="playlist" title={t('scope.playlist')} hint={t('scope.playlistHint')}>
        <div className="space-y-3">
          <SortForm
            fieldPath={`${prefix}.groupListing.sort`}
            idPrefix={`group-sort-${index}`}
          />

          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-userSortable`}
              checked={watch(`${prefix}.groupListing.userSortable`) ?? true}
              onCheckedChange={(c) =>
                setValue(`${prefix}.groupListing.userSortable`, !!c, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-userSortable`} hint="userSortable">
              {t('userSortable')}
            </HintLabel>
          </div>

          <div className="space-y-1.5">
            <HintLabel htmlFor={`playlist-${index}-yearBinding`} hint="yearBinding">
              {t('yearBinding')}
            </HintLabel>
            <Select
              value={watch(`${prefix}.groupListing.yearBinding`) ?? 'none'}
              onValueChange={(v) =>
                setValue(
                  `${prefix}.groupListing.yearBinding`,
                  v === 'none' ? undefined : (v as YearBinding),
                  { shouldDirty: true },
                )
              }
            >
              <SelectTrigger id={`playlist-${index}-yearBinding`} className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {YEAR_BINDING_OPTIONS.map((o) => (
                  <SelectItem key={o} value={o}>{t(`yearBinding_${o}`)}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-prependSeasonNumber`}
              checked={watch(`${prefix}.groupItem.prependSeasonNumber`) ?? false}
              onCheckedChange={(c) =>
                setValue(`${prefix}.groupItem.prependSeasonNumber`, !!c, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-prependSeasonNumber`} hint="prependSeasonNumber">
              {t('prependSeasonNumber')}
            </HintLabel>
          </div>

          <div className="flex items-center gap-2">
            <Checkbox
              id={`playlist-${index}-pinToYear`}
              checked={watch(`${prefix}.groupItem.pinToYear`) ?? false}
              onCheckedChange={(c) =>
                setValue(`${prefix}.groupItem.pinToYear`, !!c, { shouldDirty: true })
              }
            />
            <HintLabel htmlFor={`playlist-${index}-pinToYear`} hint="pinToYear">
              {t('pinToYear')}
            </HintLabel>
          </div>

          <TitleExtractorForm
            fieldPath={`${prefix}.groupItem.titleExtractor`}
            idPrefix={`group-title-${index}`}
          />
        </div>
      </ScopeZone>

      <ScopeZone
        tone="pergroup"
        title={t('scope.pergroup')}
        hint={
          activeContext === 'all'
            ? t('scope.pergroupHint_defaults')
            : t('scope.pergroupHint_specific', { group: staticClassifiers[selectedIdx]?.displayName ?? '' })
        }
      >
        <div className="space-y-4">
          {isTitleClassifier ? (
            <GroupContextBar
              groups={staticClassifiers}
              active={activeContext}
              allLabel={t('context.allGroups')}
              addLabel={t('context.addGroup')}
              onSelect={(id) => setActiveContext(playlistId ?? '', id)}
              onAdd={() => {
                const newId = `group-${staticClassifiers.length + 1}`;
                setValue(
                  `${prefix}.grouping.staticClassifiers` as never,
                  [
                    ...staticClassifiers,
                    { id: newId, displayName: `Group ${staticClassifiers.length + 1}` },
                  ] as never,
                  { shouldDirty: true },
                );
                setActiveContext(playlistId ?? '', newId);
              }}
            />
          ) : null}

          <GroupsSubsection index={index} activeContext={activeContext} selectedIdx={selectedIdx} />
          <EpisodesSubsection index={index} activeContext={activeContext} selectedIdx={selectedIdx} />
        </div>
      </ScopeZone>
    </div>
  );
}

interface SubsectionProps {
  index: number;
  activeContext: 'all' | string;
  selectedIdx: number;
}

function GroupsSubsection({ index, activeContext, selectedIdx }: SubsectionProps) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}` as const;
  const isSpecific = activeContext !== 'all';

  // Per-group overrides write to the group's own block; defaults write to playlist root.
  const showDateRangeField = isSpecific
    ? `${prefix}.grouping.staticClassifiers.${selectedIdx}.groupItem.showDateRange`
    : `${prefix}.groupItem.showDateRange`;

  return (
    <section className="space-y-3">
      <h5 className="text-sm font-semibold">{t('subsection.groups')}</h5>
      <InteractionNote i18nKey="interactionNote.displaySettings.yearBindingHeaders" />
      <div className="flex items-center gap-2">
        <Checkbox
          id={`playlist-${index}-group-${activeContext}-showDateRange`}
          checked={watch(showDateRangeField as never) ?? false}
          onCheckedChange={(c) =>
            setValue(showDateRangeField as never, !!c as never, { shouldDirty: true })
          }
        />
        <HintLabel
          htmlFor={`playlist-${index}-group-${activeContext}-showDateRange`}
          hint="showDateRange"
        >
          {t('showDateRange')}
        </HintLabel>
      </div>
    </section>
  );
}

function EpisodesSubsection({ index, activeContext, selectedIdx }: SubsectionProps) {
  const { watch, setValue } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');
  const prefix = `playlists.${index}` as const;
  const isSpecific = activeContext !== 'all';

  const groupPrefix = isSpecific
    ? `${prefix}.grouping.staticClassifiers.${selectedIdx}`
    : null;

  const sortPath = groupPrefix != null
    ? `${groupPrefix}.episodeListing.sort`
    : `${prefix}.episodeListing.sort`;

  const yearHeadersPath = groupPrefix != null
    ? `${groupPrefix}.episodeListing.showYearHeaders`
    : `${prefix}.episodeListing.showYearHeaders`;

  const titleExtractorPath = groupPrefix != null
    ? `${groupPrefix}.episodeItem.titleExtractor`
    : `${prefix}.episodeItem.titleExtractor`;

  return (
    <section className="space-y-3">
      <h5 className="text-sm font-semibold">{t('subsection.episodes')}</h5>
      <SortForm fieldPath={sortPath} idPrefix={`ep-sort-${index}-${activeContext}`} />
      <div className="flex items-center gap-2">
        <Checkbox
          id={`playlist-${index}-${activeContext}-showYearHeaders`}
          checked={watch(yearHeadersPath as never) ?? false}
          onCheckedChange={(c) =>
            setValue(yearHeadersPath as never, !!c as never, { shouldDirty: true })
          }
        />
        <HintLabel
          htmlFor={`playlist-${index}-${activeContext}-showYearHeaders`}
          hint="showYearHeaders"
        >
          {t('showYearHeaders')}
        </HintLabel>
      </div>
      <TitleExtractorForm
        fieldPath={titleExtractorPath}
        idPrefix={`ep-title-${index}-${activeContext}`}
      />
    </section>
  );
}
