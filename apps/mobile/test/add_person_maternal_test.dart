import 'package:family_tree/features/person/add_person_page.dart';
import 'package:family_tree/services/api_models.dart';
import 'package:family_tree/services/app_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AddPersonSession extends AppSession {
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
}

void main() {
  testWidgets('adding a non-family surname allows parents and a wife', (
    tester,
  ) async {
    final session = _AddPersonSession();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: const MaterialApp(home: AddPersonPage()),
      ),
    );
    await tester.pumpAndSettle();

    final surnameField = find.byType(TextFormField).first;
    await tester.enterText(surnameField, '陈');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('选择女方'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('父亲'), findsOneWidget);
    expect(find.text('母亲'), findsOneWidget);
    expect(find.text('配偶'), findsOneWidget);
    expect(find.text('选择女方'), findsOneWidget);
  });
}
