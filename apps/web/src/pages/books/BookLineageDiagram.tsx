import type { ParentChildEdge, PersonSummary } from '@/types/api';

const WIDTH = 346;
const HEIGHT = 470;

function generationText(value: number): string {
  const numerals = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  if (value <= 10) return value === 10 ? '十' : numerals[value] ?? String(value);
  if (value < 20) return `十${numerals[value % 10]}`;
  if (value < 100) {
    const tens = Math.floor(value / 10);
    const ones = value % 10;
    return `${numerals[tens]}十${ones ? numerals[ones] : ''}`;
  }
  return String(value);
}

export function BookLineageDiagram({
  persons,
  edges,
}: {
  persons: PersonSummary[];
  edges: ParentChildEdge[];
}) {
  const generations = Array.from(new Set(persons.map((person) => person.generationNo))).sort(
    (a, b) => a - b,
  );
  const byId = new Map(persons.map((person) => [person.id, person]));
  const points = new Map<string, { x: number; y: number; boxW: number; boxH: number }>();
  const rowHeight = generations.length > 1 ? Math.min(108, 410 / (generations.length - 1)) : 0;
  const top = 22;
  const left = 44;
  const drawable = WIDTH - left - 10;

  generations.forEach((generation, rowIndex) => {
    const list = persons
      .filter((person) => person.generationNo === generation)
      .sort((a, b) => {
        const order = (a.birthOrder ?? 999) - (b.birthOrder ?? 999);
        return order || a.fullName.localeCompare(b.fullName, 'zh-CN');
      });
    const step = Math.min(58, drawable / Math.max(1, list.length));
    const boxW = Math.max(17, Math.min(38, step - 3));
    const boxH = 24;
    const rowWidth = step * list.length;
    const start = left + (drawable - rowWidth) / 2;
    list.forEach((person, index) => {
      points.set(person.id, {
        x: start + step * (index + 0.5),
        y: top + rowIndex * rowHeight,
        boxW,
        boxH,
      });
    });
  });

  const visibleEdges = edges.filter(
    (edge) =>
      edge.status !== 'inactive' &&
      points.has(edge.parentId) &&
      points.has(edge.childId) &&
      byId.has(edge.parentId) &&
      byId.has(edge.childId),
  );

  return (
    <div className="book-lineage-diagram">
      <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} role="img" aria-label="世系吊线图">
        <defs>
          <filter id="book-node-shadow" x="-20%" y="-30%" width="140%" height="170%">
            <feDropShadow dx="0" dy="1" stdDeviation="1" floodOpacity="0.08" />
          </filter>
        </defs>
        {generations.map((generation, rowIndex) => (
          <g key={`label-${generation}`}>
            <text
              x="4"
              y={top + rowIndex * rowHeight + 15}
              className="book-lineage-diagram__generation"
            >
              第{generationText(generation)}世
            </text>
            <line
              x1="4"
              x2="38"
              y1={top + rowIndex * rowHeight + 21}
              y2={top + rowIndex * rowHeight + 21}
              className="book-lineage-diagram__rule"
            />
          </g>
        ))}
        {visibleEdges.map((edge) => {
          const parent = points.get(edge.parentId)!;
          const child = points.get(edge.childId)!;
          const midY = parent.y + parent.boxH + (child.y - parent.y - parent.boxH) * 0.48;
          const sx = parent.x;
          const sy = parent.y + parent.boxH;
          const tx = child.x;
          const ty = child.y;
          const isMother = byId.get(edge.parentId)?.gender === 'female';
          return (
            <path
              key={edge.id}
              d={`M ${sx} ${sy} L ${sx} ${midY} L ${tx} ${midY} L ${tx} ${ty}`}
              className={`book-lineage-diagram__edge ${isMother ? 'is-female' : 'is-male'}`}
            />
          );
        })}
        {persons.map((person) => {
          const point = points.get(person.id);
          if (!point) return null;
          const fontSize = Math.max(
            4.2,
            Math.min(7, (point.boxW - 3) / Math.max(2.2, person.fullName.length)),
          );
          return (
            <g key={person.id} transform={`translate(${point.x}, ${point.y})`}>
              <rect
                x={-point.boxW / 2}
                y="0"
                width={point.boxW}
                height={point.boxH}
                rx="1.5"
                className={`book-lineage-diagram__node ${
                  person.lifeStatus === 'deceased' ? 'is-deceased' : ''
                }`}
                filter="url(#book-node-shadow)"
              />
              <text
                x="0"
                y={point.boxH / 2 + 1}
                className="book-lineage-diagram__name"
                style={{ fontSize }}
              >
                {person.fullName}
              </text>
            </g>
          );
        })}
      </svg>
      <div className="book-lineage-diagram__legend">
        <span><i className="is-male" />父系</span>
        <span><i className="is-female" />母系</span>
        <span>按世代自上而下排列</span>
      </div>
    </div>
  );
}
