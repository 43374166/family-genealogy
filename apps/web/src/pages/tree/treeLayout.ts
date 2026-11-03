import type { FamilyTree, PersonSummary } from '@/types/api';

export const UNIT_CARD_WIDTH = 132;
export const UNIT_CARD_HEIGHT = 148;
export const MEMBER_GAP = 10;
export const CHILD_GAP = 34;
export const FAMILY_GAP = 68;
export const ROW_PITCH = 226;
export const LABEL_COLUMN_WIDTH = 148;
export const CANVAS_PADDING = 56;
const CONTENT_LEFT = LABEL_COLUMN_WIDTH + 28;

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

/** A visible father/mother-to-child line. Two parents produce two lines. */
export interface FamilyConnection {
  id: string;
  source: string;
  target: string;
  sourceHandle: string;
  targetHandle: string;
  parentId: string;
  childId: string;
  gender: PersonSummary['gender'];
  /** Small vertical stagger so children of different marriages do not share one bar. */
  barOffset: number;
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
  connections: FamilyConnection[];
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
 * 以 Flutter 端的森林布局为基准重写：
 * 1. 夫妻/多配偶聚合成一个家庭单元；
 * 2. 每个子单元只挂到一个布局父单元，避免同一棵子树被画两次；
 * 3. 父单元居中在子女子树之上，子女按子代数量和出生顺序从左到右排开；
 * 4. 不同根支之间保留更大的间距，不再把所有单元挤成一条直线。
 *
 * 这与之前的 Dagre + 每代强制左对齐不同：树会真正“长开”，每个支系有独立
 * 的水平空间，连线也更容易看清。
 */
export function buildTreeLayout(
  tree: FamilyTree,
  options: { familySurname?: string } = {},
): TreeLayoutResult {
  const familySurname = options.familySurname?.trim() ?? '';
  const persons = tree.persons.filter((person) => person.status !== 'merged');
  const byId = new Map(persons.map((person) => [person.id, person]));

  // ---------- 1. 家庭单元 ----------
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

  // ---------- 2. 家庭之间的父母子女关系 ----------
  const edgePairs = new Map<string, UnitEdge>();
  const parentChildren = new Map<string, Set<string>>();
  const childParents = new Map<string, Set<string>>();
  for (const edge of tree.parentChild) {
    if (edge.status && edge.status !== 'active') continue;
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
      const children = parentChildren.get(parentUnitId) ?? new Set<string>();
      children.add(childUnitId);
      parentChildren.set(parentUnitId, children);
      const parents = childParents.get(childUnitId) ?? new Set<string>();
      parents.add(parentUnitId);
      childParents.set(childUnitId, parents);
    }
    const pair = edgePairs.get(key)!;
    if (!pair.parentIds.includes(edge.parentId)) pair.parentIds.push(edge.parentId);
    if (!pair.childIds.includes(edge.childId)) pair.childIds.push(edge.childId);
  }

  for (const unit of unitById.values()) {
    unit.parentUnitIds = Array.from(childParents.get(unit.id) ?? []);
    unit.childUnitIds = Array.from(parentChildren.get(unit.id) ?? []);
  }

  // ---------- 3. 子代数量（只用于同层排序） ----------
  const childrenByPerson = new Map<string, string[]>();
  for (const edge of tree.parentChild) {
    if (edge.status && edge.status !== 'active') continue;
    const list = childrenByPerson.get(edge.parentId) ?? [];
    list.push(edge.childId);
    childrenByPerson.set(edge.parentId, list);
  }
  const descendantMemo = new Map<string, number>();
  const descendantCount = (personId: string, visiting = new Set<string>()): number => {
    const cached = descendantMemo.get(personId);
    if (cached !== undefined) return cached;
    if (visiting.has(personId)) return 0;
    visiting.add(personId);
    let total = 0;
    for (const childId of childrenByPerson.get(personId) ?? []) {
      total += 1 + descendantCount(childId, visiting);
    }
    visiting.delete(personId);
    descendantMemo.set(personId, total);
    return total;
  };
  const unitScore = (unit: LayoutUnit): number =>
    Math.max(0, ...unit.members.map((member) => descendantCount(member.id)));
  const sortUnits = (a: LayoutUnit, b: LayoutUnit): number =>
    unitScore(b) - unitScore(a) ||
    compareMembers(a.members[0], b.members[0], familySurname);

  // ---------- 4. 每棵子树只挂一个父单元 ----------
  const layoutChildren = new Map<string, Set<string>>();
  for (const unit of unitById.values()) {
    layoutChildren.set(unit.id, new Set());
  }
  for (const unit of unitById.values()) {
    for (const childUnitId of unit.childUnitIds) {
      layoutChildren.get(unit.id)?.add(childUnitId);
    }
  }

  const layoutParent = new Map<string, string>();
  for (const unit of unitById.values()) {
    if (!unit.parentUnitIds.length) continue;
    const preferredParent = unit.parentUnitIds
      .map((id) => unitById.get(id)!)
      .sort(sortUnits)[0];
    layoutParent.set(unit.id, preferredParent.id);
    for (const parentId of unit.parentUnitIds) {
      if (parentId !== preferredParent.id) layoutChildren.get(parentId)?.delete(unit.id);
    }
  }

  const sortedChildren = (unit: LayoutUnit): LayoutUnit[] =>
    Array.from(layoutChildren.get(unit.id) ?? [])
      .map((id) => unitById.get(id)!)
      .filter(Boolean)
      .sort(sortUnits);

