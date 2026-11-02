import { ApiPerson, ApiTree } from './Types';

const WIDE_W: number = 150;
const WIDE_H: number = 82;
const COMPACT_W: number = 96;
const COMPACT_H: number = 128;
const MEMBER_GAP: number = 14;
const CHILD_GAP: number = 30;
const FAMILY_GAP: number = 92;
const GEN_GAP: number = 78;
const LEFT: number = 80;
const RIGHT: number = 28;
const TOP: number = 28;
const BOTTOM: number = 30;

export interface PersonBox {
  person: ApiPerson;
  x: number;
  y: number;
  width: number;
  height: number;
  compact: boolean;
}

export interface TreeLine {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  color: string;
}

export interface TreeDot {
  x: number;
  y: number;
}

class LayoutUnit {
  members: ApiPerson[] = [];
  generation: number = 0;
  x: number = 0;
  left: number = 0;
  width: number = 0;
  parents: Set<LayoutUnit> = new Set<LayoutUnit>();
  children: Set<LayoutUnit> = new Set<LayoutUnit>();
}

class ConnectionGroup {
  father: PersonBox | null = null;
  mother: PersonBox | null = null;
  children: PersonBox[] = [];
}

export class TreeLayoutResult {
  boxes: PersonBox[] = [];
  lines: TreeLine[] = [];
  dots: TreeDot[] = [];
  width: number = 0;
  height: number = 0;
  boxById: Map<string, PersonBox> = new Map<string, PersonBox>();
}

