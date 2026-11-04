/* eslint-disable react-refresh/only-export-components */
import { createContext, memo, useContext } from 'react';
import {
  Handle,
  Position,
  type Edge,
  type EdgeProps,
  type Node,
  type NodeProps,
} from '@xyflow/react';
import type { PersonSummary } from '@/types/api';
import { UNIT_CARD_WIDTH, type GenerationRow, type LayoutUnit } from './treeLayout';
import { cn } from '@/utils/cn';
import { generationShort } from '@/utils/format';
import { familyEdgePath } from './treeEdgePath';
import { TreePersonCardContent } from './TreePersonCardContent';

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

export type FamilyFlowEdge = Edge<
  { dimmed: boolean; gender?: string; barOffset?: number },
  'family'
>;

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
      <div className="tree-unit__members">
        {unit.members.map((member, index) => {
          const selected = member.id === selectedPersonId;
          const matched = matchedPersonIds.has(member.id);
          return (
            <div className="tree-unit__member-wrap" key={member.id}>
              <Handle
                type="target"
                position={Position.Top}
                id={`target:${member.id}`}
                className="tree-handle tree-handle--target"
              />
              <Handle
                type="source"
                position={Position.Bottom}
                id={`person:${member.id}`}
                className="tree-handle tree-handle--source"
              />
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
                style={{ width: UNIT_CARD_WIDTH, height: unit.height }}
                title={`${member.fullName} · ${generationShort(member.generationNo)}`}
                onClick={(event) => {
                  event.stopPropagation();
                  onSelectPerson(member);
                }}
              >
                <TreePersonCardContent member={member} selected={selected} />
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
});

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
  const path = familyEdgePath({
    sourceX,
    sourceY,
    targetX,
    targetY,
    barOffset: data?.barOffset,
    gender: data?.gender,
  });

  return (
    <path
      d={path}
      fill="none"
      className={cn(
        'react-flow__edge-path family-edge-path',
        data?.gender === 'male' && 'is-male',
        data?.gender === 'female' && 'is-female',
        data?.dimmed && 'is-dimmed',
      )}
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
