import { forwardRef } from 'react';
import {
  UNIT_CARD_WIDTH,
  type FamilyConnection,
  type TreeLayoutResult,
} from './treeLayout';
import { familyEdgePath } from './treeEdgePath';
import { TreePersonCardContent } from './TreePersonCardContent';

function connectionPoint(
  layout: TreeLayoutResult,
  connection: FamilyConnection,
  side: 'source' | 'target',
): { x: number; y: number } | null {
  const unitId = side === 'source' ? connection.source : connection.target;
  const personId = side === 'source' ? connection.parentId : connection.childId;
  const unit = layout.units.find((item) => item.id === unitId);
  if (!unit) return null;
  const index = unit.members.findIndex((member) => member.id === personId);
  if (index < 0) return null;
  return {
    x: unit.x + index * (UNIT_CARD_WIDTH + 10) + UNIT_CARD_WIDTH / 2,
    y: side === 'source' ? unit.y + unit.height : unit.y,
  };
}

export const TreeExportView = forwardRef<
  HTMLDivElement,
  { layout: TreeLayoutResult; familyName: string }
>(function TreeExportView({ layout, familyName }, ref) {
  return (
    <div
      ref={ref}
      className="tree-print"
      style={{ width: layout.width, height: layout.height }}
      aria-hidden
    >
      <div className="tree-print__title">
        <span>{familyName || '家族'} · 族谱全图</span>
        <small>共 {layout.units.reduce((sum, unit) => sum + unit.members.length, 0)} 人</small>
      </div>
      <svg
        className="tree-print__edges"
        width={layout.width}
        height={layout.height}
        viewBox={`0 0 ${layout.width} ${layout.height}`}
      >
        {layout.connections.map((connection) => {
          const source = connectionPoint(layout, connection, 'source');
          const target = connectionPoint(layout, connection, 'target');
          if (!source || !target) return null;
          return (
            <path
              key={connection.id}
              d={familyEdgePath({
                sourceX: source.x,
                sourceY: source.y,
                targetX: target.x,
                targetY: target.y,
                barOffset: connection.barOffset,
                gender: connection.gender,
              })}
              fill="none"
              stroke={
                connection.gender === 'male'
                  ? 'rgba(74, 119, 164, 0.55)'
                  : 'rgba(184, 102, 112, 0.5)'
              }
              strokeWidth={1.2}
              strokeLinecap="round"
              className={`family-edge-path is-${connection.gender}`}
            />
          );
        })}
      </svg>
      {layout.generations.map((row) => (
        <div
          className="tree-print__generation"
          key={row.generation}
          style={{ top: row.y + 22 }}
        >
          <strong>{row.label}</strong>
          <span>{row.count} 人</span>
        </div>
      ))}
      {layout.units.map((unit) => (
        <div
          className="tree-print__unit"
          key={unit.id}
          style={{ left: unit.x, top: unit.y, width: unit.width, height: unit.height }}
        >
          {unit.members.map((member, index) => (
            <div
              className="tree-print__card"
              key={member.id}
              style={{
                left: index * (UNIT_CARD_WIDTH + 10),
                top: 0,
                width: UNIT_CARD_WIDTH,
                height: unit.height,
              }}
            >
              <div
                className={`tree-person ${member.lifeStatus === 'deceased' ? 'is-deceased' : ''}`}
                style={{ width: UNIT_CARD_WIDTH, height: unit.height }}
              >
                <TreePersonCardContent member={member} />
              </div>
            </div>
          ))}
        </div>
      ))}
      <span className="tree-print__mark">FAMILY TREE · 家族谱系</span>
    </div>
  );
});