export class TreeLayoutBuilder {
  static build(tree: ApiTree): TreeLayoutResult {
    const result = new TreeLayoutResult();
    const personsById = new Map<string, ApiPerson>();
    tree.persons.forEach((person: ApiPerson) => {
      personsById.set(person.id, person);
    });

    const spouses = new Map<string, string[]>();
    tree.spouses.forEach((edge) => {
      if (edge.status === 'divorced') return;
      const a = personsById.get(edge.personAId);
      const b = personsById.get(edge.personBId);
      if (a === undefined || b === undefined || a.generationNo !== b.generationNo) return;
      TreeLayoutBuilder.addSpouse(spouses, a.id, b.id);
      TreeLayoutBuilder.addSpouse(spouses, b.id, a.id);
    });
    spouses.forEach((ids: string[]) => {
      ids.sort((a: string, b: string) => {
        const pa = personsById.get(a);
        const pb = personsById.get(b);
        if (pa === undefined || pb === undefined) return a.localeCompare(b);
        return TreeLayoutBuilder.comparePeople(pa, pb);
      });
    });

    const generations: number[] = [];
    tree.persons.forEach((person: ApiPerson) => {
      if (generations.indexOf(person.generationNo) < 0) {
        generations.push(person.generationNo);
      }
    });
    generations.sort((a: number, b: number) => a - b);

    const compactByGeneration = new Map<number, boolean>();
    generations.forEach((generation: number) => {
      const count = tree.persons.filter(
        (person: ApiPerson) => person.generationNo === generation
      ).length;
      compactByGeneration.set(generation, count > 3 || tree.persons.length > 22);
    });

    const unitsByGeneration = new Map<number, LayoutUnit[]>();
    const unitByPerson = new Map<string, LayoutUnit>();
    generations.forEach((generation: number) => {
      const units: LayoutUnit[] = [];
      const used = new Set<string>();
      const people: ApiPerson[] = tree.persons
        .filter((person: ApiPerson) => person.generationNo === generation)
        .sort((a: ApiPerson, b: ApiPerson) => TreeLayoutBuilder.comparePeople(a, b));

      people.forEach((person: ApiPerson) => {
        if (person.gender !== 'male' || used.has(person.id)) return;
        const wifeIds = spouses.get(person.id);
        if (wifeIds === undefined) return;
        const wives: ApiPerson[] = [];
        wifeIds.forEach((wifeId: string) => {
          const wife = personsById.get(wifeId);
          if (wife !== undefined && wife.generationNo === generation && !used.has(wife.id)) {
            wives.push(wife);
          }
        });
        if (wives.length === 0) return;
        const unit = new LayoutUnit();
        unit.generation = generation;
        unit.members.push(person);
        wives.forEach((wife: ApiPerson) => unit.members.push(wife));
        unit.members.forEach((member: ApiPerson) => used.add(member.id));
        units.push(unit);
      });

      people.forEach((person: ApiPerson) => {
        if (used.has(person.id)) return;
        used.add(person.id);
        const unit = new LayoutUnit();
        unit.generation = generation;
        unit.members.push(person);
        const spouseIds = spouses.get(person.id);
        if (spouseIds !== undefined) {
          for (const spouseId of spouseIds) {
            const spouse = personsById.get(spouseId);
            if (spouse !== undefined && spouse.generationNo === generation && !used.has(spouse.id)) {
              used.add(spouse.id);
              unit.members.push(spouse);
              break;
            }
          }
        }
        units.push(unit);
      });

      units.sort((a: LayoutUnit, b: LayoutUnit) =>
        TreeLayoutBuilder.comparePeople(a.members[0], b.members[0])
      );
      units.forEach((unit: LayoutUnit) => {
        const cardWidth = TreeLayoutBuilder.cardWidth(unit.generation, compactByGeneration);
        unit.width = unit.members.length * cardWidth +
          (unit.members.length - 1) * MEMBER_GAP;
        unit.members.forEach((member: ApiPerson) => unitByPerson.set(member.id, unit));
      });
      unitsByGeneration.set(generation, units);
    });

    tree.parentChild.forEach((edge) => {
      if (edge.status !== 'active') return;
      const parentUnit = unitByPerson.get(edge.parentId);
      const childUnit = unitByPerson.get(edge.childId);
      if (parentUnit === undefined || childUnit === undefined) return;
      if (parentUnit.generation >= childUnit.generation) return;
      parentUnit.children.add(childUnit);
      childUnit.parents.add(parentUnit);
    });

    unitsByGeneration.forEach((units: LayoutUnit[]) => {
      units.forEach((unit: LayoutUnit) => {
        if (unit.parents.size < 2) return;
        const parents = Array.from(unit.parents).sort((a: LayoutUnit, b: LayoutUnit) =>
          TreeLayoutBuilder.comparePeople(a.members[0], b.members[0])
        );
        const keep = parents[0];
        parents.forEach((parent: LayoutUnit) => {
          if (parent !== keep) parent.children.delete(unit);
        });
        unit.parents.clear();
        unit.parents.add(keep);
      });
    });

    const topByGeneration = new Map<number, number>();
    let top = TOP;
    generations.forEach((generation: number) => {
      topByGeneration.set(generation, top);
      const height = TreeLayoutBuilder.cardHeight(generation, compactByGeneration);
      top += height + GEN_GAP;
    });

    const roots: LayoutUnit[] = [];
    unitsByGeneration.forEach((units: LayoutUnit[]) => {
      units.forEach((unit: LayoutUnit) => {
        if (unit.parents.size === 0) roots.push(unit);
      });
    });
    roots.sort((a: LayoutUnit, b: LayoutUnit) => {
      if (a.generation !== b.generation) return a.generation - b.generation;
      return TreeLayoutBuilder.comparePeople(a.members[0], b.members[0]);
    });

    const widthCache = new Map<LayoutUnit, number>();
    let left = LEFT;
    roots.forEach((root: LayoutUnit, index: number) => {
      const width = TreeLayoutBuilder.subtreeWidth(root, widthCache);
      TreeLayoutBuilder.placeUnit(root, left, widthCache);
      left += width;
      if (index !== roots.length - 1) left += FAMILY_GAP;
    });

    result.width = Math.max(360, left + RIGHT);
    result.height = Math.max(220, top - GEN_GAP + BOTTOM);

    unitsByGeneration.forEach((units: LayoutUnit[]) => {
      const generation = units.length > 0 ? units[0].generation : 0;
      const cardWidth = TreeLayoutBuilder.cardWidth(generation, compactByGeneration);
      const cardHeight = TreeLayoutBuilder.cardHeight(generation, compactByGeneration);
      const compact = compactByGeneration.get(generation) === true;
      const y = topByGeneration.get(generation);
      if (y === undefined) return;
      units.forEach((unit: LayoutUnit) => {
        let x = unit.left;
        unit.members.forEach((member: ApiPerson) => {
          const box: PersonBox = {
            person: member,
            x: x,
            y: y,
            width: cardWidth,
            height: cardHeight,
            compact: compact
          };
          result.boxes.push(box);
          result.boxById.set(member.id, box);
          x += cardWidth + MEMBER_GAP;
        });
      });
    });

    TreeLayoutBuilder.buildConnections(tree, result);
    return result;
  }

