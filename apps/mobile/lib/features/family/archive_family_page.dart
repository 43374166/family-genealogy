import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/app_session.dart';

class ArchiveFamilyPage extends StatefulWidget {
  const ArchiveFamilyPage({super.key});

  @override
  State<ArchiveFamilyPage> createState() => _ArchiveFamilyPageState();
}

class _ArchiveFamilyPageState extends State<ArchiveFamilyPage> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _archive() async {
    final family = SessionScope.of(context).family;
    if (family == null) return;
    if (_name.text.trim() != family.name) {
      setState(() => _error = '家族名称输入不一致');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = '请输入当前密码');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认注销家族'),
        content: Text(
          '「${family.name}」将被归档，当前族长账号也会注销，之后无法再登录。\n\n'
          '族谱、照片、故事和审计记录会按归档保留，不会出现在 App 中。\n'
          '此操作不可在 App 内撤销。',
          style: const TextStyle(fontSize: 12, height: 1.75),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认注销'),
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
      await SessionScope.of(
        context,
      ).archiveFamily(password: _password.text, confirmName: _name.text.trim());
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    final family = SessionScope.of(context).family;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '注销家族', subtitle: '归档保留族谱和审计记录'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  SoftCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '注销后会发生什么',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '· 「${family?.name ?? '当前家族'}」从 App 中隐藏；\n'
                          '· 家族成员将无法再访问该家族；\n'
                          '· 当前族长账号注销，无法再登录；\n'
                          '· 族谱、照片、故事和审计记录归档保留，不做物理删除；\n'
                          '· 需要先确保家族里只有你一个成员。',
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.8,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '请输入家族名称确认',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      hintText: family?.name,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '输入当前密码',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                      border: OutlineInputBorder(),
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
                  OutlinedButton(
                    onPressed: _submitting ? null : _archive,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cinnabar,
                      side: const BorderSide(color: Color(0xFFE6C4C0)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('注销家族并注销族长账号'),
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
