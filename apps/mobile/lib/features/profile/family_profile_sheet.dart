import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_data.dart';
import '../../services/app_session.dart';

/// Shows the family space attached to the signed-in account.
Future<void> showFamilyProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _FamilyProfileSheet(),
  );
}

class _FamilyProfileSheet extends StatelessWidget {
  const _FamilyProfileSheet();

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final family = session.family;
    final surname = family?.surname ?? DemoData.family.surname;
    final familyName = family?.name ?? DemoData.family.name;
    final region = family?.region ?? DemoData.family.region;
    final motto = family?.motto ?? DemoData.family.motto;
    final memberCount = family?.memberCount ?? DemoData.family.memberCount;
    final branchCount = family?.branchCount ?? DemoData.family.branchCount;
    final members = session.treeMembers.isEmpty
        ? DemoData.treeMembers
        : session.treeMembers;
    final generations = members
        .map((member) => member.generation)
        .toSet()
        .length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        MediaQuery.paddingOf(context).bottom + 20,
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
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 56,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cinnabar,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24B4423D),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  surname,
                  style: const TextStyle(
                    fontFamily: AppTheme.serifFamily,
                    fontSize: 28,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            familyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.serif(
                              fontSize: 22,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const TagPill(
                          label: '当前家庭',
                          color: AppColors.jade,
                          background: AppColors.jadeSoft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$region · 由当前账户所属家庭提供',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9F9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                _FamilyStat(value: '$memberCount', label: '家族成员'),
                const _StatDivider(),
                _FamilyStat(value: '$branchCount', label: '家支'),
                const _StatDivider(),
                _FamilyStat(value: '$generations', label: '已录入世代'),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0EBDD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '家风家训',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(motto, style: AppTheme.serif(fontSize: 16, height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '家庭名称与成员来自登录账户。账户系统接入后，加入或切换家庭会在这里自动更新。',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.65,
                    color: AppColors.ink.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.line),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('知道了', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _FamilyStat extends StatelessWidget {
  const _FamilyStat({required this.value, required this.label});

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
              fontSize: 21,
              height: 1.1,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 26, color: AppColors.line);
  }
}