  private static cardWidth(generation: number, compact: Map<number, boolean>): number {
    return compact.get(generation) === true ? COMPACT_W : WIDE_W;
  }

  private static cardHeight(generation: number, compact: Map<number, boolean>): number {
    return compact.get(generation) === true ? COMPACT_H : WIDE_H;
  }

  private static subtreeWidth(unit: LayoutUnit, cache: Map<LayoutUnit, number>): number {
    const cached = cache.get(unit);
    if (cached !== undefined) return cached;
    const children = TreeLayoutBuilder.sortedChildren(unit);
    let childrenWidth = 0;
    children.forEach((child: LayoutUnit, index: number) => {
      childrenWidth += TreeLayoutBuilder.subtreeWidth(child, cache);
      if (index !== children.length - 1) childrenWidth += CHILD_GAP;
    });
    const width = Math.max(unit.width, childrenWidth);
    cache.set(unit, width);
    return width;
  }

  private static placeUnit(
    unit: LayoutUnit,
    left: number,
    cache: Map<LayoutUnit, number>
  ): void {
    const width = TreeLayoutBuilder.subtreeWidth(unit, cache);
    unit.left = left + (width - unit.width) / 2;
    const children = TreeLayoutBuilder.sortedChildren(unit);
    if (children.length === 0) return;
    let childrenWidth = 0;
    children.forEach((child: LayoutUnit, index: number) => {
      childrenWidth += TreeLayoutBuilder.subtreeWidth(child, cache);
      if (index !== children.length - 1) childrenWidth += CHILD_GAP;
    });
    let childLeft = left + (width - childrenWidth) / 2;
    children.forEach((child: LayoutUnit) => {
      TreeLayoutBuilder.placeUnit(child, childLeft, cache);
      childLeft += TreeLayoutBuilder.subtreeWidth(child, cache) + CHILD_GAP;
    });
  }

  private static sortedChildren(unit: LayoutUnit): LayoutUnit[] {
    return Array.from(unit.children).sort((a: LayoutUnit, b: LayoutUnit) =>
      TreeLayoutBuilder.comparePeople(a.members[0], b.members[0])
    );
  }

  private static addSpouse(map: Map<string, string[]>, personId: string, spouseId: string): void {
    let list = map.get(personId);
    if (list === undefined) {
      list = [];
      map.set(personId, list);
    }
    if (list.indexOf(spouseId) < 0) {
      list.push(spouseId);
    }
  }

  private static comparePeople(a: ApiPerson, b: ApiPerson): number {
    const birthA = a.birthOrder === undefined ? 999 : a.birthOrder;
    const birthB = b.birthOrder === undefined ? 999 : b.birthOrder;
    if (birthA !== birthB) return birthA - birthB;
    const branchA = a.branchId === undefined ? '' : a.branchId;
    const branchB = b.branchId === undefined ? '' : b.branchId;
    const branchCompare = branchA.localeCompare(branchB);
    if (branchCompare !== 0) return branchCompare;
    return a.fullName.localeCompare(b.fullName);
  }

