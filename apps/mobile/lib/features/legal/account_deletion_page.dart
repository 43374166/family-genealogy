import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/api_client.dart';
import '../../services/app_session.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _error = '请输入当前账号密码');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认注销账号'),
        content: const Text(
          '注销后账号无法登录，登录名、手机号和密码会被删除；\n'
          '家族共同维护的族谱、照片和故事仍会保留。\n\n'
          '此操作不可撤销。',
          style: TextStyle(fontSize: 12, height: 1.7),
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
      await SessionScope.of(context).deleteAccount(password);
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
    final session = SessionScope.of(context);
    final owner = session.isOwner;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '账号注销', subtitle: '删除登录身份和个人信息'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  const SoftCard(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '注销后会删除什么',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 9),
                        Text(
                          '· 登录名、手机号、密码和登录会话\n'
                          '· 在所有家族中的成员身份和分支管理员权限\n'
                          '· 个人通知\n\n'
                          '保留：家族共同维护的族谱人物、关系、照片和故事。'
                          '这些内容属于家族，不会因单个账号注销而删除。',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.75,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (owner)
                    const SoftCard(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        '当前账号是族长，暂不能直接注销。\n'
                        '请先把族长转让给其他家族成员，或联系服务器管理员处理家族数据后再注销。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.75,
                          color: AppColors.cinnabar,
                        ),
                      ),
                    )
                  else ...[
                    const Text(
                      '输入当前密码确认',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '当前密码',
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
                      onPressed: _submitting ? null : _delete,
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
                          : const Text('注销我的账号'),
                    ),
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