  // ---------- 5. 森林布局：先算子树宽，再居中放置 ----------
  const subtreeWidthCache = new Map<string, number>();
  const subtreeWidth = (unit: LayoutUnit): number => {
    const cached = subtreeWidthCache.get(unit.id);
    if (cached !== undefined) return cached;
    const children = sortedChildren(unit);
    let childrenWidth = 0;
    children.forEach((child, index) => {
      childrenWidth += subtreeWidth(child);
      if (index !== children.length - 1) childrenWidth += CHILD_GAP;
    });
    const width = Math.max(unit.width, childrenWidth);
    subtreeWidthCache.set(unit.id, width);
    return width;
  };

  const placeUnit = (unit: LayoutUnit, left: number) => {
    const width = subtreeWidth(unit);
    unit.x = left + (width - unit.width) / 2;
    const children = sortedChildren(unit);
    if (!children.length) return;
    let childrenWidth = 0;
    children.forEach((child, index) => {
      childrenWidth += subtreeWidth(child);
      if (index !== children.length - 1) childrenWidth += CHILD_GAP;
    });
    let childLeft = left + (width - childrenWidth) / 2;
    for (const child of children) {
      placeUnit(child, childLeft);
      childLeft += subtreeWidth(child) + CHILD_GAP;
    }
  };

  const generations = Array.from(new Set(persons.map((person) => person.generationNo))).sort(
    (a, b) => a - b,
  );
  const generationY = new Map(
    generations.map((generation, index) => [generation, CANVAS_PADDING + index * ROW_PITCH]),
  );
  for (const unit of unitById.values()) {
    unit.y = generationY.get(unit.generation) ?? CANVAS_PADDING;
  }

  const roots = Array.from(unitById.values())
    .filter((unit) => !layoutParent.has(unit.id))
    .sort((a, b) => a.generation - b.generation || sortUnits(a, b));

  let cursor = CONTENT_LEFT;
  for (const root of roots) {
    placeUnit(root, cursor);
    cursor += subtreeWidth(root) + FAMILY_GAP;
  }

  const units = Array.from(unitById.values()).sort((a, b) => {
    if (a.generation !== b.generation) return a.generation - b.generation;
    return a.x - b.x;
  });

  let maxX = 0;
  let maxY = 0;
  for (const unit of units) {
    maxX = Math.max(maxX, unit.x + unit.width);
    maxY = Math.max(maxY, unit.y + unit.height);
  }

  // 每个父/母各自连到具体子女。二婚/一夫多妻时，不同妻子的子女线会从
  // 各自母亲卡片出发，不会被合并到家庭单元中心。
  const parentsByChild = new Map<string, string[]>();
  for (const edge of tree.parentChild) {
    if (edge.status && edge.status !== 'active') continue;
    const list = parentsByChild.get(edge.childId) ?? [];
    list.push(edge.parentId);
    parentsByChild.set(edge.childId, list);
  }
  const groupOffsets = new Map<string, number>();
  let groupIndex = 0;
  for (const parentIds of parentsByChild.values()) {
    const key = [...parentIds].sort().join('+');
    if (!groupOffsets.has(key)) {
      groupOffsets.set(key, ((groupIndex % 5) - 2) * 6);
      groupIndex += 1;
    }
  }

  const connections: FamilyConnection[] = [];
  for (const edge of tree.parentChild) {
    if (edge.status && edge.status !== 'active') continue;
    const parentPerson = byId.get(edge.parentId);
    const childPerson = byId.get(edge.childId);
    const parentUnitId = personUnit.get(edge.parentId);
    const childUnitId = personUnit.get(edge.childId);
    if (
      !parentPerson ||
      !childPerson ||
      !parentUnitId ||
      !childUnitId ||
      parentUnitId === childUnitId
    ) {
      continue;
    }
    if (parentPerson.generationNo >= childPerson.generationNo) continue;
    const parents = parentsByChild.get(edge.childId) ?? [edge.parentId];
    const groupKey = [...parents].sort().join('+');
    connections.push({
      id: `connection:${edge.id}`,
      source: parentUnitId,
      target: childUnitId,
      sourceHandle: `person:${edge.parentId}`,
      targetHandle: `target:${edge.childId}`,
      parentId: edge.parentId,
      childId: edge.childId,
      gender: parentPerson.gender,
      barOffset: groupOffsets.get(groupKey) ?? 0,
    });
  }

  const generationRows: GenerationRow[] = generations.map((generation) => ({
    generation,
    y: generationY.get(generation) ?? CANVAS_PADDING,
    count: persons.filter((person) => person.generationNo === generation).length,
    label: `第${toChineseNumber(generation)}世`,
  }));

  return {
    units,
    edges: Array.from(edgePairs.values()),
    connections,
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

/** 返回人物卡片在自己的家庭单元内的中心点，而不是整个单元的中心。 */
export function findPersonAnchor(
  layout: TreeLayoutResult,
  personId: string,
): { x: number; y: number } | undefined {
  const unit = findUnitForPerson(layout, personId);
  if (!unit) return undefined;
  const index = unit.members.findIndex((member) => member.id === personId);
  if (index < 0) return undefined;
  return {
    x: unit.x + index * (UNIT_CARD_WIDTH + MEMBER_GAP) + UNIT_CARD_WIDTH / 2,
    y: unit.y + unit.height / 2,
  };
}