  private static buildConnections(tree: ApiTree, result: TreeLayoutResult): void {
    const fatherByChild = new Map<string, string>();
    const motherByChild = new Map<string, string>();
    tree.parentChild.forEach((edge) => {
      if (edge.status !== 'active') return;
      if (!result.boxById.has(edge.parentId) || !result.boxById.has(edge.childId)) return;
      if (edge.parentRole === 'father') {
        fatherByChild.set(edge.childId, edge.parentId);
      } else if (edge.parentRole === 'mother') {
        motherByChild.set(edge.childId, edge.parentId);
      }
    });

    const groups = new Map<string, ConnectionGroup>();
    result.boxes.forEach((child: PersonBox) => {
      const fatherId = fatherByChild.get(child.person.id);
      const motherId = motherByChild.get(child.person.id);
      const father = fatherId === undefined ? undefined : result.boxById.get(fatherId);
      const mother = motherId === undefined ? undefined : result.boxById.get(motherId);
      if (father === undefined && mother === undefined) return;
      const anchorId = father !== undefined ? father.person.id : mother!.person.id;
      const key = anchorId + '|' + (mother === undefined ? 'single' : mother.person.id);
      let group = groups.get(key);
      if (group === undefined) {
        group = new ConnectionGroup();
        group.father = father === undefined ? null : father;
        group.mother = mother === undefined ? null : mother;
        groups.set(key, group);
      }
      group.children.push(child);
    });

    const colorSlots: string[] = ['#3F6E9E', '#3A8D70', '#C08A32', '#B45D5A', '#7B67A8'];
    const groupList: ConnectionGroup[] = [];
    groups.forEach((group: ConnectionGroup) => groupList.push(group));
    groupList.forEach((group: ConnectionGroup, groupIndex: number) => {
      if (group.children.length === 0) return;
      const father = group.father;
      const mother = group.mother;
      const firstParent = father !== null ? father : mother;
      if (firstParent === null) return;
      const color = colorSlots[groupIndex % colorSlots.length];
      let parentBottom = firstParent.y + firstParent.height;
      if (father !== null) parentBottom = Math.max(parentBottom, father.y + father.height);
      if (mother !== null) parentBottom = Math.max(parentBottom, mother.y + mother.height);
      const children = group.children.sort((a: PersonBox, b: PersonBox) => a.x - b.x);
      const childTop = children[0].y;
      const stagger = (groupIndex % 4) * 10;
      const barY = Math.min(childTop - 18, parentBottom + 36 + stagger);

      let barLeft = 999999;
      let barRight = 0;
      const addBarX = (x: number): void => {
        barLeft = Math.min(barLeft, x);
        barRight = Math.max(barRight, x);
      };

      if (father !== null) {
        const fx = father.x + father.width / 2;
        result.lines.push({ x1: fx, y1: father.y + father.height, x2: fx, y2: barY, color: color });
        result.dots.push({ x: fx, y: father.y + father.height });
        addBarX(fx);
      }
      if (mother !== null) {
        const mx = mother.x + mother.width / 2;
        result.lines.push({ x1: mx, y1: mother.y + mother.height, x2: mx, y2: barY, color: color });
        result.dots.push({ x: mx, y: mother.y + mother.height });
        addBarX(mx);
      }
      children.forEach((child: PersonBox) => addBarX(child.x + child.width / 2));
      result.lines.push({ x1: barLeft, y1: barY, x2: barRight, y2: barY, color: color });
      children.forEach((child: PersonBox) => {
        const cx = child.x + child.width / 2;
        result.lines.push({ x1: cx, y1: barY, x2: cx, y2: child.y, color: color });
        result.dots.push({ x: cx, y: barY });
      });
    });
  }
}
