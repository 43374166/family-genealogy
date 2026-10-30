import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';

class MyQrPage extends StatefulWidget {
  const MyQrPage({super.key});

  @override
  State<MyQrPage> createState() => _MyQrPageState();
}

class _MyQrPageState extends State<MyQrPage> {
  ApiInvite? _invite;
  bool _loading = true;
  bool _creating = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    try {
      final invites = await session.invites();
      final now = DateTime.now();
      ApiInvite? active;
      for (final invite in invites) {
        final expired =
            invite.expiresAt != null && invite.expiresAt!.isBefore(now);
        if (invite.status == 'active' &&
            invite.role == 'member' &&
            !expired &&
            invite.usedCount < invite.maxUses) {
          active = invite;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _invite = active;
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

  Future<void> _create() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final invite = await SessionScope.of(
        context,
      ).createInvite(role: 'member', maxUses: 20, expiresInDays: 30);
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _creating = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = error.message;
      });
    }
  }

  Future<void> _copy() async {
    final invite = _invite;
    if (invite == null) return;
    final family = SessionScope.of(context).family?.name ?? '家族';
    await Clipboard.setData(
      ClipboardData(
        text:
            '邀请你加入$family\n'
            '打开“家族族谱”App → 登录页 → 用邀请码注册/加入\n'
            '邀请码：${invite.code}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('邀请信息已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final invite = _invite;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '我的二维码', subtitle: '扫码加入当前家族'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: Column(
                      children: [
                        Text(
                          session.family?.name ?? '家族',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '邀请加入家族',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (invite != null)
                          QrImageView(
                            data: invite.code,
                            version: QrVersions.auto,
                            size: 210,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.ink,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.ink,
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              '当前没有可用的邀请码',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                        if (invite != null) ...[
                          const SizedBox(height: 16),
                          SelectableText(
                            invite.code,
                            style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '有效期至 ${_date(invite.expiresAt)} · 已用 ${invite.usedCount}/${invite.maxUses}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _copy,
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('复制邀请'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _creating ? null : _create,
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('换一个'),
                                ),
                              ),
                            ],
                          ),
                        ] else if (!_loading) ...[
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _creating ? null : _create,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size.fromHeight(46),
                            ),
                            child: const Text('生成邀请二维码'),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.cinnabar,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const SoftCard(
                    padding: EdgeInsets.all(15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: AppColors.gold,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '对方用这个二维码加入后，会成为当前家族的普通成员。族长可在“邀请成员”里查看邀请码使用情况。',
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.65,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
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

String _date(DateTime? value) {
  if (value == null) return '长期';
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
