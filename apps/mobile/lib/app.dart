import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/shell/app_shell.dart';
import 'services/app_session.dart';

class FamilyTreeApp extends StatefulWidget {
  const FamilyTreeApp({super.key});

  @override
  State<FamilyTreeApp> createState() => _FamilyTreeAppState();
}

class _FamilyTreeAppState extends State<FamilyTreeApp> {
  late final AppSession _session = AppSession();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '家族族谱',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const _AppScrollBehavior(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SessionScope(session: _session, child: const _RootGate()),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: session.isAuthenticated
          ? const AppShell(key: ValueKey('app'))
          : const LoginPage(key: ValueKey('login')),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
