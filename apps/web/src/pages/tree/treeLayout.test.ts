import { describe, expect, it } from 'vitest';
import type { FamilyTree, ParentChildEdge, PersonSummary, SpouseEdge } from '@/types/api';
import {
  buildTreeLayout,
  findPersonAnchor,
  findUnitForPerson,
  toChineseNumber,
} from './treeLayout';

function person(
  id: string,
  fullName: string,
  gender: PersonSummary['gender'],
  generationNo: number,
  surname = '张',
): PersonSummary {
  const givenName = fullName.replace(surname, '');
  return {
    id,
    fullName,
    surname,
    givenName,
    gender,
    generationNo,
    generationLabel: `第${generationNo}世`,
    lifeStatus: 'living',
    status: 'active',
    version: 1,
    hasAvatar: false,
  };
}

function parentEdge(
  id: string,
  parentId: string,
  childId: string,
  parentRole: ParentChildEdge['parentRole'],
): ParentChildEdge {
  return { id, parentId, childId, parentRole, status: 'active' };
}

function spouseEdge(id: string, a: string, b: string): SpouseEdge {
  return { id, personAId: a, personBId: b, status: 'married' };
}

function sampleTree(): FamilyTree {
  const father = person('p1', '张父', 'male', 1);
  const mother = person('p2', '林母', 'female', 1, '林');
  const son = person('p3', '张子', 'male', 2);
  const daughterInLaw = person('p4', '李妻', 'female', 2, '李');
  const sister = person('p5', '张女', 'female', 2);
  return {
    familyId: 'f1',
    version: 1,
    persons: [father, mother, son, daughterInLaw, sister],
    parentChild: [
      parentEdge('e1', father.id, son.id, 'father'),
      parentEdge('e2', mother.id, son.id, 'mother'),
      parentEdge('e3', father.id, sister.id, 'father'),
      parentEdge('e4', mother.id, sister.id, 'mother'),
    ],
    spouses: [spouseEdge('s1', father.id, mother.id), spouseEdge('s2', son.id, daughterInLaw.id)],
  };
}

