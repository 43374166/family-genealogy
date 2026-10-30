import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_data.dart';
import '../../models/family_member.dart';
import '../person/person_detail_page.dart';
import '../requests/requests_page.dart';
import 'family_profile_sheet.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    const person = DemoData.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '我的',
              subtitle: DemoData.family.name,
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
                  _ProfileCard(person: person),
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
                          trailing: DemoData.family.name,
                          onTap: () => showFamilyProfileSheet(context),
                        ),
                        const Divider(height: 1, indent: 47),
                        _MenuRow(
                          icon: Icons.person_outline_rounded,
                          color: AppColors.primary,
                          background: AppColors.primarySoft,
                          label: '个人档案',
                          trailing: person.generationLabel,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const PersonDetailPage(person: person),
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
                            '当前为本地演示版本。账户体系、资料写入与审核流程将在 Go 服务端接入后启用。',
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
                      onPressed: () => _showLogout(context),
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
                  DemoData.family.surname,
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
              DemoData.family.name,
              style: AppTheme.serif(fontSize: 22, letterSpacing: 1),
            ),
            const SizedBox(height: 5),
            const Text(
              '家族族谱 · Flutter 原型 v0.4.0',
              style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              '以人物为中心，记录家族世系、生平与共同记忆。\n本版本仅用于 UI 与交互验证，尚未接入后端。',
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

  void _showLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('演示模式', style: TextStyle(fontSize: 17)),
        content: const Text(
          '尚未接入账户服务，无法退出登录。',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.6,
            color: AppColors.inkSoft,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.person});

  final FamilyMember person;

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
                                  person.tags.first,
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
                            '${person.generationLabel} · ${person.branchId == 'branch_zhang' ? '长房' : '外支'}',
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
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 13,
                      color: AppColors.jade,
                    ),
                    const SizedBox(width: 5),
                    const Expanded(
                      child: Text(
                        '账号已与本人档案关联',
                        style: TextStyle(
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
