import 'package:flutter_test/flutter_test.dart';

import 'package:family_tree/features/tree/tree_layout.dart';
import 'package:family_tree/services/api_models.dart';

ApiPerson _person(String id, String name, int generation) {
  return ApiPerson.fromJson({
    'id': id,
    'fullName': name,
    'surname': name.substring(0, 1),
    'givenName': name.substring(1),
    'gender': id == 'b' || id == 'd' || id == 'f' ? 'female' : 'male',
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
    expect(layout.marriageBridges.length, 3);
    expect(layout.placementFor('e')!.person.fullName, '陈戊');

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
