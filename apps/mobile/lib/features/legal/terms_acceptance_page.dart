import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/app_session.dart';
import 'legal_page.dart';

class TermsAcceptancePage extends StatefulWidget {
  const TermsAcceptancePage({super.key});

  @override
  State<TermsAcceptancePage> createState() => _TermsAcceptancePageState();
}

class _TermsAcceptancePageState extends State<TermsAcceptancePage> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).acceptTerms(LegalPage.termsVersion);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _decline() async {
    final session = SessionScope.of(context);
    await session.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                '使用前确认',
                style: AppTheme.serif(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '我们更新了用户协议和隐私政策。继续使用前，请确认你已阅读并同意以下内容。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.8,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 22),
              _LegalRow(
                title: '用户协议',
                subtitle: '服务内容、账号安全、家族内容规范',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalPage(kind: LegalKind.terms),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _LegalRow(
                title: '隐私政策',
                subtitle: '收集范围、存储保护、你的权利',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalPage(kind: LegalKind.privacy),
                  ),
                ),
              ),
              const Spacer(),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.cinnabar,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                onPressed: _busy ? null : _accept,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('同意并继续'),
              ),
              TextButton(
                onPressed: _busy ? null : _decline,
                child: const Text('不同意，退出登录', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalRow extends StatelessWidget {
  const _LegalRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
