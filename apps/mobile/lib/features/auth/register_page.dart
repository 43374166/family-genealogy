import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../services/app_session.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.serverUrl});

  final String serverUrl;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCode = TextEditingController();
  final _loginName = TextEditingController();
  final _displayName = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _inviteCode.dispose();
    _loginName.dispose();
    _displayName.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await SessionScope.of(context).register(
      serverUrl: widget.serverUrl,
      loginName: _loginName.text.trim(),
      password: _password.text,
      displayName: _displayName.text.trim(),
      inviteCode: _inviteCode.text.trim().toUpperCase(),
      phone: _phone.text.trim(),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const AppPageHeader(title: '加入家族', subtitle: '使用族长提供的邀请码注册'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
                  children: [
                    Text(
                      '创建账号',
                      style: AppTheme.serif(fontSize: 27, letterSpacing: 1),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '手机号可先留空，后续接入手机号一键登录。',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Field(
                      controller: _inviteCode,
                      label: '邀请码',
                      hint: '向族长获取，例如 A7K9P2QX',
                      icon: Icons.key_rounded,
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) =>
                          (value ?? '').trim().length < 6 ? '请输入有效邀请码' : null,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _loginName,
                      label: '登录名',
                      hint: '英文或数字，用于登录',
                      icon: Icons.person_outline_rounded,
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? '请输入登录名' : null,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _displayName,
                      label: '显示名',
                      hint: '例如：凌磊',
                      icon: Icons.badge_outlined,
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? '请输入显示名' : null,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _phone,
                      label: '手机号（可选）',
                      hint: '+8613800000000',
                      icon: Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) return null;
                        if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(text)) {
                          return '请使用国际格式，例如 +8613800000000';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _password,
                      label: '密码',
                      hint: '至少 8 位',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscure,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                      ),
                      validator: (value) =>
                          (value ?? '').length < 8 ? '密码至少 8 位' : null,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _confirm,
                      label: '确认密码',
                      hint: '再次输入密码',
                      icon: Icons.lock_reset_rounded,
                      obscureText: _obscure,
                      validator: (value) =>
                          value != _password.text ? '两次密码不一致' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.cinnabar,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('注册并加入'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '注册后先成为普通成员，再申请绑定族谱中的人物；绑定需族长审核。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? suffix;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 19),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
