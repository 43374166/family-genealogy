import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../services/app_session.dart';
import '../../features/home/home_page.dart';
import '../../features/messages/messages_page.dart';
import '../../features/person/add_person_page.dart';
import '../../features/person/add_relationship_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/requests/profile_edit_page.dart';
import '../../features/tree/tree_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final GlobalKey<TreePageState> _treeKey = GlobalKey<TreePageState>();
  bool _treeOpened = false;
  String? _treeFamilyId;

  void _select(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
    if (index == 1 && !_treeOpened) {
      _treeOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _treeKey.currentState?.focusSelfOnFirstEntry();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyId = SessionScope.of(context).family?.id;
    if (familyId != _treeFamilyId) {
      _treeFamilyId = familyId;
      _treeOpened = false;
    }
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: _index,
          children: [
            HomePage(
              onOpenTree: () => _select(1),
              onOpenMessages: () => _select(2),
              onOpenProfile: () => _select(3),
            ),
            TreePage(key: _treeKey, onBack: () => _select(0)),
            const MessagesPage(),
            const ProfilePage(),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          currentIndex: _index,
          onSelect: _select,
          onAdd: () => _showAddSheet(context),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddSheet(
        onAddPerson: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddPersonPage()),
          );
        },
        onAddRelation: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AddRelationshipPage(),
            ),
          );
        },
        onEditProfile: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ProfileEditPage()),
          );
        },
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDF1F2), width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A20323B),
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: '首页',
                    selected: currentIndex == 0,
                    onTap: () => onSelect(0),
                  ),
                  _NavItem(
                    icon: Icons.account_tree_outlined,
                    activeIcon: Icons.account_tree_rounded,
                    label: '族谱树',
                    selected: currentIndex == 1,
                    onTap: () => onSelect(1),
                  ),
                  const SizedBox(width: 72),
                  _NavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    label: '消息',
                    selected: currentIndex == 2,
                    badge: true,
                    onTap: () => onSelect(2),
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: '我的',
                    selected: currentIndex == 3,
                    onTap: () => onSelect(3),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                top: -7,
                child: Center(child: _AddButton(onTap: onAdd)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : const Color(0xFF849198);
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(selected ? activeIcon : icon, size: 23, color: color),
                  if (badge)
                    Positioned(
                      right: -4,
                      top: -1,
                      child: Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: BoxDecoration(
                          color: AppColors.cinnabar,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '添加家族内容',
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          border: Border.all(color: const Color(0xFFF7FAFF), width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _AddSheet extends StatelessWidget {
  const _AddSheet({
    required this.onAddPerson,
    required this.onAddRelation,
    required this.onEditProfile,
  });

  final VoidCallback onAddPerson;
  final VoidCallback onAddRelation;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        icon: Icons.person_add_alt_1_rounded,
        title: '新增家族成员',
        subtitle: '由族长录入正式档案',
        color: AppColors.primary,
        background: AppColors.primarySoft,
        onTap: onAddPerson,
      ),
      (
        icon: Icons.family_restroom_rounded,
        title: '添加亲属关系',
        subtitle: '维护父母与配偶关系',
        color: AppColors.jade,
        background: AppColors.jadeSoft,
        onTap: onAddRelation,
      ),
      (
        icon: Icons.edit_note_rounded,
        title: '申请修改资料',
        subtitle: '修改本人信息并提交审核',
        color: AppColors.gold,
        background: AppColors.goldSoft,
        onTap: onEditProfile,
      ),
      (
        icon: Icons.photo_camera_back_outlined,
        title: '上传家族影像',
        subtitle: '记录老照片、祠堂与家族活动',
        color: AppColors.teal,
        background: AppColors.tealSoft,
        onTap: () => _notice(context, '影像上传需在服务端接入后开放'),
      ),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.paddingOf(context).bottom + 18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                color: const Color(0xFFE8EDEE),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Text(
            '添加家族内容',
            style: TextStyle(
              fontFamily: 'NotoSerifSC',
              fontSize: 22,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '族长直接写入，保存后会立即同步到族谱。',
            style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < options.length; i++) ...[
            _AddOption(
              icon: options[i].icon,
              title: options[i].title,
              subtitle: options[i].subtitle,
              color: options[i].color,
              background: options[i].background,
              onTap: options[i].onTap,
            ),
            if (i != options.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  void _notice(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFA),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 9.5,
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
