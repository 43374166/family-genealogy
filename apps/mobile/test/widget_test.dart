import 'package:family_tree/app.dart';
import 'package:family_tree/services/app_session.dart';
import 'package:family_tree/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptySessionStore extends SessionStore {
  @override
  Future<StoredSession?> read() async => null;

  @override
  Future<void> save(StoredSession session) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the family login gate', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = AppSession(store: _EmptySessionStore());
    addTearDown(session.dispose);
    await tester.pumpWidget(FamilyTreeApp(session: session));
    await tester.pumpAndSettle();

    expect(find.text('家族族谱'), findsOneWidget);
    expect(find.text('进入家族'), findsWidgets);
    expect(find.text('登录名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('服务器地址（本地开发）'), findsOneWidget);
    expect(find.text('演示账号：linglei / Demo#2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
