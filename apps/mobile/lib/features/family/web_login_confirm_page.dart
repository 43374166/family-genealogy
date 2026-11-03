import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';

class WebLoginConfirmPage extends StatefulWidget {
  const WebLoginConfirmPage({
    super.key,
    required this.qrId,
    required this.secret,
  });

  final String qrId;
  final String secret;

  @override
  State<WebLoginConfirmPage> createState() => _WebLoginConfirmPageState();
}

class _WebLoginConfirmPageState extends State<WebLoginConfirmPage> {
  ApiQrLoginContext? _context;
  String? _error;
  bool _loading = true;
  bool _confirming = false;
  bool _confirmed = false;
  bool _cancelling = false;
  bool _started = false;
  Timer? _countdownTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _scan();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _context?.expiresAt != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await SessionScope.of(
        context,
      ).scanWebLogin(id: widget.qrId, secret: widget.secret);
      if (!mounted) return;
      setState(() {
        _context = result;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      await SessionScope.of(
        context,
      ).confirmWebLogin(id: widget.qrId, secret: widget.secret);
      if (!mounted) return;
      setState(() {
        _confirmed = true;
        _confirming = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    try {
      await SessionScope.of(
        context,
      ).cancelWebLogin(id: widget.qrId, secret: widget.secret);
    } on ApiException {
      // Best effort: the QR will expire on its own.
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(
              title: '扫码登录网页',
              subtitle: '确认电脑端登录请求',
              showBack: true,
              padding: EdgeInsets.fromLTRB(16, 8, 22, 8),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _error != null
                  ? _ErrorView(message: _error!, onRetry: _scan)
                  : _confirmed
                  ? const _SuccessView()
                  : _buildConfirm(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirm(BuildContext context) {
    final info = _context!;
    final expiresAt = info.expiresAt;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        MediaQuery.paddingOf(context).bottom + 26,
      ),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 25, 22, 23),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF6F9F7), Color(0xFFFFFDF7)],
            ),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A20323B),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.desktop_windows_outlined,
                  color: AppColors.primary,
                  size: 29,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                '有人请求登录网页版',
                style: AppTheme.serif(fontSize: 21, letterSpacing: 0.5),
              ),
              const SizedBox(height: 7),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '确认后，浏览器会以你当前的账号和家族身份登录。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.inkMuted,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(17, 6, 17, 6),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'IP 归属地',
                value: info.locationLabel,
                highlight: true,
              ),
              const Divider(height: 1, indent: 32),
              _InfoRow(
                icon: Icons.language_rounded,
                label: '请求 IP',
                value: info.requestIp.isEmpty ? '无法获取' : info.requestIp,
              ),
              const Divider(height: 1, indent: 32),
              _InfoRow(
                icon: Icons.devices_outlined,
                label: '设备',
                value: info.requestDevice.isEmpty ? '未知设备' : info.requestDevice,
              ),
              if (expiresAt != null) ...[
                const Divider(height: 1, indent: 32),
                _InfoRow(
                  icon: Icons.timer_outlined,
                  label: '二维码有效期',
                  value: _formatExpiry(expiresAt),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.goldSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.security_rounded, size: 17, color: AppColors.gold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '只有在你本人发起网页登录时才确认。登录后请留意电脑端显示的 IP / 城市是否与你当前所在位置一致。',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.7,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 47,
          child: FilledButton(
            onPressed: _confirming ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: _confirming
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '确认登录网页版',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 7),
        TextButton(
          onPressed: _cancelling ? null : _cancel,
          style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
          child: Text(
            _cancelling ? '正在取消…' : '不是我，取消这次登录',
            style: const TextStyle(fontSize: 11.5),
          ),
        ),
      ],
    );
  }

  String _formatExpiry(DateTime date) {
    final remaining = date.toLocal().difference(DateTime.now());
    if (remaining.isNegative) return '已过期';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return '$minutes 分 ${seconds.toString().padLeft(2, '0')} 秒';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                color: highlight ? AppColors.cinnabar : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.cinnabarSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: AppColors.cinnabar,
                size: 27,
              ),
            ),
            const SizedBox(height: 14),
            Text('无法确认这次登录', style: AppTheme.serif(fontSize: 20)),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.7,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 17),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: AppColors.jadeSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.jade,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text('电脑端已登录', style: AppTheme.serif(fontSize: 22)),
            const SizedBox(height: 8),
            const Text(
              '网页端会自动进入你的家族空间。现在可以关闭这个页面了。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.75,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }
}
