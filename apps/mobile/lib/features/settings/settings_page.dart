import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../services/app_session.dart';
import '../../services/app_settings.dart';
import '../family/bind_person_page.dart';
import '../family/binding_requests_page.dart';
import '../family/export_family_page.dart';
import '../family/family_switch_page.dart';
import '../family/import_family_page.dart';
import '../family/invite_page.dart';
import '../family/phone_bind_page.dart';
import '../person/api_person_detail_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _version = '0.27.0';

  Future<void> _pickTextSize(BuildContext context) async {
    final settings = SettingsScope.of(context);
    final selected = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 2, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '字体大小',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              for (final option in const [
                (0.9, '小'),
                (1.0, '标准'),
                (1.15, '大'),
                (1.3, '特大'),
              ])
                ListTile(
                  title: Text(option.$2),
                  trailing: (settings.textScale - option.$1).abs() < 0.01
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    setSheetState(() {});
                    Navigator.of(context).pop(option.$1);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await settings.setTextScale(selected);
    }
  }

  Future<void> _clearCache(BuildContext context) async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('图片缓存已清理')));
  }

  Future<void> _showPrivacy(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('隐私与展示范围'),
        content: const Text(
          '当前范围：\n'
          '· 手机号只用于登录、找回和成员绑定，不在族谱中公开；\n'
          '· 族谱、成员和照片只对当前家族成员可见；\n'
          '· 照片存放在私有对象存储，读取时需要登录鉴权；\n'
          '· 族长和分支管理员在授权范围内可以审核、维护资料。',
          style: TextStyle(fontSize: 12, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAbout(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于家族族谱'),
        content: Text(
          '家族族谱 v$_version\n\n'
          '支持多家族、邀请加入、族谱维护、审核、数据导入和家族相册。',
          style: const TextStyle(fontSize: 12, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final session = SessionScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后需要重新输入账号密码。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await session.logout();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final settings = SettingsScope.of(context);
    final linkedId = session.membership?.personId;
    final person = session.memberById(linkedId);
    final phone = session.user?.phone ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppPageHeader(title: '设置', subtitle: '账号、显示与通用设置'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                children: [
                  const SectionTitle(title: '账号'),
                  const SizedBox(height: 9),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    child: Column(
                      children: [
                        _SettingRow(
                          icon: Icons.badge_outlined,
                          label: '登录账号',
                          trailing: session.user?.loginName ?? '-',
                        ),
                        const Divider(height: 1, indent: 47),
                        _SettingRow(
                          icon: Icons.phone_iphone_rounded,
                          label: '手机号',
                          trailing: phone.isEmpty ? '未绑定' : _maskPhone(phone),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PhoneBindPage(),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 47),
                        _SettingRow(
                          icon: Icons.person_pin_circle_outlined,
                          label: '绑定族谱人物',
                          trailing: linkedId == null
                              ? '未绑定'
                              : person?.generationLabel ?? '已绑定',
                          onTap: () {
                            if (linkedId == null) {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const BindPersonPage(),
                                ),
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ApiPersonDetailPage(personId: linkedId),
                                ),
                              );
                            }
                          },
                        ),
                        const Divider(height: 1, indent: 47),
                        _SettingRow(
                          icon: Icons.diversity_3_rounded,
                          label: '当前家族',
                          trailing: session.family?.name ?? '-',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FamilySwitchPage(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SectionTitle(title: '通用'),
                  const SizedBox(height: 9),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    child: Column(
                      children: [
                        _SettingRow(
                          icon: Icons.text_fields_rounded,
                          label: '字体大小',
                          trailing: _textScaleLabel(settings.textScale),
                          onTap: () => _pickTextSize(context),
                        ),
                        const Divider(height: 1, indent: 47),
                        _SettingRow(
                          icon: Icons.cleaning_services_outlined,
                          label: '清除图片缓存',
                          trailing: '释放临时空间',
                          onTap: () => _clearCache(context),
                        ),
                        const Divider(height: 1, indent: 47),
                        _SettingRow(
                          icon: Icons.shield_outlined,
                          label: '隐私与展示范围',
                          trailing: '仅本家族',
                          onTap: () => _showPrivacy(context),
                        ),
                        const Divider(height: 1, indent: 47),
                        _SettingRow(
                          icon: Icons.info_outline_rounded,
                          label: '关于家族族谱',
                          trailing: 'v$_version',
                          onTap: () => _showAbout(context),
                        ),
                      ],
                    ),
                  ),
                  if (session.isOwner || session.canWrite) ...[
                    const SizedBox(height: 18),
                    const SectionTitle(title: '家族管理'),
                    const SizedBox(height: 9),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      child: Column(
                        children: [
                          if (session.isOwner) ...[
                            _SettingRow(
                              icon: Icons.link_rounded,
                              label: '邀请成员',
                              trailing: '邀请码',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const InvitePage(),
                                ),
                              ),
                            ),
                            const Divider(height: 1, indent: 47),
                            _SettingRow(
                              icon: Icons.ios_share_rounded,
                              label: '导出旁支数据',
                              trailing: '生成导入码',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ExportFamilyPage(),
                                ),
                              ),
                            ),
                            const Divider(height: 1, indent: 47),
                            _SettingRow(
                              icon: Icons.move_to_inbox_outlined,
                              label: '导入旁支数据',
                              trailing: '选择分支/世代',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ImportFamilyPage(),
                                ),
                              ),
                            ),
                            const Divider(height: 1, indent: 47),
                          ],
                          if (session.canWrite)
                            _SettingRow(
                              icon: Icons.how_to_reg_outlined,
                              label: '绑定审核',
                              trailing: '成员绑定',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const BindingRequestsPage(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => _logout(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cinnabar,
                      side: const BorderSide(color: Color(0xFFE6C4C0)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('退出登录'),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      '账号数据与族谱资料分开保存',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    this.trailing = '',
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.inkSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
              ),
            ),
            if (trailing.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  trailing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _maskPhone(String phone) {
  if (phone.length < 8) return phone;
  return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
}

String _textScaleLabel(double scale) {
  if (scale <= 0.95) return '小';
  if (scale >= 1.25) return '特大';
  if (scale >= 1.1) return '大';
  return '标准';
}
