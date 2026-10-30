import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../models/family_member.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../family/bind_person_page.dart';
import '../gallery/gallery_page.dart';
import '../person/api_person_detail_page.dart';
import '../profile/family_profile_sheet.dart';
import '../requests/edit_request_page.dart';
import '../requests/requests_page.dart';
import '../search/member_search_page.dart';
import '../stories/stories_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onOpenTree,
    required this.onOpenMessages,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenTree;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenProfile;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<ApiActivity> _activities = const [];
  bool _activityLoading = true;
  String? _activityError;
  String? _activityFamilyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final familyId = SessionScope.of(context).family?.id;
    if (familyId == null || familyId == _activityFamilyId) return;
    _activityFamilyId = familyId;
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() {
      _activityLoading = true;
      _activityError = null;
    });
    try {
      final items = await SessionScope.of(context).activity(limit: 20);
      if (!mounted) return;
      setState(() {
        _activities = items;
        _activityLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _activityError = error.message;
        _activityLoading = false;
      });
    }
  }

  Future<void> _startEditRequest(BuildContext context) async {
    final person = await Navigator.of(context).push<ApiPerson>(
      MaterialPageRoute<ApiPerson>(
        builder: (_) => const MemberSearchPage(selectMode: true),
      ),
    );
    if (person == null || !context.mounted) return;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            EditRequestPage(personId: person.id, initialPerson: person),
      ),
    );
    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('资料申请已提交，等待审核')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Stack(
              children: [
                _HeroBackdrop(topInset: topInset),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: topInset + 8),
                    _HomeTopBar(
                      onOpenMessages: widget.onOpenMessages,
                      onOpenProfile: widget.onOpenProfile,
                    ),
                    const SizedBox(height: 18),
                    _FamilyIdentity(
                      onTap: () => showFamilyProfileSheet(context),
                    ),
                    const SizedBox(height: 22),
                    _SummaryCard(
                      onMembersTap: () =>
                          _open(context, const MemberSearchPage()),
                      onBranchesTap: () => _showBranches(context),
                      onProfileTap: () {
                        final linkedId = SessionScope.of(
                          context,
                        ).membership?.personId;
                        if (linkedId == null) {
                          _open(context, const BindPersonPage());
                        } else {
                          _open(
                            context,
                            ApiPersonDetailPage(personId: linkedId),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _QuickActions(
                      onTree: widget.onOpenTree,
                      onSearch: () => _open(context, const MemberSearchPage()),
                      onEditProfile: () => _startEditRequest(context),
                      onRequests: () => _open(context, const RequestsPage()),
                      onGallery: () => _open(context, const GalleryPage()),
                      onStories: () => _open(context, const StoriesPage()),
                    ),
                    const SizedBox(height: 14),
                    _LatestActivity(
                      activities: _activities,
                      loading: _activityLoading,
                      error: _activityError,
                      onRetry: _loadActivity,
                      onMore: () => _open(
                        context,
                        _ActivityFeedPage(
                          activities: _activities,
                          loading: _activityLoading,
                          error: _activityError,
                          onRetry: _loadActivity,
                        ),
                      ),
                      onMessages: widget.onOpenMessages,
                    ),
                    const SizedBox(height: 26),
                    const _HomeFooter(),
                    const SizedBox(height: 26),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _showBranches(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BranchSheet(),
    );
  }
}

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 390,
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/hero_ink.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0.06, -0.25),
              filterQuality: FilterQuality.medium,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.44, 0.72, 1],
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.0),
                    AppColors.background.withValues(alpha: 0.52),
                    AppColors.background,
                  ],
                ),
              ),
            ),
            Positioned(
              left: -30,
              right: -30,
              top: topInset + 20,
              height: 240,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.55, -0.1),
                    radius: 0.95,
                    colors: [
                      Colors.white.withValues(alpha: 0.45),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.onOpenMessages,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenMessages;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final displayName = session.user?.displayName ?? '家族成员';
    final member =
        session.memberById(session.membership?.personId) ??
        FamilyMember(
          id: session.user?.id ?? 'account',
          familyId: session.family?.id ?? '',
          branchId: '',
          name: displayName,
          gender: Gender.male,
          generation: 0,
        );
    final role = session.roleLabel ?? '普通成员';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          InkWell(
            onTap: onOpenProfile,
            borderRadius: BorderRadius.circular(28),
            child: Row(
              children: [
                InkPortrait(
                  person: member,
                  width: 44,
                  height: 44,
                  circle: true,
                  showBorder: true,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          role,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: AppColors.inkMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          RoundIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: onOpenMessages,
            tooltip: '消息通知',
            backgroundColor: Colors.white.withValues(alpha: 0.68),
          ),
          const SizedBox(width: 4),
          RoundIconButton(
            icon: Icons.settings_outlined,
            onTap: () => _showSettings(context),
            tooltip: '设置',
            backgroundColor: Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const _SettingsSheet(),
    );
  }
}

class _FamilyIdentity extends StatelessWidget {
  const _FamilyIdentity({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final family = SessionScope.of(context).family;
    final familyName = family?.name ?? '当前家族';
    final motto = (family?.motto ?? '').isEmpty ? '敦亲睦族 · 薪火相传' : family!.motto;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    familyName,
                    style: AppTheme.serif(
                      fontSize: 42,
                      height: 1.08,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: _FamilySeal(),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 15, left: 2),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 22,
                  height: 1,
                  color: AppColors.ink.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 9),
                Text(
                  motto,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w400,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilySeal extends StatelessWidget {
  const _FamilySeal();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.025,
      child: Container(
        width: 26,
        height: 43,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.cinnabar,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFF5DFD5), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2EB4423D),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              '族',
              style: TextStyle(
                fontSize: 11,
                height: 1,
                color: Color(0xFFFFF6E8),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '谱',
              style: TextStyle(
                fontSize: 11,
                height: 1,
                color: Color(0xFFFFF6E8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.onMembersTap,
    required this.onBranchesTap,
    required this.onProfileTap,
  });

  final VoidCallback onMembersTap;
  final VoidCallback onBranchesTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final family = session.family;
    final linkedId = session.membership?.personId;
    final linkedPerson = linkedId == null
        ? null
        : session.tree?.persons
              .where((person) => person.id == linkedId)
              .firstOrNull;
    final generationLabel =
        linkedPerson?.generationLabel ?? (linkedId == null ? '未绑定' : '已绑定');
    return SoftCard(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 17),
      radius: 21,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                icon: Icons.groups_rounded,
                color: AppColors.primary,
                softColor: AppColors.primarySoft,
                label: '家族成员',
                value:
                    '${SessionScope.of(context).tree?.persons.length ?? family?.memberCount ?? 0}',
                onTap: onMembersTap,
              ),
            ),
            const _SummaryDivider(),
            Expanded(
              child: _SummaryItem(
                icon: Icons.account_tree_rounded,
                color: AppColors.jade,
                softColor: AppColors.jadeSoft,
                label: '家支',
                value: '${family?.branchCount ?? 0}',
                onTap: onBranchesTap,
              ),
            ),
            const _SummaryDivider(),
            Expanded(
              child: _SummaryItem(
                icon: Icons.person_pin_circle_outlined,
                color: AppColors.gold,
                softColor: AppColors.goldSoft,
                label: '我的世代',
                value: generationLabel,
                isStatus: true,
                onTap: onProfileTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: AppColors.line,
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.color,
    required this.softColor,
    required this.label,
    required this.value,
    required this.onTap,
    this.isStatus = false,
  });

  final IconData icon;
  final Color color;
  final Color softColor;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isStatus;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: softColor,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.2,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isStatus ? 12.5 : 20,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                              color: isStatus ? AppColors.gold : AppColors.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 1),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: isStatus ? AppColors.gold : AppColors.inkMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onTree,
    required this.onSearch,
    required this.onEditProfile,
    required this.onRequests,
    required this.onGallery,
    required this.onStories,
  });

  final VoidCallback onTree;
  final VoidCallback onSearch;
  final VoidCallback onEditProfile;
  final VoidCallback onRequests;
  final VoidCallback onGallery;
  final VoidCallback onStories;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        label: '族谱树',
        subtitle: '查看家族关系',
        icon: Icons.account_tree_rounded,
        color: AppColors.primary,
        onTap: onTree,
      ),
      _QuickActionData(
        label: '成员查询',
        subtitle: '查找家族成员',
        icon: Icons.people_alt_rounded,
        color: AppColors.jade,
        onTap: onSearch,
      ),
      _QuickActionData(
        label: '资料申请',
        subtitle: '修改个人信息',
        icon: Icons.edit_note_rounded,
        color: AppColors.gold,
        onTap: onEditProfile,
      ),
      _QuickActionData(
        label: '我的申请',
        subtitle: '查看审核进度',
        icon: Icons.assignment_rounded,
        color: AppColors.violet,
        onTap: onRequests,
      ),
      _QuickActionData(
        label: '家族相册',
        subtitle: '珍贵家族影像',
        icon: Icons.photo_library_rounded,
        color: AppColors.teal,
        onTap: onGallery,
      ),
      _QuickActionData(
        label: '家族故事',
        subtitle: '传承家族文化',
        icon: Icons.menu_book_rounded,
        color: AppColors.rose,
        onTap: onStories,
      ),
    ];

    return SoftCard(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      radius: 21,
      child: Column(
        children: [
          Row(
            children: [
              _QuickActionCell(data: actions[0]),
              const _VerticalRule(),
              _QuickActionCell(data: actions[1]),
              const _VerticalRule(),
              _QuickActionCell(data: actions[2]),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              _QuickActionCell(data: actions[3]),
              const _VerticalRule(),
              _QuickActionCell(data: actions[4]),
              const _VerticalRule(),
              _QuickActionCell(data: actions[5]),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 58, color: AppColors.line);
  }
}

class _QuickActionCell extends StatelessWidget {
  const _QuickActionCell({required this.data});

  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 2),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(data.color, Colors.white, 0.08)!,
                      Color.lerp(data.color, Colors.black, 0.08)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: data.color.withValues(alpha: 0.24),
                      blurRadius: 13,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(data.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatestActivity extends StatelessWidget {
  const _LatestActivity({
    required this.activities,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onMore,
    required this.onMessages,
  });

  final List<ApiActivity> activities;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onMore;
  final VoidCallback onMessages;

  @override
  Widget build(BuildContext context) {
    final items = activities.take(3).toList();
    return SoftCard(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 8),
      radius: 21,
      child: Column(
        children: [
          SectionTitle(title: '最新动态', actionLabel: '查看更多', onAction: onMore),
          const SizedBox(height: 9),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (error != null)
            InkWell(
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '动态加载失败，点击重试',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
              ),
            )
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '家族还没有新动态',
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              _ActivityRow(
                activity: items[i],
                onTap: items[i].needsReview ? onMessages : null,
              ),
              if (i != items.length - 1) const Divider(height: 1, indent: 46),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, this.onTap});

  final ApiActivity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActivityLeading(kind: activity.kind),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: activity.actorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              const TextSpan(text: '  '),
                              TextSpan(
                                text: activity.summary,
                                style: const TextStyle(
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, height: 1.35),
                        ),
                      ),
                      if (activity.needsReview) ...[
                        const SizedBox(width: 6),
                        const StatusPill(
                          label: '待审核',
                          foreground: AppColors.gold,
                          background: AppColors.goldSoft,
                          dot: true,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (activity.detail.isNotEmpty)
                        Expanded(
                          child: Text(
                            activity.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              height: 1.3,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 6),
                      Text(
                        _relativeActivityTime(activity.createdAt),
                        style: const TextStyle(
                          fontSize: 9.5,
                          height: 1.2,
                          color: AppColors.inkMuted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
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

class _ActivityLeading extends StatelessWidget {
  const _ActivityLeading({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (kind) {
      'person' => (
        Icons.person_outline_rounded,
        AppColors.primary,
        AppColors.primarySoft,
      ),
      'request' => (
        Icons.assignment_turned_in_outlined,
        AppColors.gold,
        AppColors.goldSoft,
      ),
      'member' => (
        Icons.person_add_alt_1_rounded,
        AppColors.rose,
        AppColors.roseSoft,
      ),
      'family' => (
        Icons.account_tree_outlined,
        AppColors.jade,
        AppColors.jadeSoft,
      ),
      _ => (Icons.history_rounded, AppColors.inkMuted, AppColors.slateSoft),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 19, color: color),
    );
  }
}

String _relativeActivityTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  var local = value.toLocal();
  // Older rows were written by MySQL with the server's wall clock but are
  // parsed by the API as UTC. Treat a far-future value as that wall clock so
  // the home feed does not label old activity as "刚刚".
  if (local.isAfter(now.add(const Duration(minutes: 10)))) {
    local = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
  }
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month-$day';
}

class _HomeFooter extends StatelessWidget {
  const _HomeFooter();

  @override
  Widget build(BuildContext context) {
    final family = SessionScope.of(context).family;
    final subtitle = family != null && family.region.isNotEmpty
        ? family.region
        : '家族族谱 · 传承家风';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 1,
              color: AppColors.inkMuted.withValues(alpha: 0.25),
            ),
            const SizedBox(width: 9),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(width: 9),
            Container(
              width: 28,
              height: 1,
              color: AppColors.inkMuted.withValues(alpha: 0.25),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'FAMILY GENEALOGY · 2026',
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 1.7,
            color: AppColors.inkMuted.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _BranchSheet extends StatefulWidget {
  @override
  State<_BranchSheet> createState() => _BranchSheetState();
}

class _BranchSheetState extends State<_BranchSheet> {
  List<ApiBranch> _branches = const [];
  bool _loading = true;
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
      final branches = await SessionScope.of(context).branches();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _loading = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final persons = session.tree?.persons ?? const <ApiPerson>[];
    final counts = <String, int>{};
    var unassigned = 0;
    for (final person in persons) {
      final branchId = person.branchId;
      if (branchId == null || branchId.isEmpty) {
        unassigned++;
      } else {
        counts[branchId] = (counts[branchId] ?? 0) + 1;
      }
    }
    return _SheetFrame(
      title: '家支概览',
      subtitle: '全族共 ${_branches.length} 个家支 · ${persons.length} 位成员',
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : Column(
              children: [
                for (var i = 0; i < _branches.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? AppColors.jadeSoft
                                : AppColors.slateSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.account_tree_outlined,
                            size: 18,
                            color: i == 0 ? AppColors.jade : AppColors.slate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _branches[i].name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          '${counts[_branches[i].id] ?? 0} 人',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != _branches.length - 1)
                    const Divider(height: 1, indent: 46),
                ],
                if (unassigned > 0) ...[
                  const Divider(height: 1, indent: 46),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.slateSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.help_outline_rounded,
                            size: 18,
                            color: AppColors.slate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '未分家支',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          '$unassigned 人',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: '设置',
      subtitle: '已连接家庭服务器',
      child: Column(
        children: [
          _SettingsRow(icon: Icons.person_outline_rounded, label: '账户与资料'),
          _SettingsRow(icon: Icons.privacy_tip_outlined, label: '隐私与展示范围'),
          _SettingsRow(icon: Icons.contrast_rounded, label: '外观与字号'),
          _SettingsRow(icon: Icons.info_outline_rounded, label: '关于家族族谱'),
          const SizedBox(height: 12),
          const Text(
            'v0.25.0 · Flutter + MySQL',
            style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Text(title, style: AppTheme.serif(fontSize: 21)),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(content: Text('该设置项将在后续版本开放')));
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.inkSoft),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: AppColors.ink),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityFeedPage extends StatelessWidget {
  const _ActivityFeedPage({
    required this.activities,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<ApiActivity> activities;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '家族动态',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '动态加载失败',
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: onRetry, child: const Text('重试')),
                ],
              ),
            )
          : activities.isEmpty
          ? const Center(
              child: Text(
                '家族还没有新动态',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                18,
                8,
                18,
                MediaQuery.paddingOf(context).bottom + 22,
              ),
              itemCount: activities.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final activity = activities[index];
                return SoftCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: _ActivityRow(activity: activity),
                );
              },
            ),
    );
  }
}
