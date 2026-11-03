import dagre from '@dagrejs/dagre';
import type { FamilyTree, PersonSummary } from '@/types/api';

export const UNIT_CARD_WIDTH = 208;
export const UNIT_CARD_HEIGHT = 142;
export const MEMBER_GAP = 10;
export const ROW_PITCH = 232;
export const LABEL_COLUMN_WIDTH = 148;
export const CANVAS_PADDING = 56;

export interface LayoutUnit {
  id: string;
  generation: number;
  x: number;
  y: number;
  width: number;
  height: number;
  members: PersonSummary[];
  parentUnitIds: string[];
  childUnitIds: string[];
}

export interface UnitEdge {
  id: string;
  source: string;
  target: string;
  parentIds: string[];
  childIds: string[];
}

export interface GenerationRow {
  generation: number;
  y: number;
  count: number;
  label: string;
}

export interface TreeLayoutResult {
  units: LayoutUnit[];
  edges: UnitEdge[];
  generations: GenerationRow[];
  width: number;
  height: number;
}

function compareMembers(a: PersonSummary, b: PersonSummary, familySurname: string): number {
  const aFamily = a.surname && a.surname === familySurname ? 0 : 1;
  const bFamily = b.surname && b.surname === familySurname ? 0 : 1;
  if (aFamily !== bFamily) return aFamily - bFamily;
  if (a.gender !== b.gender) {
    if (a.gender === 'male') return -1;
    if (b.gender === 'male') return 1;
  }
  const order = (a.birthOrder ?? 999) - (b.birthOrder ?? 999);
  if (order !== 0) return order;
  const birth = (a.birth?.year ?? 9999) - (b.birth?.year ?? 9999);
  if (birth !== 0) return birth;
  return a.fullName.localeCompare(b.fullName, 'zh-CN');
}

/**
 * 把「人物」聚合成「夫妻 / 单人家庭单元」，再交给 Dagre 计算层级布局。
 *
 * 为什么不直接让人物作为节点：
 * 1. 夫妻卡片必须并排，父母到子女的线应从这对夫妻的中轴落下；
 * 2. 同一个人只应出现一次，多配偶也能自然放在同一单元；
 * 3. Dagre 只在「家庭单元」图上求 x/层级，得到稳定的子树排序；
 *    最终 y 仍由真实世代号决定，避免婚姻边扰动世代。
 */
