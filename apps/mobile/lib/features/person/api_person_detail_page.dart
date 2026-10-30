import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import 'edit_person_page.dart';

/// API-backed person profile. The summary received from a search result can be
/// passed as [initialPerson] so the page paints immediately; the full record is
/// still fetched to obtain parents, spouses and children.
class ApiPersonDetailPage extends StatefulWidget {
  const ApiPersonDetailPage({
    super.key,
    required this.personId,
    this.initialPerson,
  });

  final String personId;
  final ApiPerson? initialPerson;

  @override
  State<ApiPersonDetailPage> createState() => _ApiPersonDetailPageState();
}

class _ApiPersonDetailPageState extends State<ApiPersonDetailPage> {
  ApiPerson? _person;
  String? _error;
  bool _loading = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _person = widget.initialPerson;
    _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final person = await session.fetchPerson(widget.personId);
      if (!mounted) return;
      setState(() {
        _person = person;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _editPerson(ApiPerson person) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => EditPersonPage(person: person)),
    );
    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _deleteRelation(ApiRelative relative, String group) async {
    final canWrite = SessionScope.of(context).canWrite;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(canWrite ? '删除亲属关系' : '申请删除亲属关系'),
        content: Text(
          canWrite
              ? '确定删除与 ${relative.fullName} 的${relative.relation}关系吗？只删除关系，不删除人物。'
              : '提交删除与 ${relative.fullName} 的${relative.relation}关系的申请，等待族长或管理员审核。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(canWrite ? '删除关系' : '提交申请'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (relative.edgeId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('关系标识缺失，请刷新后重试')));
      return;
    }
    try {
      final session = SessionScope.of(context);
      final edgeType = group == '配偶' ? 'spouse' : 'parent_child';
      if (canWrite) {
        if (edgeType == 'spouse') {
          await session.deleteSpouse(relative.edgeId);
        } else {
          await session.deleteParentChild(relative.edgeId);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('关系已删除')));
        await _load();
      } else {
        await session.createRelationshipEndRequest(
          edgeType: edgeType,
          edgeId: relative.edgeId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('关系纠错申请已提交')));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = _person;
    final session = SessionScope.of(context);
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
          ),
          if (person == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _LoadingOrError(
                loading: _loading,
                error: _error,
                onRetry: _load,
              ),
            )
          else
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
                        _Relationships(
                          person: person,
                          canWrite: session.canWrite,
                          onDelete: _deleteRelation,
                        ),
                        const SizedBox(height: 14),
                        _LifeDetails(person: person),
                        const SizedBox(height: 14),
                        _Biography(person: person),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _editPerson(person),
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                label: Text(
                                  session.canWrite ? '编辑资料' : '申请修改资料',
                                ),
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
                                onPressed: () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('已打开该成员的真实档案'),
                                      ),
                                    ),
                                icon: const Icon(
                                  Icons.account_tree_outlined,
                                  size: 17,
                                ),
                                label: const Text('查看亲属'),
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
}

class _LoadingOrError extends StatelessWidget {
  const _LoadingOrError({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: AppColors.inkMuted,
            ),
            const SizedBox(height: 12),
            Text(
              error ?? '暂时无法读取人物档案',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.person});

  final ApiPerson person;

