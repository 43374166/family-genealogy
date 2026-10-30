import 'package:family_tree/app.dart';
import 'package:family_tree/data/demo_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home and tree prototype smoke test', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FamilyTreeApp());
    await tester.pumpAndSettle();

    expect(find.text(DemoData.family.name), findsWidgets);
    expect(find.text('最新动态'), findsOneWidget);
    expect(find.text('族谱树'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.account_tree_outlined).last);
    await tester.pumpAndSettle();

    expect(find.text('张一'), findsWidgets);
    expect(find.text('查看详情'), findsNothing);

    await tester.tap(find.text('张一').first);
    await tester.pumpAndSettle();
    expect(find.text('查看详情'), findsOneWidget);

    await tester.tap(find.text('张宏远').first);
    await tester.pumpAndSettle();
    expect(find.text('查看详情'), findsOneWidget);

    await tester.tapAt(const Offset(20, 310));
    await tester.pumpAndSettle();
    expect(find.text('查看详情'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