export function buildTreeLayout(
  tree: FamilyTree,
  options: { familySurname?: string } = {},
): TreeLayoutResult {
  const familySurname = options.familySurname?.trim() ?? '';
  const persons = tree.persons.filter((person) => person.status !== 'merged');
  const byId = new Map(persons.map((person) => [person.id, person]));

  const parent = new Map<string, string>();
  const find = (id: string): string => {
    let root = id;
    while (parent.get(root) && parent.get(root) !== root) root = parent.get(root)!;
    let current = id;
    while (current !== root) {
      const next = parent.get(current)!;
      parent.set(current, root);
      current = next;
    }
    return root;
  };
  const union = (a: string, b: string) => {
    const rootA = find(a);
    const rootB = find(b);
    if (rootA !== rootB) parent.set(rootB, rootA);
  };

  for (const person of persons) parent.set(person.id, person.id);

  for (const edge of tree.spouses) {
    if (edge.status === 'divorced') continue;
    const a = byId.get(edge.personAId);
    const b = byId.get(edge.personBId);
    if (!a || !b || a.generationNo !== b.generationNo) continue;
    union(a.id, b.id);
  }

  const groups = new Map<string, PersonSummary[]>();
  for (const person of persons) {
    const root = find(person.id);
    const list = groups.get(root) ?? [];
    list.push(person);
    groups.set(root, list);
  }

  const unitById = new Map<string, LayoutUnit>();
  const personUnit = new Map<string, string>();

  for (const members of groups.values()) {
    members.sort((a, b) => compareMembers(a, b, familySurname));
    const generation = members[0]?.generationNo ?? 1;
    const id = `unit:${members.map((member) => member.id).join('+')}`;
    const width = members.length * UNIT_CARD_WIDTH + (members.length - 1) * MEMBER_GAP;
    const unit: LayoutUnit = {
      id,
      generation,
      x: 0,
      y: 0,
      width,
      height: UNIT_CARD_HEIGHT,
      members,
      parentUnitIds: [],
      childUnitIds: [],
    };
    unitById.set(id, unit);
    for (const member of members) personUnit.set(member.id, id);
  }

  const edgePairs = new Map<string, UnitEdge>();
  const parentUnitChildren = new Map<string, Set<string>>();
  const childUnitParents = new Map<string, Set<string>>();

  for (const edge of tree.parentChild) {
    const parentUnitId = personUnit.get(edge.parentId);
    const childUnitId = personUnit.get(edge.childId);
    if (!parentUnitId || !childUnitId || parentUnitId === childUnitId) continue;
    const parentUnit = unitById.get(parentUnitId)!;
    const childUnit = unitById.get(childUnitId)!;
    if (parentUnit.generation >= childUnit.generation) continue;

    const key = `${parentUnitId}->${childUnitId}`;
    if (!edgePairs.has(key)) {
      edgePairs.set(key, {
        id: `edge:${key}`,
        source: parentUnitId,
        target: childUnitId,
        parentIds: [],
        childIds: [],
      });
      const children = parentUnitChildren.get(parentUnitId) ?? new Set<string>();
      children.add(childUnitId);
      parentUnitChildren.set(parentUnitId, children);
      const parents = childUnitParents.get(childUnitId) ?? new Set<string>();
      parents.add(parentUnitId);
      childUnitParents.set(childUnitId, parents);
    }
    const pair = edgePairs.get(key)!;
    if (!pair.parentIds.includes(edge.parentId)) pair.parentIds.push(edge.parentId);
    if (!pair.childIds.includes(edge.childId)) pair.childIds.push(edge.childId);
  }

  for (const unit of unitById.values()) {
    unit.parentUnitIds = Array.from(childUnitParents.get(unit.id) ?? []);
    unit.childUnitIds = Array.from(parentUnitChildren.get(unit.id) ?? []);
  }

  const graph = new dagre.graphlib.Graph();
  graph.setGraph({
    rankdir: 'TB',
    nodesep: 58,
    ranksep: 110,
    marginx: 40,
    marginy: 20,
    ranker: 'tight-tree',
  });
  graph.setDefaultEdgeLabel(() => ({}));

  for (const unit of unitById.values()) {
    graph.setNode(unit.id, { width: unit.width, height: UNIT_CARD_HEIGHT });
  }
  for (const edge of edgePairs.values()) {
    graph.setEdge(edge.source, edge.target, { weight: 1, minlen: 1 });
  }

  dagre.layout(graph);

  const generations = Array.from(new Set(persons.map((person) => person.generationNo))).sort(
    (a, b) => a - b,
  );
  const rowIndex = new Map(generations.map((generation, index) => [generation, index]));

  let minX = Number.POSITIVE_INFINITY;
  for (const unit of unitById.values()) {
    const node = graph.node(unit.id) as { x?: number } | undefined;
    minX = Math.min(minX, (node?.x ?? 0) - unit.width / 2);
  }
  if (!Number.isFinite(minX)) minX = 0;

  const sortedUnits = Array.from(unitById.values()).sort((a, b) => {
    if (a.generation !== b.generation) return a.generation - b.generation;
    const nodeA = graph.node(a.id) as { x?: number } | undefined;
    const nodeB = graph.node(b.id) as { x?: number } | undefined;
    return (nodeA?.x ?? 0) - (nodeB?.x ?? 0);
  });

  const unitsByGeneration = new Map<number, LayoutUnit[]>();
  for (const unit of sortedUnits) {
    const node = graph.node(unit.id) as { x?: number } | undefined;
    unit.x = (node?.x ?? unit.width / 2) - unit.width / 2 + (LABEL_COLUMN_WIDTH - minX);
    unit.y = CANVAS_PADDING + (rowIndex.get(unit.generation) ?? 0) * ROW_PITCH;
    const list = unitsByGeneration.get(unit.generation) ?? [];
    list.push(unit);
    unitsByGeneration.set(unit.generation, list);
  }

  // Dagre 的 rank 与真实世代不完全等价（孤立的婚姻单元可能同 rank）。
  // 将同世代单元按 x 排开，保证覆盖 y 后不会重叠。
  for (const list of unitsByGeneration.values()) {
    list.sort((a, b) => a.x - b.x);
    for (let index = 1; index < list.length; index += 1) {
      const prev = list[index - 1];
      const current = list[index];
      const minimum = prev.x + prev.width + 34;
      if (current.x < minimum) current.x = minimum;
    }
  }

  const units = sortedUnits;
  let maxX = 0;
  let maxY = 0;
  for (const unit of units) {
    maxX = Math.max(maxX, unit.x + unit.width);
    maxY = Math.max(maxY, unit.y + unit.height);
  }

  const generationRows: GenerationRow[] = generations.map((generation) => ({
    generation,
    y: CANVAS_PADDING + (rowIndex.get(generation) ?? 0) * ROW_PITCH,
    count: persons.filter((person) => person.generationNo === generation).length,
    label: `第${toChineseNumber(generation)}世`,
  }));

  return {
    units,
    edges: Array.from(edgePairs.values()),
    generations: generationRows,
    width: Math.max(960, maxX + CANVAS_PADDING),
    height: Math.max(560, maxY + CANVAS_PADDING + 20),
  };
}

export function toChineseNumber(value: number): string {
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

/** 找到包含指定人物的家庭单元，用于搜索定位。 */
export function findUnitForPerson(
  layout: TreeLayoutResult,
  personId: string,
): LayoutUnit | undefined {
  return layout.units.find((unit) => unit.members.some((member) => member.id === personId));
}
