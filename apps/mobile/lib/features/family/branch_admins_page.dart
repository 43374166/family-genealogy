import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/status_pill.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';

class BranchAdminsPage extends StatefulWidget {
  const BranchAdminsPage({super.key});

  @override
  State<BranchAdminsPage> createState() => _BranchAdminsPageState();
}

class _BranchAdminsPageState extends State<BranchAdminsPage> {
  List<ApiBranchAdminGrant> _grants = const [];
  List<ApiFamilyAccount> _accounts = const [];
  List<ApiBranch> _branches = const [];
  bool _loading = true;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = SessionScope.of(context);
      final grants = await session.branchAdmins();
      final accounts = await session.accounts();
      final branches = await session.branches();
      if (!mounted) return;
      setState(() {
        _grants = grants;
        _accounts = accounts;
        _branches = branches;
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

  Future<void> _add() async {
    final candidates = _accounts.where((item) => item.role != 'owner').toList();
    if (candidates.isEmpty || _branches.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('还没有可任命的成员或家支')));
      return;
    }
    var accountId = candidates.first.userId;
    var branchId = _branches.first.id;
    var includeDescendants = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('任命分支管理员'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: accountId,
                    decoration: const InputDecoration(labelText: '成员'),
                    items: [
                      for (final account in candidates)
                        DropdownMenuItem(
                          value: account.userId,
                          child: Text(
                            account.personName.isEmpty
                                ? account.displayName
                                : '${account.personName} · ${account.displayName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => accountId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: branchId,
                    decoration: const InputDecoration(labelText: '管辖家支'),
                    items: [
                      for (final branch in _branches)
                        DropdownMenuItem(
                          value: branch.id,
                          child: Text(
                            branch.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => branchId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    value: includeDescendants,
                    onChanged: (value) => setDialogState(
                      () => includeDescendants = value ?? true,
                    ),
                    title: const Text('包含下级支', style: TextStyle(fontSize: 12)),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认任命'),
              ),
            ],
          );
        },
      ),
    );
    if (result != true || !mounted) return;
    try {
      await SessionScope.of(context).grantBranchAdmin(
        userId: accountId,
        branchId: branchId,
        includeDescendants: includeDescendants,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已任命分支管理员')));
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _revoke(ApiBranchAdminGrant grant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销分支管理员'),
        content: Text('撤销 ${grant.displayName} 对 ${grant.branchName} 的管理权限？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤销'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SessionScope.of(context).revokeBranchAdmin(grant.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已撤销')));
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
            AppPageHeader(
              title: '分支管理员',
              subtitle: '按家支授权，范围含下级支',
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
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                      children: [
                        FilledButton.icon(
                          onPressed: _add,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('任命管理员'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_grants.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 34),
                            child: Center(
                              child: Text(
                                '还没有分支管理员',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ),
                          )
                        else
                          for (final grant in _grants) ...[
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                15,
                                13,
                                15,
                                13,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.admin_panel_settings_outlined,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          grant.displayName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                      TagPill(
                                        label: grant.includeDescendants
                                            ? '含下级支'
                                            : '仅本支',
                                        color: AppColors.jade,
                                        background: AppColors.jadeSoft,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${grant.branchName} · @${grant.loginName}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _revoke(grant),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.cinnabar,
                                      ),
                                      child: const Text('撤销权限'),
                                    ),
                                  ),
                                ],
                              ),
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
