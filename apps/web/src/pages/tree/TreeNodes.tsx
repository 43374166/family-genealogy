/* eslint-disable react-refresh/only-export-components */
import { createContext, memo, useContext } from 'react';
import {
  Handle,
  Position,
  getSmoothStepPath,
  type Edge,
  type EdgeProps,
  type Node,
  type NodeProps,
} from '@xyflow/react';
import { PersonAvatar } from '@/components/PersonAvatar';
import type { PersonSummary } from '@/types/api';
import { dualCalendarDate, type DualCalendarDate } from '@/utils/calendar';
import {
  UNIT_CARD_HEIGHT,
  UNIT_CARD_WIDTH,
  type GenerationRow,
  type LayoutUnit,
} from './treeLayout';
import { cn } from '@/utils/cn';
import { genderLabel, generationShort, lifeYears } from '@/utils/format';

export type FamilyUnitNode = Node<
  {
    unit: LayoutUnit;
    dimmed: boolean;
  },
  'familyUnit'
>;

export type GenerationNode = Node<
  {
    row: GenerationRow;
    dimmed: boolean;
  },
  'generation'
>;

export type FamilyFlowEdge = Edge<{ dimmed: boolean }, 'family'>;

export interface TreeInteraction {
  selectedPersonId: string | null;
  matchedPersonIds: Set<string>;
  onSelectPerson: (person: PersonSummary) => void;
}

export const TreeInteractionContext = createContext<TreeInteraction>({
  selectedPersonId: null,
  matchedPersonIds: new Set(),
  onSelectPerson: () => undefined,
});

export const FamilyUnitNodeView = memo(function FamilyUnitNodeView({
  data,
}: NodeProps<FamilyUnitNode>) {
  const { unit, dimmed } = data;
  const { selectedPersonId, matchedPersonIds, onSelectPerson } =
    useContext(TreeInteractionContext);
  const hasSelected = unit.members.some((member) => member.id === selectedPersonId);

  return (
    <div
      className={cn(
        'tree-unit',
        dimmed && 'is-dimmed',
        hasSelected && 'has-selected',
        unit.members.length > 1 && 'is-couple',
      )}
      style={{ width: unit.width, height: unit.height }}
    >
      <Handle type="target" position={Position.Top} className="tree-handle" />
      <div className="tree-unit__members">
        {unit.members.map((member, index) => {
          const selected = member.id === selectedPersonId;
          const matched = matchedPersonIds.has(member.id);
          const birth = dualCalendarDate(member.birth);
          const death = dualCalendarDate(member.death);
          return (
            <div className="tree-unit__member-wrap" key={member.id}>
              {index > 0 ? (
                <span className="tree-unit__bond" aria-hidden>
                  <i />
                </span>
              ) : null}
              <button
                type="button"
                className={cn(
                  'tree-person',
                  selected && 'is-selected',
                  matched && 'is-matched',
                  member.lifeStatus === 'deceased' && 'is-deceased',
                )}
                style={{ width: UNIT_CARD_WIDTH, height: UNIT_CARD_HEIGHT }}
                title={`${member.fullName} · ${generationShort(member.generationNo)}`}
                onClick={(event) => {
                  event.stopPropagation();
                  onSelectPerson(member);
                }}
              >
                <PersonAvatar person={member} size={44} ring={selected} />
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
                  <span className="tree-person__calendar">
                    {birth ? <TreeCalendarLine label="生" date={birth} /> : null}
                    {death ? <TreeCalendarLine label="卒" date={death} /> : null}
                  </span>
                </span>
              </button>
            </div>
          );
        })}
      </div>
      <Handle type="source" position={Position.Bottom} className="tree-handle" />
    </div>
  );
});

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

export const GenerationNodeView = memo(function GenerationNodeView({
  data,
}: NodeProps<GenerationNode>) {
  return (
    <div className={cn('tree-generation-label', data.dimmed && 'is-dimmed')}>
      <span className="tree-generation-label__text">{data.row.label}</span>
      <span className="tree-generation-label__count">{data.row.count} 人</span>
      <span className="tree-generation-label__rule" />
    </div>
  );
});

export function FamilyEdgeView({
  sourceX,
  sourceY,
  targetX,
  targetY,
  data,
}: EdgeProps<FamilyFlowEdge>) {
  const [path] = getSmoothStepPath({
    sourceX,
    sourceY,
    targetX,
    targetY,
    borderRadius: 20,
    offset: 24,
  });

  return (
    <path
      d={path}
      fill="none"
      className={cn('react-flow__edge-path family-edge-path', data?.dimmed && 'is-dimmed')}
    />
  );
}

export const treeNodeTypes = {
  familyUnit: FamilyUnitNodeView,
  generation: GenerationNodeView,
};

export const treeEdgeTypes = {
  family: FamilyEdgeView,
};
