import { useFormContext, useWatch } from 'react-hook-form';
import type { FieldPath, UseFormReturn } from 'react-hook-form';
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
import { usePreviewHighlight } from '@/hooks/use-preview-highlight.ts';
import { PREVIEW_FIELDS } from '@/components/editor/preview/preview-field-ids.ts';

// react-hook-form's generic resolution breaks on dynamically-composed paths; concentrate
// the necessary casts in these two helpers so call sites stay readable.
function watchPath<T>(
  watch: UseFormReturn<PatternConfig>['watch'],
  path: string,
): T | undefined {
  return watch(path as FieldPath<PatternConfig>) as T | undefined;
}

function setPath<T>(
  setValue: UseFormReturn<PatternConfig>['setValue'],
  path: string,
  value: T,
  options?: { shouldDirty?: boolean },
): void {
  setValue(path as FieldPath<PatternConfig>, value as never, options);
}

const YEAR_BINDING_OPTIONS = ['none', 'pinToYear', 'splitByYear'] as const;

interface DisplaySettingsTabProps {
  index: number;
}

export function DisplaySettingsTab({ index }: DisplaySettingsTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const playlistId = useWatch({ control, name: `${prefix}.id` as const });
  const partitionBy = watchPath<string>(watch, `${prefix}.selector.partitionBy`);
  const resolverType = watchPath<string>(watch, `${prefix}.grouping.by`);
  const staticClassifiers = (
    watchPath<Array<{ id: string; displayName: string }>>(watch, `${prefix}.grouping.staticClassifiers`) ?? []
  );

  const activeContext = useEditorStore((s) => s.getActiveGroupContext(playlistId ?? ''));
  const setActiveContext = useEditorStore((s) => s.setActiveGroupContext);
  const selectedIdx = staticClassifiers.findIndex((g) => g.id === activeContext);
  const isTitleClassifier = resolverType === 'titleClassifier';

  const selectorTitleExtractorHl = usePreviewHighlight(PREVIEW_FIELDS.selectorTitleExtractor);
  const groupListingSortHl = usePreviewHighlight(PREVIEW_FIELDS.groupListingSort);
  const groupListingYearBindingHl = usePreviewHighlight(PREVIEW_FIELDS.groupListingYearBinding);
  const groupItemPrependSeasonNumberHl = usePreviewHighlight(PREVIEW_FIELDS.groupItemPrependSeasonNumber);

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.displaySettings" />

      <div {...selectorTitleExtractorHl}>
        <SelectorBridge
          partitionBy={partitionBy as 'seasonNumber' | 'year' | undefined}
          partitionByLabel={t(`partitionBy_${partitionBy ?? 'none'}`)}
        >
          <TitleExtractorForm
            fieldPath={`${prefix}.selector.titleExtractor`}
            idPrefix={`selector-title-${index}`}
          />
        </SelectorBridge>
      </div>

      <ScopeZone tone="playlist" title={t('scope.playlist')} hint={t('scope.playlistHint')}>
        <div className="space-y-3">
          <div {...groupListingSortHl}>
            <SortForm
              fieldPath={`${prefix}.groupListing.sort`}
              idPrefix={`group-sort-${index}`}
            />
          </div>

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
              <SelectTrigger id={`playlist-${index}-yearBinding`} className="w-full" {...groupListingYearBindingHl}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {YEAR_BINDING_OPTIONS.map((o) => (
                  <SelectItem key={o} value={o}>{t(`yearBinding_${o}`)}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {resolverType === 'seasonNumber' ? (
            <div className="flex items-center gap-2" {...groupItemPrependSeasonNumberHl}>
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
          ) : null}

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

          {!isTitleClassifier && (
            <TitleExtractorForm
              fieldPath={`${prefix}.groupItem.titleExtractor`}
              idPrefix={`group-title-${index}`}
            />
          )}
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
                setPath(
                  setValue,
                  `${prefix}.grouping.staticClassifiers`,
                  [
                    ...staticClassifiers,
                    { id: newId, displayName: `Group ${staticClassifiers.length + 1}` },
                  ],
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

  const showDateRangeHl = usePreviewHighlight(PREVIEW_FIELDS.groupItemShowDateRange);

  // Per-group overrides write to the group's own block; defaults write to playlist root.
  const showDateRangeField = isSpecific
    ? `${prefix}.grouping.staticClassifiers.${selectedIdx}.groupItem.showDateRange`
    : `${prefix}.groupItem.showDateRange`;

  return (
    <section className="space-y-3">
      <h5 className="text-sm font-semibold">{t('subsection.groups')}</h5>
      <InteractionNote i18nKey="interactionNote.displaySettings.yearBindingHeaders" />
      <div className="flex items-center gap-2" {...showDateRangeHl}>
        <Checkbox
          id={`playlist-${index}-group-${activeContext}-showDateRange`}
          checked={watchPath<boolean>(watch, showDateRangeField) ?? false}
          onCheckedChange={(c) =>
            setPath(setValue, showDateRangeField, !!c, { shouldDirty: true })
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

  const episodeListingSortHl = usePreviewHighlight(PREVIEW_FIELDS.episodeListingSort);
  const episodeItemTitleHl = usePreviewHighlight(PREVIEW_FIELDS.episodeItemTitle);

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
      <div {...episodeListingSortHl}>
        <SortForm
          fieldPath={sortPath}
          idPrefix={`ep-sort-${index}-${activeContext}`}
          scope="episode"
        />
      </div>
      <div className="flex items-center gap-2">
        <Checkbox
          id={`playlist-${index}-${activeContext}-showYearHeaders`}
          checked={watchPath<boolean>(watch, yearHeadersPath) ?? false}
          onCheckedChange={(c) =>
            setPath(setValue, yearHeadersPath, !!c, { shouldDirty: true })
          }
        />
        <HintLabel
          htmlFor={`playlist-${index}-${activeContext}-showYearHeaders`}
          hint="showYearHeaders"
        >
          {t('showYearHeaders')}
        </HintLabel>
      </div>
      <div {...episodeItemTitleHl}>
        <TitleExtractorForm
          fieldPath={titleExtractorPath}
          idPrefix={`ep-title-${index}-${activeContext}`}
          labelKey="episodeTitleExtractor"
        />
      </div>
    </section>
  );
}
