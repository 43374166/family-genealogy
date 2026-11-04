import { PersonAvatar } from '@/components/PersonAvatar';
import type { PersonSummary } from '@/types/api';
import { dualCalendarDate, type DualCalendarDate } from '@/utils/calendar';
import { cn } from '@/utils/cn';
import { genderLabel, lifeYears } from '@/utils/format';

function TreeCalendarLine({ label, date }: { label: string; date: DualCalendarDate }) {
  return (
    <span className="tree-person__calendar-row">
      <em>{label}</em>
      <span>
        <strong>{date.primary}</strong>
        {date.secondary ? <small>{date.secondary}</small> : null}
      </span>
    </span>
  );
}

export function TreePersonCardContent({
  member,
  selected = false,
}: {
  member: PersonSummary;
  selected?: boolean;
}) {
  const birth = dualCalendarDate(member.birth);
  const death = dualCalendarDate(member.death);
  return (
    <>
      <PersonAvatar person={member} size={38} ring={selected} />
      <span className="tree-person__body">
        <span className="tree-person__name-row">
          <strong>{member.fullName}</strong>
          <i
            className={cn(
              'tree-person__gender',
              member.gender === 'female' ? 'is-female' : 'is-male',
            )}
          >
            {genderLabel(member.gender)}
          </i>
        </span>
        <span className="tree-person__years">{lifeYears(member)}</span>
        <span className="tree-person__meta">
          <em>{member.generationName || member.generationLabel}</em>
          {birth?.zodiac ? (
            <em className="tree-person__zodiac" title={`生肖${birth.zodiac}`}>
              生肖{birth.zodiac}
            </em>
          ) : null}
          {member.hasAvatar ? <span className="tree-person__avatar-dot" /> : null}
        </span>
        {birth || death ? (
          <span className="tree-person__calendar">
            {birth ? <TreeCalendarLine label="生" date={birth} /> : null}
            {death ? <TreeCalendarLine label="卒" date={death} /> : null}
          </span>
        ) : null}
      </span>
    </>
  );
}
