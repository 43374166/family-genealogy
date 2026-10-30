import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/app_session.dart';
import 'phone_login_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginName = TextEditingController(text: 'linglei');
  final _password = TextEditingController();
  final _serverUrl = TextEditingController(text: ApiConfig.defaultBaseUrl);
  bool _obscure = true;

  @override
  void dispose() {
    _loginName.dispose();
    _password.dispose();
    _serverUrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppSession session) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await session.login(
      serverUrl: _serverUrl.text,
      loginName: _loginName.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F7),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/hero_ink.jpg',
            fit: BoxFit.cover,
            color: Colors.white.withValues(alpha: 0.72),
            colorBlendMode: BlendMode.srcOver,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: AnimatedBuilder(
                  animation: session,
                  builder: (context, _) {
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _LoginBrand(),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.fromLTRB(21, 23, 21, 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFE8EDEC),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x12213E43),
                                  blurRadius: 28,
                                  offset: Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '进入家族',
                                    style: AppTheme.serif(fontSize: 25),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    '使用家庭账户登录，查看当前家族的族谱与档案',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.5,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 19),
                                  TextFormField(
                                    controller: _loginName,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    decoration: _fieldDecoration(
                                      label: '登录名',
                                      icon: Icons.person_outline_rounded,
                                    ),
                                    validator: (value) =>
                                        (value == null || value.trim().isEmpty)
                                        ? '请输入登录名'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _password,
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    onFieldSubmitted: (_) => _submit(session),
                                    decoration:
                                        _fieldDecoration(
                                          label: '密码',
                                          icon: Icons.lock_outline_rounded,
                                        ).copyWith(
                                          suffixIcon: IconButton(
                                            onPressed: () => setState(
                                              () => _obscure = !_obscure,
                                            ),
                                            icon: Icon(
                                              _obscure
                                                  ? Icons
                                                        .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              size: 19,
                                              color: AppColors.inkMuted,
                                            ),
                                          ),
                                        ),
                                    validator: (value) =>
                                        (value == null || value.length < 8)
                                        ? '密码至少 8 位'
                                        : null,
                                  ),
                                  const SizedBox(height: 13),
                                  TextFormField(
                                    controller: _serverUrl,
                                    keyboardType: TextInputType.url,
                                    textInputAction: TextInputAction.next,
                                    style: const TextStyle(fontSize: 12),
                                    decoration:
                                        _fieldDecoration(
                                          label: '服务器地址（本地开发）',
                                          icon: Icons.dns_outlined,
                                        ).copyWith(
                                          helperText: '真机需与电脑在同一局域网',
                                          helperStyle: const TextStyle(
                                            fontSize: 9.5,
                                            color: AppColors.inkMuted,
                                          ),
                                        ),
                                    validator: (value) =>
                                        (value == null || value.trim().isEmpty)
                                        ? '请输入服务器地址'
                                        : null,
                                  ),
                                  if (session.error != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.cinnabarSoft,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Text(
                                        session.error!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          height: 1.4,
                                          color: AppColors.cinnabar,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    height: 48,
                                    child: FilledButton(
                                      onPressed: session.loading
                                          ? null
                                          : () => _submit(session),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        disabledBackgroundColor: AppColors
                                            .primary
                                            .withValues(alpha: 0.55),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: session.loading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              '进入家族',
                                              style: TextStyle(
                                                fontSize: 14,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Center(
                                    child: Text(
                                      '演示账号：linglei / Demo#2026',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => PhoneLoginPage(
                                                serverUrl: _serverUrl.text
                                                    .trim(),
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          '手机号验证码登录',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 12,
                                        color: AppColors.line,
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => RegisterPage(
                                                serverUrl: _serverUrl.text
                                                    .trim(),
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          '有邀请码？注册',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '家族族谱 · 数据保存在你的家庭服务器',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 0.8,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 19, color: AppColors.inkMuted),
      filled: true,
      fillColor: const Color(0xFFF7F9F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE4EBE9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE4EBE9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
    );
  }
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 68,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.cinnabar,
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33B4423D),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Text(
            '族',
            style: TextStyle(
              fontFamily: AppTheme.serifFamily,
              fontSize: 27,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          '家族族谱',
          style: AppTheme.serif(
            fontSize: 32,
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '寻根溯源 · 传承家风',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2.2,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}