describe('buildTreeLayout', () => {
  it('把夫妻放进同一个家庭单元，并让每个人只出现一次', () => {
    const layout = buildTreeLayout(sampleTree());
    const allMemberIds = layout.units.flatMap((unit) => unit.members.map((member) => member.id));

    expect(layout.units).toHaveLength(3);
    expect(allMemberIds.sort()).toEqual(['p1', 'p2', 'p3', 'p4', 'p5']);
    expect(new Set(allMemberIds).size).toBe(allMemberIds.length);

    const parentsUnit = findUnitForPerson(layout, 'p1');
    const childrenUnit = findUnitForPerson(layout, 'p3');
    expect(parentsUnit?.members.map((member) => member.id).sort()).toEqual(['p1', 'p2']);
    expect(childrenUnit?.members.map((member) => member.id).sort()).toEqual(['p3', 'p4']);
    expect(parentsUnit?.width).toBe(274);
    expect(childrenUnit?.width).toBe(274);
    expect(layout.connections).toHaveLength(4);
    expect(layout.connections.every((connection) => connection.sourceHandle.startsWith('person:'))).toBe(
      true,
    );
    expect(layout.connections.every((connection) => connection.targetHandle.startsWith('target:'))).toBe(
      true,
    );
  });

  it('每段婚姻的子女分别从父亲和母亲卡片出发', () => {
    const father = person('f1', '张父', 'male', 1);
    const wife1 = person('w1', '林妻', 'female', 1, '林');
    const wife2 = person('w2', '李妻', 'female', 1, '李');
    const child1 = person('c1', '张长子', 'male', 2);
    const child2 = person('c2', '张次子', 'male', 2);
    const tree: FamilyTree = {
      familyId: 'f1',
      version: 1,
      persons: [father, wife1, wife2, child1, child2],
      parentChild: [
        parentEdge('pc1', father.id, child1.id, 'father'),
        parentEdge('pc2', wife1.id, child1.id, 'mother'),
        parentEdge('pc3', father.id, child2.id, 'father'),
        parentEdge('pc4', wife2.id, child2.id, 'mother'),
      ],
      spouses: [spouseEdge('s1', father.id, wife1.id), spouseEdge('s2', father.id, wife2.id)],
    };
    const layout = buildTreeLayout(tree);
    expect(layout.units.filter((unit) => unit.generation === 1)).toHaveLength(1);
    expect(layout.units.find((unit) => unit.members.some((member) => member.id === father.id))?.members).toHaveLength(3);
    expect(layout.connections.map((connection) => connection.sourceHandle).sort()).toEqual([
      'person:f1',
      'person:f1',
      'person:w1',
      'person:w2',
    ]);
    expect(
      layout.connections.filter((connection) => connection.childId === child1.id).map((connection) => connection.parentId).sort(),
    ).toEqual([father.id, wife1.id].sort());
  });

  it('点击人物时使用人物卡中心而不是家庭单元中心', () => {
    const layout = buildTreeLayout(sampleTree());
    const unit = findUnitForPerson(layout, 'p1')!;
    const first = findPersonAnchor(layout, 'p1')!;
    const second = findPersonAnchor(layout, 'p2')!;
    expect(first.x).toBe(unit.x + 66);
    expect(second.x).toBe(unit.x + 132 + 10 + 66);
    expect(first.y).toBe(unit.y + unit.height / 2);
  });

  it('子代更多的家庭单元排在同一世代左边', () => {
    const tree = sampleTree();
    const lonely = person('p6', '张孤', 'male', 1);
    tree.persons.push(lonely);
    const layout = buildTreeLayout(tree);
    const parentUnit = findUnitForPerson(layout, 'p1')!;
    const lonelyUnit = findUnitForPerson(layout, 'p6')!;
    expect(parentUnit.x).toBeLessThan(lonelyUnit.x);
  });

  it('同一对父母的多条父母子女边只生成一条家庭单元连线', () => {
    const layout = buildTreeLayout(sampleTree());
    const parents = findUnitForPerson(layout, 'p1');
    const son = findUnitForPerson(layout, 'p3');
    const sister = findUnitForPerson(layout, 'p5');
    const edges = layout.edges.filter((edge) => edge.source === parents?.id);

    expect(edges).toHaveLength(2);
    expect(edges.map((edge) => edge.target).sort()).toEqual(
      [son?.id, sister?.id].filter(Boolean).sort(),
    );
    expect(edges.every((edge) => edge.parentIds.length === 2)).toBe(true);
  });

  it('按真实世代生成行，并保证父代在子代上方', () => {
    const layout = buildTreeLayout(sampleTree());
    const parentsUnit = findUnitForPerson(layout, 'p1')!;
    const childrenUnit = findUnitForPerson(layout, 'p3')!;

    expect(layout.generations.map((row) => row.generation)).toEqual([1, 2]);
    expect(parentsUnit.y).toBeLessThan(childrenUnit.y);
    expect(layout.generations[0].count).toBe(2);
    expect(layout.generations[1].count).toBe(3);
  });

  it('离婚的配偶不并排成为同一单元', () => {
    const tree = sampleTree();
    tree.spouses = [{ id: 's1', personAId: 'p1', personBId: 'p2', status: 'divorced' }];
    const layout = buildTreeLayout(tree);
    const unitA = findUnitForPerson(layout, 'p1');
    const unitB = findUnitForPerson(layout, 'p2');
    expect(unitA?.id).not.toBe(unitB?.id);
  });

  it('不把没有父母子女关系的孤立人物漏掉', () => {
    const tree = sampleTree();
    tree.persons.push(person('p6', '张孤', 'male', 2));
    const layout = buildTreeLayout(tree);
    expect(findUnitForPerson(layout, 'p6')).toBeDefined();
  });
});

describe('toChineseNumber', () => {
  it('转换常见世代数字', () => {
    expect(toChineseNumber(1)).toBe('一');
    expect(toChineseNumber(10)).toBe('十');
    expect(toChineseNumber(12)).toBe('十二');
    expect(toChineseNumber(24)).toBe('二十四');
  });
});
