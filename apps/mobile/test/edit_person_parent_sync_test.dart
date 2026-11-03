import 'package:family_tree/features/person/edit_person_page.dart';
import 'package:family_tree/services/api_models.dart';
import 'package:family_tree/services/app_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSession extends AppSession {
  int deletedParents = 0;
  String? deletedEdgeId;
  int deletedSpouses = 0;
  String? deletedSpouseEdgeId;
  bool updatedPerson = false;

  static const _family = ApiFamily(
    id: 'family-1',
    name: '凌氏家族',
    surname: '凌',
    motto: '',
    region: '',
    description: '',
    status: 'active',
    memberCount: 2,
    branchCount: 1,
    version: 1,
  );

  @override
  ApiFamily? get family => _family;

  @override
  bool get canWrite => true;

  @override
  Future<List<ApiBranch>> branches() async => const [
    ApiBranch(id: 'branch-1', name: '长房'),
  ];

  @override
  Future<ApiPerson> updatePerson({
    required String personId,
    required String surname,
    required String givenName,
    required String courtesyName,
    required String alias,
    required String gender,
    required int generationNo,
    String generationName = '',
    required String branchId,
    int? birthOrder,
    ApiPartialDate? birth,
    ApiPartialDate? death,
    required String lifeStatus,
    required String birthPlace,
    required String residence,
    required String occupation,
    required String education,
    required String biography,
    required int version,
  }) async {
    updatedPerson = true;
    return _person;
  }

  @override
  Future<void> deleteParentChild(String edgeId) async {
    deletedParents++;
    deletedEdgeId = edgeId;
  }

  @override
  Future<void> deleteSpouse(String edgeId) async {
    deletedSpouses++;
    deletedSpouseEdgeId = edgeId;
  }
}

final _person = ApiPerson.fromJson({
  'id': 'child-1',
  'fullName': '凌测试',
  'surname': '凌',
  'givenName': '测试',
  'gender': 'male',
  'generationNo': 2,
  'generationLabel': '第二代',
  'branchId': 'branch-1',
  'lifeStatus': 'living',
  'status': 'active',
  'version': 3,
  'parents': [
    {
      'personId': 'father-1',
      'fullName': '凌父亲',
      'relation': '父亲',
      'edgeId': 'edge-father-1',
    },
  ],
});

final _maternalPerson = ApiPerson.fromJson({
  'id': 'maternal-1',
  'fullName': '陈母方',
  'surname': '陈',
  'givenName': '母方',
  'gender': 'female',
  'generationNo': 2,
  'generationLabel': '第二代',
  'branchId': 'branch-1',
  'lifeStatus': 'living',
  'status': 'active',
  'version': 1,
  'spouses': [
    {
      'personId': 'husband-1',
      'fullName': '凌丈夫',
      'relation': '配偶',
      'edgeId': 'edge-spouse-1',
    },
  ],
});

void main() {
  testWidgets('owner editing parents writes the relationship change', (
    tester,
  ) async {
    final session = _FakeSession();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: MaterialApp(home: EditPersonPage(person: _person)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('凌父亲'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('凌父亲'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('保存修改'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存修改'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(session.updatedPerson, isTrue);
    expect(session.deletedParents, 1);
    expect(session.deletedEdgeId, 'edge-father-1');
    expect(find.text('资料已保存'), findsOneWidget);
  });

  testWidgets('non-family surname edits can keep spouse and add parents', (
    tester,
  ) async {
    final session = _FakeSession();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: MaterialApp(home: EditPersonPage(person: _maternalPerson)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('凌丈夫'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('配偶'), findsOneWidget);
    expect(find.text('父亲'), findsOneWidget);
    expect(find.text('母亲'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('保存修改'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存修改'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(session.deletedSpouses, 1);
    expect(session.deletedSpouseEdgeId, 'edge-spouse-1');
  });
}
