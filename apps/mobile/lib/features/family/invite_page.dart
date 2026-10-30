import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';

class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  List<ApiInvite> _invites = const [];
  List<ApiBranch> _branches = const [];
  String _role = 'member';
  String? _branchId;
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_invites.isEmpty && _loading) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = SessionScope.of(context);
      final invites = await session.invites();
      final branches = await session.branches();
      if (!mounted) return;
      setState(() {
        _invites = invites;
        _branches = branches;
        _branchId ??= branches.isNotEmpty ? branches.first.id : null;
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
    if (_role == 'admin' && _branchId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择分支管理员管辖的家支')));
      return;
    }
    setState(() => _creating = true);
    try {
      final invite = await SessionScope.of(context).createInvite(
        role: _role,
        branchId: _role == 'admin' ? _branchId : null,
      );
      if (!mounted) return;
      setState(() {
        _invites = [invite, ..._invites];
        _creating = false;
      });
      await _copy(invite.code);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('邀请码 $code 已复制')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '邀请成员',
              subtitle: '分享邀请码，成员注册后申请绑定人物',
              actions: [
                HeaderIconButton(icon: Icons.refresh_rounded, onTap: _load),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _error != null
                  ? _ErrorBody(error: _error!, onRetry: _load)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
                      children: [
                        SoftCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.link_rounded,
                                  color: AppColors.primary,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '成员用邀请码注册后先成为普通成员，再在“我的”里申请绑定族谱人物。二维码分享后续接入。',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.65,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SoftCard(
                          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '邀请为',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('普通成员'),
                                    selected: _role == 'member',
                                    onSelected: (_) =>
                                        setState(() => _role = 'member'),
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('分支管理员'),
                                    selected: _role == 'admin',
                                    onSelected: (_) =>
                                        setState(() => _role = 'admin'),
                                  ),
                                ],
                              ),
                              if (_role == 'admin') ...[
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  initialValue: _branchId,
                                  decoration: const InputDecoration(
                                    labelText: '管辖家支（含下级支）',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    for (final branch in _branches)
                                      DropdownMenuItem(
                                        value: branch.id,
                                        child: Text(branch.name),
                                      ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _branchId = value),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _creating ? null : _create,
                          icon: _creating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add_rounded, size: 18),
                          label: const Text('生成新邀请码'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const SectionTitle(title: '邀请码'),
                        const SizedBox(height: 8),
                        if (_invites.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Center(
                              child: Text(
                                '还没有邀请码',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ),
                          )
                        else
                          for (final invite in _invites) ...[
                            _InviteCard(
                              invite: invite,
                              onCopy: () => _copy(invite.code),
                            ),
                            const SizedBox(height: 9),
                          ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invite, required this.onCopy});

  final ApiInvite invite;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final active =
        invite.status == 'active' &&
        invite.usedCount < invite.maxUses &&
        (invite.expiresAt?.isAfter(DateTime.now()) ?? false);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.code,
                      style: const TextStyle(
                        fontSize: 20,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${invite.role == 'admin' ? '分支管理员' : '普通成员'}'
                      '${invite.branchName.isEmpty ? '' : ' · ${invite.branchName}'}'
                      ' · 已用 ${invite.usedCount}/${invite.maxUses} · '
                      '${invite.expiresAt == null ? '永久' : _date(invite.expiresAt!)} 到期',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TagPill(
                label: active ? '可用' : '已失效',
                color: active ? AppColors.jade : AppColors.inkMuted,
                background: active ? AppColors.jadeSoft : AppColors.slateSoft,
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.copy_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _date(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
