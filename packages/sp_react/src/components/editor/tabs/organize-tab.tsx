import { useFormContext, useWatch, useFieldArray } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import type { PatternConfig, ResolverType } from '@/schemas/config-schema.ts';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select.tsx';
import { HintLabel } from '@/components/editor/hint-label.tsx';
import { NumberingExtractorForm } from '@/components/editor/numbering-extractor-form.tsx';
import { GroupDefCard } from '@/components/editor/group-def-card.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';
import { ScopeZone } from '@/components/editor/shared/scope-zone.tsx';
import { GroupContextBar } from '@/components/editor/shared/group-context-bar.tsx';
import { useEditorStore } from '@/stores/editor-store.ts';

const RESOLVER_TYPES = ['seasonNumber', 'year', 'titleDiscovery', 'titleClassifier'] as const;
const PARTITION_OPTIONS = ['group', 'seasonNumber', 'year'] as const;

interface OrganizeTabProps {
  index: number;
  playlistCount: number;
}

export function OrganizeTab({ index }: OrganizeTabProps) {
  const prefix = `playlists.${index}` as const;
  const { watch, setValue, control } = useFormContext<PatternConfig>();
  const { t } = useTranslation('editor');

  const playlistId = useWatch({ control, name: `${prefix}.id` as const });
  const grouping = watch(`${prefix}.grouping`);
  const resolverType = grouping?.by;
  const partitionBy = watch(`${prefix}.selector.partitionBy`);
  const staticClassifiers = (grouping?.staticClassifiers ?? []) as Array<{ id: string; displayName: string }>;

  const { move, remove } = useFieldArray({
    control,
    name: `${prefix}.grouping.staticClassifiers`,
  });

  const activeContext = useEditorStore((s) => s.getActiveGroupContext(playlistId ?? ''));
  const setActiveContext = useEditorStore((s) => s.setActiveGroupContext);
  const resetActiveContext = useEditorStore((s) => s.resetActiveGroupContext);

  const selectedGroupIndex = staticClassifiers.findIndex((g) => g.id === activeContext);
  const isTitleClassifier = resolverType === 'titleClassifier';

  const onGroupingByChange = (val: ResolverType) => {
    setValue(`${prefix}.grouping.by`, val, { shouldDirty: true });
    if (val !== 'titleClassifier') resetActiveContext(playlistId ?? '');
  };

  const onAddGroup = () => {
    const current = staticClassifiers;
    const newId = `group-${current.length + 1}`;
    setValue(
      `${prefix}.grouping.staticClassifiers`,
      [...current, { id: newId, displayName: `Group ${current.length + 1}` }] as never,
      { shouldDirty: true },
    );
    setActiveContext(playlistId ?? '', newId);
  };

  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.resolver" />

      <ScopeZone tone="playlist" title={t('scope.playlist')} hint={t('scope.playlistHint')}>
        <div className="space-y-2">
          <HintLabel htmlFor={`playlist-${index}-resolverType`} hint="resolverType">
            {t('resolverType')}
          </HintLabel>
          <Select value={resolverType ?? ''} onValueChange={(v) => onGroupingByChange(v as ResolverType)}>
            <SelectTrigger id={`playlist-${index}-resolverType`} className="w-full">
              <SelectValue placeholder={t('selectResolver')} />
            </SelectTrigger>
            <SelectContent className="min-w-[280px]">
              {RESOLVER_TYPES.map((type) => (
                <SelectItem key={type} value={type} description={t(`resolverDesc_${type}`)}>
                  {t(`resolverLabel_${type}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <HintLabel htmlFor={`playlist-${index}-partitionBy`} hint="partitionBy">
            {t('partitionBy')}
          </HintLabel>
          <Select
            value={partitionBy ?? 'group'}
            onValueChange={(v) =>
              setValue(
                `${prefix}.selector.partitionBy`,
                v as typeof PARTITION_OPTIONS[number],
                { shouldDirty: true },
              )
            }
          >
            <SelectTrigger id={`playlist-${index}-partitionBy`} className="w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {PARTITION_OPTIONS.map((opt) => (
                <SelectItem key={opt} value={opt}>{t(`partitionBy_${opt}`)}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </ScopeZone>

      <ScopeZone
        tone="pergroup"
        title={t('scope.pergroup')}
        hint={
          activeContext === 'all'
            ? t('scope.pergroupHint_defaults')
            : t('scope.pergroupHint_specific', {
                group: staticClassifiers[selectedGroupIndex]?.displayName ?? '',
              })
        }
      >
        {isTitleClassifier ? (
          <GroupContextBar
            groups={staticClassifiers}
            active={activeContext}
            allLabel={t('context.allGroups')}
            addLabel={t('context.addGroup')}
            onSelect={(id) => setActiveContext(playlistId ?? '', id)}
            onAdd={onAddGroup}
          />
        ) : null}

        {activeContext === 'all' ? (
          <>
            <InteractionNote i18nKey="interactionNote.resolver.numberingExtractor" />
            <NumberingExtractorForm
              fieldPath={`${prefix}.grouping.numberingExtractor`}
              idPrefix={`ep-ext-${index}`}
            />
          </>
        ) : (
          isTitleClassifier && 0 <= selectedGroupIndex ? (
            <GroupDefCard
              playlistIndex={index}
              groupIndex={selectedGroupIndex}
              isFirst={selectedGroupIndex === 0}
              isLast={selectedGroupIndex === staticClassifiers.length - 1}
              onMoveUp={() => move(selectedGroupIndex, selectedGroupIndex - 1)}
              onMoveDown={() => move(selectedGroupIndex, selectedGroupIndex + 1)}
              onRemove={() => {
                remove(selectedGroupIndex);
                resetActiveContext(playlistId ?? '');
              }}
            />
          ) : null
        )}
      </ScopeZone>
    </div>
  );
}
