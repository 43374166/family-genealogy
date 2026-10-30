import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../services/api_client.dart';
import '../../services/app_session.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key, required this.serverUrl});

  final String serverUrl;

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  Timer? _timer;
  int _countdown = 0;
  bool _sending = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  bool _validPhone(String phone) =>
      RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone.trim());

  Future<void> _send() async {
    final phone = _phone.text.trim();
    if (!_validPhone(phone)) {
      setState(() => _error = '请输入国际格式手机号，例如 +8613800000000');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).sendLoginCode(phone);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _countdown = 60;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_countdown <= 1) {
          timer.cancel();
          setState(() => _countdown = 0);
        } else {
          setState(() => _countdown -= 1);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码已发送，请查收短信')));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.message;
      });
    }
  }

  Future<void> _login() async {
    final phone = _phone.text.trim();
    final code = _code.text.trim();
    if (!_validPhone(phone) || code.length != 6) {
      setState(() => _error = '请输入手机号和 6 位验证码');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await SessionScope.of(
      context,
    ).loginWithPhone(serverUrl: widget.serverUrl, phone: phone, code: code);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _submitting = false;
      _error = SessionScope.of(context).error ?? '登录失败，请重试';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '手机号登录', subtitle: '验证码登录，需先在账号中绑定手机号'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
                children: [
                  Text(
                    '验证码登录',
                    style: AppTheme.serif(fontSize: 27, letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '手机号需使用国际格式；未绑定手机号的账号请先用登录名登录后绑定。',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: '手机号',
                      hintText: '+8613800000000',
                      prefixIcon: const Icon(Icons.phone_iphone_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: '验证码',
                            counterText: '',
                            prefixIcon: const Icon(Icons.sms_outlined),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 58,
                        child: OutlinedButton(
                          onPressed: _sending || _countdown > 0 ? null : _send,
                          child: Text(
                            _countdown > 0
                                ? '${_countdown}s'
                                : _sending
                                ? '发送中'
                                : '发送验证码',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
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
                    onPressed: _submitting ? null : _login,
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
                        : const Text('登录'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
