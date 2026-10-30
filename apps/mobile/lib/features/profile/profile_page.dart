import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_data.dart';
import '../../models/family_member.dart';
import '../../services/app_session.dart';
import '../family/bind_person_page.dart';
import '../family/binding_requests_page.dart';
import '../family/branch_admins_page.dart';
import '../family/invite_page.dart';
import '../family/phone_bind_page.dart';
import '../person/api_person_detail_page.dart';
import '../requests/requests_page.dart';
import 'family_profile_sheet.dart';

String _maskPhone(String phone) {
  if (phone.length < 8) return phone;
  return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final linkedPersonId = session.membership?.personId;
    final person =
        session.memberById(linkedPersonId) ??
        FamilyMember(
          id: session.user?.id ?? 'account',
          familyId: session.family?.id ?? '',
          branchId: '',
          name: session.user?.displayName ?? '家族成员',
          gender: Gender.male,
          generation: 0,
        );
    final familyName = session.family?.name ?? DemoData.family.name;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '我的',
              subtitle: familyName,
              showBack: false,
              padding: const EdgeInsets.fromLTRB(22, 8, 16, 8),
              actions: [
                HeaderIconButton(
                  icon: Icons.settings_outlined,
                  onTap: () => _notice(context),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                children: [
                  _ProfileCard(
                    person: person,
                    roleLabel: session.membership?.role == 'owner'
                        ? '族长'
                        : session.membership?.role == 'admin'
                        ? '分支管理员'
                        : '普通成员',
                  ),
                  const SizedBox(height: 14),
                  _StatsRow(),
                  const SizedBox(height: 18),
                  const SectionTitle(title: '我的服务'),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    child: Column(
                      children: [
                        _MenuRow(
                          icon: Icons.diversity_3_rounded,
                          color: AppColors.jade,
                          background: AppColors.jadeSoft,
                          label: '家庭资料',
                          trailing: familyName,
                          onTap: () => showFamilyProfileSheet(context),
                        ),
                        const Divider(height: 1, indent: 47),
                        if (session.isOwner) ...[
                          _MenuRow(
                            icon: Icons.link_rounded,
                            color: AppColors.primary,
                            background: AppColors.primarySoft,
                            label: '邀请成员',
                            trailing: '邀请码',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const InvitePage(),
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 47),
                          _MenuRow(
                            icon: Icons.admin_panel_settings_outlined,
                            color: AppColors.gold,
                            background: AppColors.goldSoft,
                            label: '分支管理员',
                            trailing: '任免',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BranchAdminsPage(),
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 47),
                        ],
                        if (session.canWrite) ...[
                          _MenuRow(
                            icon: Icons.how_to_reg_outlined,
                            color: AppColors.jade,
                            background: AppColors.jadeSoft,
                            label: '绑定审核',
                            trailing: '成员绑定',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BindingRequestsPage(),
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 47),
                        ] else if (linkedPersonId == null) ...[
                          _MenuRow(
                            icon: Icons.person_pin_circle_outlined,
                            color: AppColors.gold,
                            background: AppColors.goldSoft,
                            label: '绑定族谱人物',
                            trailing: '未绑定',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BindPersonPage(),
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 47),
                        ],
                        _MenuRow(
                          icon: Icons.person_outline_rounded,
                          color: AppColors.primary,
                          background: AppColors.primarySoft,
                          label: '个人档案',
                          trailing: linkedPersonId == null
                              ? '未绑定'
                              : person.generationLabel,
                          onTap: () {
                            if (linkedPersonId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('尚未绑定族谱人物，请先提交绑定申请'),
                                ),
                              );
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ApiPersonDetailPage(
                                  personId: linkedPersonId,
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 47),
                        _MenuRow(
                          icon: Icons.phone_iphone_rounded,
                          color: AppColors.teal,
                          background: AppColors.tealSoft,
                          label: '手机号',
                          trailing: (session.user?.phone ?? '').isEmpty
                              ? '未绑定'
                              : _maskPhone(session.user!.phone),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PhoneBindPage(),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 47),
                        _MenuRow(
                          icon: Icons.assignment_outlined,
                          color: AppColors.gold,
                          background: AppColors.goldSoft,
                          label: '我的申请',
                          trailing: '1 条待审核',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RequestsPage(),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 47),
                        _MenuRow(
                          icon: Icons.photo_library_outlined,
                          color: AppColors.teal,
                          background: AppColors.tealSoft,
                          label: '我上传的影像',
                          trailing: '6 张',
                          onTap: () => _notice(context),
                        ),
                        const Divider(height: 1, indent: 47),
                        _MenuRow(
                          icon: Icons.bookmark_border_rounded,
                          color: AppColors.cinnabar,
                          background: AppColors.cinnabarSoft,
                          label: '收藏的家族故事',
                          trailing: '3 篇',
                          onTap: () => _notice(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SectionTitle(title: '账户与安全'),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    child: Column(
                      children: [
                        _MenuRow(
                          icon: Icons.shield_outlined,
                          color: AppColors.jade,
                          background: AppColors.jadeSoft,
                          label: '隐私与展示范围',
                          onTap: () => _notice(context),
                        ),
                        const Divider(height: 1, indent: 47),
                        _MenuRow(
                          icon: Icons.devices_rounded,
                          color: AppColors.violet,
                          background: AppColors.violetSoft,
                          label: '登录设备',
                          trailing: '1 台',
                          onTap: () => _notice(context),
                        ),
                        const Divider(height: 1, indent: 47),
                        _MenuRow(
                          icon: Icons.info_outline_rounded,
                          color: AppColors.inkMuted,
                          background: AppColors.slateSoft,
                          label: '关于家族族谱',
                          trailing: 'v0.4.0',
                          onTap: () => _showAbout(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF0EBDD)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.science_outlined,
                          size: 17,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '当前已连接家庭服务器。资料写入、关系维护与审核流程将在下一阶段启用。',
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.65,
                              color: AppColors.ink.withValues(alpha: 0.58),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton(
                      onPressed: () => _showLogout(context, session),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.inkMuted,
                      ),
                      child: const Text(
                        '退出登录',
                        style: TextStyle(fontSize: 11.5),
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

  void _notice(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('该能力将在后续版本开放')));
  }

  void _showAbout(BuildContext context) {
    final family = SessionScope.of(context).family;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.cinnabarSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  family?.surname ?? DemoData.family.surname,
                  style: const TextStyle(
                    fontFamily: AppTheme.serifFamily,
                    fontSize: 30,
                    color: AppColors.cinnabar,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            Text(
              family?.name ?? DemoData.family.name,
              style: AppTheme.serif(fontSize: 22, letterSpacing: 1),
            ),
            const SizedBox(height: 5),
            const Text(
              '家族族谱 · Flutter + MySQL v0.16.0',
              style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              '以人物为中心，记录家族世系、生平与共同记忆。\n当前已接入家庭服务器，写入与审核能力将在下一阶段开放。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.7,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 19),
            TagPill(
              label: 'Flutter 3.35 · Android / iOS',
              color: AppColors.inkMuted,
              background: AppColors.slateSoft,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogout(BuildContext context, AppSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('退出登录', style: TextStyle(fontSize: 17)),
        content: const Text(
          '退出后需要重新输入家庭账户密码。',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.6,
            color: AppColors.inkSoft,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await session.logout();
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.person, required this.roleLabel});

  final FamilyMember person;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3EEE2), Color(0xFFDDE8E9)],
        ),
        border: Border.all(color: Colors.white),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            top: -20,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    InkPortrait(
                      person: person,
                      width: 70,
                      height: 82,
                      radius: 17,
                      showBorder: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                person.name,
                                style: AppTheme.serif(
                                  fontSize: 24,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.66),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  roleLabel,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.inkSoft,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            person.generation > 0
                                ? '${person.generationLabel} · 族谱成员'
                                : '账号已加入家庭 · 尚未绑定族谱人物',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'ID ${person.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8.5,
                              letterSpacing: 0.3,
                              color: AppColors.ink.withValues(alpha: 0.42),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 21,
                      color: AppColors.inkSoft,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  height: 1,
                  color: AppColors.inkMuted.withValues(alpha: 0.14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      person.generation > 0
                          ? Icons.verified_user_outlined
                          : Icons.link_off_rounded,
                      size: 13,
                      color: person.generation > 0
                          ? AppColors.jade
                          : AppColors.inkMuted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        person.generation > 0 ? '账号已与本人档案关联' : '尚未绑定族谱人物',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                    const Text(
                      '2024 年 4 月加入',
                      style: TextStyle(fontSize: 9, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          children: const [
            _StatItem(value: '3', label: '我的申请'),
            VerticalDivider(width: 1, thickness: 1, color: AppColors.line),
            _StatItem(value: '12', label: '家族贡献'),
            VerticalDivider(width: 1, thickness: 1, color: AppColors.line),
            _StatItem(value: '2', label: '加入年数'),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppTheme.serifFamily,
              fontSize: 19,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.color,
    required this.background,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(width: 3),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
