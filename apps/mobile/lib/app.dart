import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/shell/app_shell.dart';
import 'services/app_session.dart';

class FamilyTreeApp extends StatefulWidget {
  const FamilyTreeApp({super.key, this.session});

  /// Test seam; production uses a session backed by secure storage.
  final AppSession? session;

  @override
  State<FamilyTreeApp> createState() => _FamilyTreeAppState();
}

class _FamilyTreeAppState extends State<FamilyTreeApp> {
  late final AppSession _session = widget.session ?? AppSession();
  late final bool _ownsSession = widget.session == null;

  @override
  void initState() {
    super.initState();
    if (_ownsSession) {
      _session.restore();
    }
  }

  @override
  void dispose() {
    if (_ownsSession) {
      _session.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: _session,
      child: MaterialApp(
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
        home: const _RootGate(),
      ),
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
      child: session.restoring
          ? const _BootSplash(key: ValueKey('boot'))
          : session.isAuthenticated
          ? const AppShell(key: ValueKey('app'))
          : const LoginPage(key: ValueKey('login')),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2E9),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFA63A38),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Text(
                '族',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('家族族谱', style: AppTheme.serif(fontSize: 26, letterSpacing: 3)),
            const SizedBox(height: 6),
            const Text(
              '正在恢复登录…',
              style: TextStyle(fontSize: 11, color: Color(0xFF7A817F)),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
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
