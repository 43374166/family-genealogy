import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/demo_data.dart';
import '../../models/family_member.dart';
import '../person/person_detail_page.dart';

class MemberSearchPage extends StatefulWidget {
  const MemberSearchPage({super.key});

  @override
  State<MemberSearchPage> createState() => _MemberSearchPageState();
}

class _MemberSearchPageState extends State<MemberSearchPage> {
  final _controller = TextEditingController();
  int? _generation;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<FamilyMember> get _results {
    final query = _query.trim().toLowerCase();
    return DemoData.directory.where((member) {
      final matchesGeneration =
          _generation == null || member.generation == _generation;
      if (!matchesGeneration) return false;
      if (query.isEmpty) return true;
      return member.name.toLowerCase().contains(query) ||
          member.aliases.any((alias) => alias.toLowerCase().contains(query)) ||
          (member.birthPlace?.toLowerCase().contains(query) ?? false) ||
          (member.occupation?.toLowerCase().contains(query) ?? false);
    }).toList()..sort((a, b) => a.generation.compareTo(b.generation));
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '成员查询',
              subtitle:
                  '${DemoData.family.name} · 共 ${DemoData.family.memberCount} 人',
              actions: [
                HeaderIconButton(
                  icon: Icons.tune_rounded,
                  onTap: () => _showFilterSheet(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0820323B),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索姓名、籍贯或职业',
                    filled: false,
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                children: [
                  _GenerationChip(
                    label: '全部',
                    selected: _generation == null,
                    onTap: () => setState(() => _generation = null),
                  ),
                  for (final generation in [6, 7, 8, 9, 10])
                    _GenerationChip(
                      label: FamilyMember.generationLabelFor(generation),
                      selected: _generation == generation,
                      onTap: () => setState(() => _generation = generation),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  Text(
                    _query.isEmpty ? '全部成员' : '搜索结果',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${results.length} 位',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.sort_rounded,
                    size: 16,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 3),
                  const Text(
                    '按世代',
                    style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const _EmptySearch()
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        18,
                        2,
                        18,
                        MediaQuery.paddingOf(context).bottom + 24,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final member = results[index];
                        return _MemberRow(
                          member: member,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PersonDetailPage(person: member),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          MediaQuery.paddingOf(context).bottom + 22,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
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
            Text('筛选成员', style: AppTheme.serif(fontSize: 21)),
            const SizedBox(height: 4),
            const Text(
              '当前原型支持按世代浏览，更多筛选将随数据能力一起接入。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '世代',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _GenerationChip(
                  label: '全部',
                  selected: _generation == null,
                  onTap: () {
                    setState(() => _generation = null);
                    Navigator.pop(context);
                  },
                ),
                for (final generation in [6, 7, 8, 9, 10])
                  _GenerationChip(
                    label: FamilyMember.generationLabelFor(generation),
                    selected: _generation == generation,
                    onTap: () {
                      setState(() => _generation = generation);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerationChip extends StatelessWidget {
  const _GenerationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? Colors.transparent : AppColors.line,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.onTap});

  final FamilyMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              InkPortrait(person: member, width: 48, height: 56, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (member.isFemale)
                          const TagPill(
                            label: '女',
                            color: AppColors.rose,
                            background: AppColors.roseSoft,
                          ),
                        if (member.isCurrentUser)
                          const Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: TagPill(
                              label: '本人',
                              color: AppColors.primary,
                              background: AppColors.primarySoft,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        member.generationLabel,
                        if (member.relation == '配偶') '配偶',
                        member.lifespan,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      member.birthPlace ?? '籍贯未记录',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TagPill(
                    label: member.isLiving ? '在世' : '已故',
                    color: member.isLiving
                        ? AppColors.jade
                        : AppColors.inkMuted,
                    background: member.isLiving
                        ? AppColors.jadeSoft
                        : AppColors.slateSoft,
                  ),
                  const SizedBox(height: 9),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: AppColors.inkMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 50),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -math.pi / 18,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  size: 34,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '没有找到相关成员',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              '试试姓名中的其他字，或切换世代筛选',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
