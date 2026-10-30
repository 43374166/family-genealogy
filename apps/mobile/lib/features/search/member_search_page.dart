import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/ink_portrait.dart';
import '../../core/widgets/status_pill.dart';
import '../../models/family_member.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../person/api_person_detail_page.dart';

class MemberSearchPage extends StatefulWidget {
  const MemberSearchPage({super.key});

  @override
  State<MemberSearchPage> createState() => _MemberSearchPageState();
}

class _MemberSearchPageState extends State<MemberSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<ApiPerson> _results = const [];
  int? _generation;
  String _query = '';
  String? _error;
  bool _loading = true;
  bool _started = false;
  int _serial = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _query = value;
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), _search);
  }

  Future<void> _search() async {
    final serial = ++_serial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await SessionScope.of(
        context,
      ).searchPersons(query: _query, generation: _generation, limit: 100);
      if (!mounted || serial != _serial) return;
      final sorted = [...page.items]
        ..sort((a, b) {
          final generation = a.generationNo.compareTo(b.generationNo);
          if (generation != 0) return generation;
          return a.fullName.compareTo(b.fullName);
        });
      setState(() {
        _results = sorted;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || serial != _serial) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _selectGeneration(int? generation) {
    setState(() => _generation = generation);
    _debounce?.cancel();
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final generations = _generationsOf(session);
    final familyName = session.family?.name ?? '当前家庭';
    final memberCount = session.family?.memberCount ?? _results.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '成员查询',
              subtitle: '$familyName · 共 $memberCount 人',
              actions: [
                HeaderIconButton(
                  icon: Icons.tune_rounded,
                  onTap: () => _showFilterSheet(context, generations),
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
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索姓名、字号',
                    filled: false,
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    suffixIcon: _query.isEmpty
                        ? (_loading
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null)
                        : IconButton(
                            onPressed: () {
                              _controller.clear();
                              _onQueryChanged('');
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
                    onTap: () => _selectGeneration(null),
                  ),
                  for (final generation in generations)
                    _GenerationChip(
                      label: FamilyMember.generationLabelFor(generation),
                      selected: _generation == generation,
                      onTap: () => _selectGeneration(generation),
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
                    '${_results.length} 位',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const Spacer(),
                  if (_loading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.sort_rounded,
                      size: 16,
                      color: AppColors.inkMuted,
                    ),
                  const SizedBox(width: 3),
                  Text(
                    _loading ? '查询中' : '按世代',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? _SearchError(error: _error!, onRetry: _search)
                  : _results.isEmpty && !_loading
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
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final person = _results[index];
                        return _MemberRow(
                          person: person,
                          currentPersonId: session.membership?.personId,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ApiPersonDetailPage(
                                personId: person.id,
                                initialPerson: person,
                              ),
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

  List<int> _generationsOf(AppSession session) {
    final tree = session.tree;
    if (tree == null) return const [];
    final values =
        tree.persons.map((person) => person.generationNo).toSet().toList()
          ..sort();
    return values;
  }

  void _showFilterSheet(BuildContext context, List<int> generations) {
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
              '按世代缩小范围，姓名搜索由服务端实时查询。',
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
                    Navigator.pop(context);
                    _selectGeneration(null);
                  },
                ),
                for (final generation in generations)
                  _GenerationChip(
                    label: FamilyMember.generationLabelFor(generation),
                    selected: _generation == generation,
                    onTap: () {
                      Navigator.pop(context);
                      _selectGeneration(generation);
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
  const _MemberRow({
    required this.person,
    required this.currentPersonId,
    required this.onTap,
  });

  final ApiPerson person;
  final String? currentPersonId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final member = person.toFamilyMember('');
    final isCurrent = currentPersonId == person.id;
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
                        Flexible(
                          child: Text(
                            person.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (member.isFemale)
                          const TagPill(
                            label: '女',
                            color: AppColors.rose,
                            background: AppColors.roseSoft,
                          ),
                        if (isCurrent)
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
                      '${person.generationLabel} · ${member.lifespan}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    if (person.birthPlace.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        person.birthPlace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
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

class _SearchError extends StatelessWidget {
  const _SearchError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
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
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
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
