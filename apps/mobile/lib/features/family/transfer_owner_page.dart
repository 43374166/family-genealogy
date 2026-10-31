import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';

class TransferOwnerPage extends StatefulWidget {
  const TransferOwnerPage({super.key});

  @override
  State<TransferOwnerPage> createState() => _TransferOwnerPageState();
}

class _TransferOwnerPageState extends State<TransferOwnerPage> {
  List<ApiFamilyAccount> _accounts = const [];
  bool _loading = true;
  bool _submitting = false;
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
    try {
      final accounts = await SessionScope.of(context).accounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
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

  Future<void> _transfer(ApiFamilyAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('转让族长'),
        content: Text(
          '确定把族长转给「${account.displayName}」吗？\n\n'
          '转让后你会变成普通成员，不能再管理邀请、分支管理员和家族设置。',
          style: const TextStyle(fontSize: 12, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认转让'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).transferOwner(account.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('族长已转让给 ${account.displayName}')));
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
    final session = SessionScope.of(context);
    final candidates = _accounts
        .where(
          (account) =>
              account.role != 'owner' && account.userId != session.user?.id,
        )
        .toList(growable: false);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '转让族长', subtitle: '把家族管理权交给另一位成员'),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                      children: [
                        const SoftCard(
                          padding: EdgeInsets.all(15),
                          child: Text(
                            '族长可以把邀请成员、审核、分支管理员和数据导入导出交给下一任。转让后你仍保留普通成员身份，不会退出家族。',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.7,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (candidates.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.group_off_outlined,
                                  size: 40,
                                  color: AppColors.inkMuted,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  '还没有其他成员',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '先在“邀请成员”里邀请家人加入，再转让族长',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          for (var i = 0; i < candidates.length; i++) ...[
                            _AccountRow(
                              account: candidates[i],
                              enabled: !_submitting,
                              onTap: () => _transfer(candidates[i]),
                            ),
                            if (i != candidates.length - 1)
                              const SizedBox(height: 8),
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

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.enabled,
    required this.onTap,
  });

  final ApiFamilyAccount account;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  account.displayName.isEmpty
                      ? '族'
                      : account.displayName.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.personName.isEmpty
                          ? account.loginName
                          : '${account.loginName} · ${account.personName}',
                      style: const TextStyle(
                        fontSize: 10,
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