  @override
  Widget build(BuildContext context) {
    final member = person.toFamilyMember('');
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkPortrait(
                person: member,
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
                            person.fullName,
                            style: AppTheme.serif(
                              fontSize: 28,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        _GenerationBadge(label: person.generationLabel),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      person.occupation.isEmpty ? '家族成员' : person.occupation,
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
                          label: person.lifeStatus == 'living' ? '在世' : '已故',
                          color: person.lifeStatus == 'living'
                              ? AppColors.jade
                              : AppColors.inkMuted,
                          background: person.lifeStatus == 'living'
                              ? AppColors.jadeSoft
                              : AppColors.slateSoft,
                          icon: person.lifeStatus == 'living'
                              ? Icons.wb_sunny_outlined
                              : Icons.nightlight_outlined,
                        ),
                        if (person.courtesyName.isNotEmpty)
                          TagPill(
                            label: '字 ${person.courtesyName}',
                            color: AppColors.cinnabar,
                            background: AppColors.cinnabarSoft,
                          ),
                        if (person.alias.isNotEmpty)
                          TagPill(
                            label: '号 ${person.alias}',
                            color: AppColors.gold,
                            background: AppColors.goldSoft,
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
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _MiniFact(label: '生卒', value: _lifespan(person)),
                _MiniDivider(),
                _MiniFact(label: '籍贯', value: _orUnknown(person.birthPlace)),
                _MiniDivider(),
                _MiniFact(label: '世代', value: person.generationLabel),
              ],
            ),
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
            textAlign: TextAlign.center,
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

class _MiniDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 25,
      color: AppColors.inkMuted.withValues(alpha: 0.18),
    );
  }
}

class _GenerationBadge extends StatelessWidget {
  const _GenerationBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Relationships extends StatelessWidget {
  const _Relationships({
    required this.person,
    required this.canWrite,
    required this.onDelete,
  });

  final ApiPerson person;
  final bool canWrite;
  final Future<void> Function(ApiRelative relative, String group) onDelete;

  @override
  Widget build(BuildContext context) {
    final groups = <(String, List<ApiRelative>)>[
      if (person.parents.isNotEmpty) ('父母', person.parents),
      if (person.spouses.isNotEmpty) ('配偶', person.spouses),
      if (person.children.isNotEmpty) ('子女', person.children),
    ];
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: '亲属关系'),
          const SizedBox(height: 10),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂未记录亲属关系',
                style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
            )
          else
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 3),
                child: Text(
                  group.$1,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              for (final relative in group.$2)
                InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ApiPersonDetailPage(personId: relative.personId),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: AppColors.inkMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            relative.fullName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          relative.relation,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        IconButton(
                          onPressed: () => onDelete(relative, group.$1),
                          tooltip: canWrite ? '删除关系' : '申请删除关系',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            canWrite
                                ? Icons.delete_outline_rounded
                                : Icons.outbox_outlined,
                            size: 17,
                            color: AppColors.cinnabar,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              if (group != groups.last) const Divider(height: 12),
            ],
        ],
      ),
    );
  }
}

class _LifeDetails extends StatelessWidget {
  const _LifeDetails({required this.person});

  final ApiPerson person;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (Icons.cake_outlined, '出生', _dateText(person.birth, '未记录')),
      (
        Icons.event_busy_outlined,
        '逝世',
        person.lifeStatus == 'living' ? '在世' : _dateText(person.death, '未记录'),
      ),
      (Icons.place_outlined, '籍贯', _orUnknown(person.birthPlace)),
      (Icons.home_work_outlined, '现居', _orUnknown(person.residence)),
      (Icons.work_outline_rounded, '职业', _orUnknown(person.occupation)),
      (Icons.school_outlined, '教育', _orUnknown(person.education)),
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

  final ApiPerson person;

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
            person.biography.isEmpty ? '暂未记录详细生平。' : person.biography,
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
                '资料版本 v${person.version}',
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

String _lifespan(ApiPerson person) {
  final birth = person.birth?.year;
  final death = person.death?.year;
  if (birth == null) return '生卒不详';
  if (death == null) return '$birth–';
  return '$birth–$death';
}

String _dateText(ApiPartialDate? date, String fallback) {
  if (date == null) return fallback;
  if (date.text.isNotEmpty) return date.text;
  if (date.year == null) return fallback;
  if (date.month == null) return '${date.year} 年';
  if (date.day == null) return '${date.year}-${date.month}';
  return '${date.year}-${date.month}-${date.day}';
}

String _orUnknown(String value) => value.isEmpty ? '未记录' : value;
