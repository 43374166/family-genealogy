import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../services/api_client.dart';
import '../../services/app_session.dart';
import 'join_family_page.dart';

class FamilySwitchPage extends StatefulWidget {
  const FamilySwitchPage({super.key});

  @override
  State<FamilySwitchPage> createState() => _FamilySwitchPageState();
}

class _FamilySwitchPageState extends State<FamilySwitchPage> {
  bool _busy = false;
  String? _error;

  Future<void> _switch(String familyId, String name) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.of(context).switchFamily(familyId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已切换到$name')));
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final surname = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新家族'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '家族名称',
                  hintText: '例如：凌氏家族',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: surname,
                decoration: const InputDecoration(
                  labelText: '姓氏',
                  hintText: '例如：凌',
                ),
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
            child: const Text('创建'),
          ),
        ],
      ),
    );
    final familyName = name.text.trim();
    final familySurname = surname.text.trim();
    name.dispose();
    surname.dispose();
    if (created != true || !mounted) return;
    if (familyName.isEmpty || familySurname.isEmpty) {
      setState(() => _error = '请填写家族名称和姓氏');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.of(
        context,
      ).createFamily(name: familyName, surname: familySurname);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已创建$familyName')));
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final families = session.families;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '我的家族', subtitle: '一个账号可以属于多个家族'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.diversity_3_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            '切换后，族谱、成员和审核都会按当前家族显示。新建家族后你就是族长。',
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
                  FilledButton.icon(
                    onPressed: _busy ? null : _create,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('创建新家族'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const JoinFamilyPage(),
                            ),
                          ),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('填写邀请码或扫码加入'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.cinnabar,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    '已加入的家族',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (families.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '还没有家族',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final item in families) ...[
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        child: InkWell(
                          onTap: _busy || item.family.id == session.family?.id
                              ? null
                              : () => _switch(item.family.id, item.family.name),
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: item.family.id == session.family?.id
                                        ? AppColors.jadeSoft
                                        : AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.membership.role == 'owner'
                                        ? Icons.workspace_premium_outlined
                                        : Icons.people_outline_rounded,
                                    size: 19,
                                    color: item.family.id == session.family?.id
                                        ? AppColors.jade
                                        : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.family.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${item.membership.roleLabel} · ${item.family.memberCount} 人',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.family.id == session.family?.id)
                                  const TagPill(
                                    label: '当前',
                                    color: AppColors.jade,
                                    background: AppColors.jadeSoft,
                                  )
                                else
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: AppColors.inkMuted,
                                  ),
                              ],
                            ),
                          ),
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
