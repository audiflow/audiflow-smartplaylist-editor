import { GroupsForm } from '@/components/editor/groups-form.tsx';
import { SectionNote, InteractionNote } from '@/components/editor/note-blocks.tsx';

interface GroupsTabProps {
  index: number;
}

export function GroupsTab({ index }: GroupsTabProps) {
  return (
    <div className="space-y-4">
      <SectionNote i18nKey="sectionNote.groups" />
      <InteractionNote i18nKey="interactionNote.groups.overrides" />
      <GroupsForm index={index} />
    </div>
  );
}
