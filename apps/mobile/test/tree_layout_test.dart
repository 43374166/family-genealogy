import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/features/tree/tree_layout.dart';
import 'package:family_tree/services/api_models.dart';

ApiPerson _person(String id, String name, int generation, {String? gender}) {
  return ApiPerson.fromJson({
    'id': id,
    'fullName': name,
    'surname': name.substring(0, 1),
    'givenName': name.substring(1),
    'gender':
        gender ?? (id == 'b' || id == 'd' || id == 'f' ? 'female' : 'male'),
    'generationNo': generation,
    'generationLabel': '第$generation世',
    'lifeStatus': 'living',
    'status': 'active',
    'version': 1,
  });
}

void main() {
  test('dynamic layout places arbitrary people without demo coordinates', () {
    final tree = ApiTree(
      familyId: 'family-chen',
      version: 1,
      persons: [
        _person('a', '陈甲', 1),
        _person('b', '林乙', 1),
        _person('c', '陈丙', 2),
        _person('d', '苏丁', 2),
        _person('e', '陈戊', 3),
        _person('f', '余己', 3),
      ],
      parentChild: const [
        ApiParentChildEdge(
          id: 'pc1',
          parentId: 'a',
          childId: 'c',
          parentRole: 'father',
          status: 'active',
        ),
        ApiParentChildEdge(
          id: 'pc2',
          parentId: 'b',
          childId: 'c',
          parentRole: 'mother',
          status: 'active',
        ),
        ApiParentChildEdge(
          id: 'pc3',
          parentId: 'c',
          childId: 'e',
          parentRole: 'father',
          status: 'active',
        ),
        ApiParentChildEdge(
          id: 'pc4',
          parentId: 'd',
          childId: 'e',
          parentRole: 'mother',
          status: 'active',
        ),
      ],
      spouses: const [
        ApiSpouseEdge(
          id: 's1',
          personAId: 'a',
          personBId: 'b',
          status: 'active',
        ),
        ApiSpouseEdge(
          id: 's2',
          personAId: 'c',
          personBId: 'd',
          status: 'active',
        ),
        ApiSpouseEdge(
          id: 's3',
          personAId: 'e',
          personBId: 'f',
          status: 'active',
        ),
      ],
    );

    final layout = TreeLayout.fromTree(tree);
    expect(layout, isNotNull);
    expect(layout!.personCount, 6);
    expect(layout.generations, [1, 2, 3]);
    expect(layout.width, greaterThan(300));
    expect(layout.height, greaterThan(200));
    expect(layout.edges, isNotEmpty);
    expect(layout.placementFor('e')!.person.fullName, '陈戊');

    // One couple gets one child branch. Both parent cards share this single
    // branch; no separate mother line is drawn.
    final father = layout.placementFor('a')!;
    final mother = layout.placementFor('b')!;
    final child = layout.placementFor('c')!;
    final childEdges = layout.edges
        .where(
          (edge) =>
              (edge.points.last.dx - child.center.dx).abs() < 0.1 &&
              (edge.points.last.dy - child.rect.top).abs() < 0.1,
        )
        .toList();
    expect(childEdges.length, 1);
    final childEdge = childEdges.single;
    expect((childEdge.points.first.dx - father.center.dx).abs(), lessThan(0.1));
    expect(
      (childEdge.points.first.dy - father.rect.bottom).abs(),
      lessThan(0.1),
    );
    final bridgeMidX = (father.rect.right + mother.rect.left) / 2;
    expect(
      layout.unionNodes.any(
        (point) =>
            (point.dx - bridgeMidX).abs() < 0.1 &&
            (point.dy - father.center.dy).abs() < 0.1,
      ),
      isFalse,
      reason: 'no vertical line should hang from the marriage bridge centre',
    );

    for (final generation in layout.generations) {
      final row =
          layout.placements
              .where((placement) => placement.generation == generation)
              .toList()
            ..sort((a, b) => a.rect.left.compareTo(b.rect.left));
      for (var i = 1; i < row.length; i++) {
        expect(
          row[i].rect.left,
          greaterThanOrEqualTo(row[i - 1].rect.right),
          reason: 'nodes must not overlap in generation $generation',
        );
      }
    }
  });

  test(
    'multiple wives sit beside the husband and have separate child branches',
    () {
      final tree = ApiTree(
        familyId: 'family-multiple-wives',
        version: 1,
        persons: [
          _person('h', '凌丈夫', 1),
          _person('w1', '王元配', 1, gender: 'female'),
          _person('w2', '李继室', 1, gender: 'female'),
          _person('c1', '凌长子', 2),
          _person('c2', '凌次子', 2),
        ],
        parentChild: const [
          ApiParentChildEdge(
            id: 'pc1',
            parentId: 'h',
            childId: 'c1',
            parentRole: 'father',
            status: 'active',
          ),
          ApiParentChildEdge(
            id: 'pc2',
            parentId: 'w1',
            childId: 'c1',
            parentRole: 'mother',
            status: 'active',
          ),
          ApiParentChildEdge(
            id: 'pc3',
            parentId: 'h',
            childId: 'c2',
            parentRole: 'father',
            status: 'active',
          ),
          ApiParentChildEdge(
            id: 'pc4',
            parentId: 'w2',
            childId: 'c2',
            parentRole: 'mother',
            status: 'active',
          ),
        ],
        spouses: const [
          ApiSpouseEdge(
            id: 's1',
            personAId: 'h',
            personBId: 'w1',
            status: 'married',
          ),
          ApiSpouseEdge(
            id: 's2',
            personAId: 'h',
            personBId: 'w2',
            status: 'married',
          ),
        ],
      );

      final layout = TreeLayout.fromTree(tree)!;
      final husband = layout.placementFor('h')!;
      final wives = [layout.placementFor('w1')!, layout.placementFor('w2')!]
        ..sort((a, b) => a.rect.left.compareTo(b.rect.left));
      expect(wives.first.rect.left, greaterThan(husband.rect.right));
      expect(wives.last.rect.left, greaterThan(wives.first.rect.right));

      List<TreeEdge> edgesFor(String childId) {
        final child = layout.placementFor(childId)!;
        return layout.edges
            .where(
              (edge) =>
                  (edge.points.last.dx - child.center.dx).abs() < 0.1 &&
                  (edge.points.last.dy - child.rect.top).abs() < 0.1,
            )
            .toList();
      }

      final firstEdges = edgesFor('c1');
      final secondEdges = edgesFor('c2');
      expect(firstEdges.length, 1);
      expect(secondEdges.length, 1);

      final firstFather = firstEdges.single;
      final secondFather = secondEdges.single;
      expect(
        (firstFather.points.first.dx - secondFather.points.first.dx).abs(),
        greaterThan(10),
        reason: 'different wives need separate couple anchors',
      );
      expect(
        (firstFather.points[1].dy - secondFather.points[1].dy).abs(),
        greaterThan(0),
        reason: 'different wives need staggered branch levels',
      );
    },
  );

  test('empty tree produces no layout', () {
    final tree = ApiTree(
      familyId: 'empty',
      version: 1,
      persons: const [],
      parentChild: const [],
      spouses: const [],
    );
    expect(TreeLayout.fromTree(tree), isNull);
  });
}
