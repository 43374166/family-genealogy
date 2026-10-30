import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/app_session.dart';

class PhoneBindPage extends StatefulWidget {
  const PhoneBindPage({super.key});

  @override
  State<PhoneBindPage> createState() => _PhoneBindPageState();
}

class _PhoneBindPageState extends State<PhoneBindPage> {
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
      await SessionScope.of(context).sendBindCode(phone);
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

  Future<void> _bind() async {
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
    try {
      await SessionScope.of(context).bindPhone(phone: phone, code: code);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('手机号已绑定'),
          content: const Text('以后可以直接用手机号和验证码登录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPhone = SessionScope.of(context).user?.phone ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '绑定手机号', subtitle: '验证后可手机号验证码登录'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                children: [
                  SoftCard(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phone_iphone_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            currentPhone.isEmpty
                                ? '当前账号未绑定手机号'
                                : '当前手机号：$currentPhone',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '新手机号',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
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
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _bind,
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
                        : const Text('确认绑定'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '手机号只用于登录验证，不会公开展示。',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.55,
                      color: AppColors.inkMuted,
                    ),
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
