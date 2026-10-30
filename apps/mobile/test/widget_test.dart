import 'package:family_tree/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the family login gate', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FamilyTreeApp());
    await tester.pumpAndSettle();

    expect(find.text('家族族谱'), findsOneWidget);
    expect(find.text('进入家族'), findsWidgets);
    expect(find.text('登录名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('服务器地址（本地开发）'), findsOneWidget);
    expect(find.text('演示账号：zhangsan / Demo#2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
