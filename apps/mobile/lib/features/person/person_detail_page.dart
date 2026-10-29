import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_data.dart';
import '../../models/family_member.dart';
import '../requests/profile_edit_page.dart';

class PersonDetailPage extends StatelessWidget {
  const PersonDetailPage({super.key, required this.person});

  final FamilyMember person;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            leadingWidth: 62,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: RoundIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                  size: 36,
                  backgroundColor: Colors.white,
                  iconColor: AppColors.ink,
                ),
              ),
            ),
            title: Text('人物档案', style: AppTheme.serif(fontSize: 19)),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: () => _showMore(context),
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    4,
                    18,
                    MediaQuery.paddingOf(context).bottom + 26,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileHero(person: person),
                      const SizedBox(height: 14),
                      _Relationships(person: person),
                      const SizedBox(height: 14),
                      _LifeDetails(person: person),
                      const SizedBox(height: 14),
                      _Biography(person: person),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ProfileEditPage(),
                                ),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              label: const Text('申请修改资料'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.ink,
                                side: const BorderSide(color: AppColors.line),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('族谱定位为演示能力，将在族谱页开放'),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.account_tree_outlined,
                                size: 17,
                              ),
                              label: const Text('在族谱中定位'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            _SheetAction(icon: Icons.ios_share_rounded, label: '分享人物档案'),
            _SheetAction(icon: Icons.flag_outlined, label: '反馈资料问题'),
            _SheetAction(icon: Icons.history_rounded, label: '查看修改记录'),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.person});

  final FamilyMember person;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6F3E9), Color(0xFFE7EFF0)],
        ),
        border: Border.all(color: Colors.white),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            top: -22,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkPortrait(
                    person: person,
                    width: 92,
                    height: 112,
                    radius: 18,
                    showBorder: true,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                person.name,
                                style: AppTheme.serif(
                                  fontSize: 28,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                person.generationLabel,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          person.occupation ??
                              (person.relation == '配偶'
                                  ? '配偶'
                                  : person.tags.isNotEmpty
                                  ? person.tags.first
                                  : '家族成员'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            TagPill(
                              label: person.isLiving ? '在世' : '已故',
                              color: person.isLiving
                                  ? AppColors.jade
                                  : AppColors.inkMuted,
                              background: person.isLiving
                                  ? AppColors.jadeSoft
                                  : AppColors.slateSoft,
                              icon: person.isLiving
                                  ? Icons.wb_sunny_outlined
                                  : Icons.nightlight_outlined,
                            ),
                            if (person.tags.isNotEmpty)
                              TagPill(
                                label: person.tags.first,
                                color: AppColors.cinnabar,
                                background: AppColors.cinnabarSoft,
                                icon: Icons.bookmark_border_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _MiniFact(label: '生卒', value: person.lifespan),
                    Container(
                      width: 1,
                      height: 25,
                      color: AppColors.inkMuted.withValues(alpha: 0.18),
                    ),
                    _MiniFact(label: '籍贯', value: person.birthPlace ?? '未记录'),
                    Container(
                      width: 1,
                      height: 25,
                      color: AppColors.inkMuted.withValues(alpha: 0.18),
                    ),
                    _MiniFact(label: '家支', value: '长房'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniFact extends StatelessWidget {
  const _MiniFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Relationships extends StatelessWidget {
  const _Relationships({required this.person});

  final FamilyMember person;

  @override
  Widget build(BuildContext context) {
    final relations = _relationsFor(person);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 12),
      child: Column(
        children: [
          const SectionTitle(title: '亲属关系'),
          const SizedBox(height: 13),
          for (final relation in relations) ...[
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: relation.person == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PersonDetailPage(person: relation.person!),
                      ),
                    ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 45,
                      child: Text(
                        relation.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                    if (relation.person != null) ...[
                      InkPortrait(
                        person: relation.person!,
                        width: 34,
                        height: 34,
                        circle: true,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          relation.person!.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (relation.extraCount != null) ...[
                        Text(
                          relation.extraCount!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        relation.person!.generationLabel,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.inkMuted,
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          relation.emptyText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (relation != relations.last)
              const Divider(height: 1, indent: 45),
          ],
        ],
      ),
    );
  }
}

class _RelationItem {
  const _RelationItem({
    required this.label,
    this.person,
    this.emptyText = '暂未记录',
    this.extraCount,
  });

  final String label;
  final FamilyMember? person;
  final String emptyText;
  final String? extraCount;
}

List<_RelationItem> _relationsFor(FamilyMember person) {
  final relations = <_RelationItem>[];

  final spouse = DemoData.spouseOf(person.id);
  if (spouse != null) {
    relations.add(_RelationItem(label: '配偶', person: spouse));
  }

  final father = DemoData.fatherOf(person.id);
  if (father != null) {
    relations.add(_RelationItem(label: '父亲', person: father));
  }

  final mother = DemoData.motherOf(person.id);
  if (mother != null) {
    relations.add(_RelationItem(label: '母亲', person: mother));
  }

  final children = DemoData.childrenOf(person.id);
  if (children.isNotEmpty) {
    relations.add(
      _RelationItem(
        label: '子女',
        person: children.first,
        extraCount: children.length > 1 ? '等 ${children.length} 人' : null,
      ),
    );
  }

  if (relations.isEmpty) {
    return const [_RelationItem(label: '亲属', emptyText: '暂未记录亲属关系')];
  }
  return relations;
}

class _LifeDetails extends StatelessWidget {
  const _LifeDetails({required this.person});

  final FamilyMember person;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (
        Icons.cake_outlined,
        '出生',
        person.birthYear == null ? '未记录' : '${person.birthYear} 年',
      ),
      (
        Icons.event_busy_outlined,
        '逝世',
        person.deathYear == null ? '在世' : '${person.deathYear} 年',
      ),
      (Icons.place_outlined, '籍贯', person.birthPlace ?? '未记录'),
      (Icons.home_work_outlined, '现居', person.residence ?? '未记录'),
      (Icons.work_outline_rounded, '职业', person.occupation ?? '未记录'),
    ];

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: '生平信息'),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(rows[i].$1, size: 17, color: AppColors.inkMuted),
                  const SizedBox(width: 11),
                  SizedBox(
                    width: 40,
                    child: Text(
                      rows[i].$2,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$3,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1) const Divider(height: 1, indent: 28),
          ],
        ],
      ),
    );
  }
}

class _Biography extends StatelessWidget {
  const _Biography({required this.person});

  final FamilyMember person;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: '人物生平'),
          const SizedBox(height: 11),
          Text(
            person.biography ?? '暂未记录详细生平。',
            style: const TextStyle(
              fontSize: 13,
              height: 1.8,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 14,
                color: AppColors.jade,
              ),
              const SizedBox(width: 5),
              Text(
                '资料版本 v3 · 最近更新于 2025-04-20',
                style: TextStyle(
                  fontSize: 9.5,
                  color: AppColors.inkMuted.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(const SnackBar(content: Text('该操作将在服务端接入后开放')));
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.inkSoft),
            const SizedBox(width: 13),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
            ),
            const Spacer(),
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
