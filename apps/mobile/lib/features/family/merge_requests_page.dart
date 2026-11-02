import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../search/member_search_page.dart';

class MergeRequestsPage extends StatefulWidget {
  const MergeRequestsPage({super.key});

  @override
  State<MergeRequestsPage> createState() => _MergeRequestsPageState();
}

class _MergeRequestsPageState extends State<MergeRequestsPage> {
  List<ApiFamilyMergeRequest> _items = const [];
  bool _loading = true;
  bool _started = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await SessionScope.of(context).mergeRequests();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _open(ApiFamilyMergeRequest request) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MergeRequestDetailPage(initial: request),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '家族合并',
              subtitle: _loading ? '正在加载' : '${_items.length} 个申请',
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _items.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Icon(
                                  Icons.merge_type_rounded,
                                  size: 44,
                                  color: AppColors.inkMuted,
                                ),
                                SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    '暂时没有家族合并申请',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    '成员加入本家族时，如果原家族有数据，会自动提交到这里',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                18,
                                8,
                                18,
                                MediaQuery.paddingOf(context).bottom + 26,
                              ),
                              itemCount: _items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return InkWell(
                                  onTap: () => _open(item),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '「${item.sourceFamilyName}」→ ${item.targetFamilyName}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            StatusPill(
                                              label: item.statusLabel,
                                              foreground: item.isPending
                                                  ? AppColors.gold
                                                  : AppColors.inkMuted,
                                              background: item.isPending
                                                  ? AppColors.goldSoft
                                                  : AppColors.slateSoft,
                                              compact: true,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          '由 ${item.requesterName} 提交 · '
                                          '${item.personCount} 位人物 · '
                                          '${item.storyCount} 篇故事 · '
                                          '${item.photoCount} 张照片',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppColors.inkMuted,
                                          ),
                                        ),
                                        if (item.reviewNote.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            '备注：${item.reviewNote}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.inkSoft,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Text(
                                              item.isPending
                                                  ? '选择要合并的内容和位置'
                                                  : '查看合并结果',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const Spacer(),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 18,
                                              color: AppColors.inkMuted,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class MergeRequestDetailPage extends StatefulWidget {
  const MergeRequestDetailPage({super.key, required this.initial});

  final ApiFamilyMergeRequest initial;

  @override
  State<MergeRequestDetailPage> createState() => _MergeRequestDetailPageState();
}

class _MergeRequestDetailPageState extends State<MergeRequestDetailPage> {
  ApiFamilyMergeDetail? _detail;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  final Set<String> _personIDs = {};
  final Set<String> _storyIDs = {};
  final Set<String> _photoIDs = {};
  String? _branchID;
  int _startGeneration = 1;
  ApiPerson? _attachParent;
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await SessionScope.of(
        context,
      ).mergeDetail(widget.initial.id);
      if (!mounted) return;
      final pending = detail.request.isPending;
      setState(() {
        _detail = detail;
        _personIDs
          ..clear()
          ..addAll(
            detail.request.selectedPersonIds.isNotEmpty
                ? detail.request.selectedPersonIds
                : pending
                ? detail.persons.map((person) => person.id)
                : const <String>[],
          );
        _storyIDs
          ..clear()
          ..addAll(
            detail.request.selectedStoryIds.isNotEmpty
                ? detail.request.selectedStoryIds
                : pending
                ? detail.stories.map((story) => story.id)
                : const <String>[],
          );
        _photoIDs
          ..clear()
          ..addAll(
            detail.request.selectedPhotoIds.isNotEmpty
                ? detail.request.selectedPhotoIds
                : pending
                ? detail.photos.map((photo) => photo.id)
                : const <String>[],
          );
        _branchID =
            detail.request.targetBranchId ??
            (detail.branches.isNotEmpty ? detail.branches.first.id : null);
        final targetMax =
            SessionScope.of(context).tree?.persons
                .map((person) => person.generationNo)
                .fold<int>(0, (max, value) => value > max ? value : max) ??
            0;
        _startGeneration =
            detail.request.startGeneration ??
            (detail.minGeneration > 0
                ? (targetMax == 0 ? 1 : targetMax + 1)
                : 1);
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

  Future<void> _pickParent() async {
    final person = await Navigator.of(context).push<ApiPerson>(
      MaterialPageRoute<ApiPerson>(
        builder: (_) => const MemberSearchPage(selectMode: true),
      ),
    );
    if (person == null || !mounted) return;
    setState(() {
      _attachParent = person;
      if (person.generationNo > 0) {
        _startGeneration = (person.generationNo + 1).clamp(1, 99);
      }
    });
  }

  Future<void> _approve() async {
    final detail = _detail;
    if (detail == null) return;
    if (_personIDs.isEmpty && _storyIDs.isEmpty && _photoIDs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择一位人物、一篇故事或一张照片')));
      return;
    }
    final start = _startGeneration.clamp(1, 99);
    if (detail.minGeneration > 0 &&
        start + detail.maxGeneration - detail.minGeneration > 99) {
      setState(() => _error = '合并后的世代会超过第 99 世，请调小起始世代');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认合并'),
        content: Text(
          '将把 ${_personIDs.length} 位人物、${_storyIDs.length} 篇故事、'
          '${_photoIDs.length} 张照片合并到当前家族。合并后原家族中没有其他成员时会被归档。',
          style: const TextStyle(fontSize: 12.5, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认合并'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await SessionScope.of(context).approveMerge(
        requestId: detail.request.id,
        personIds: _personIDs.toList(),
        storyIds: _storyIDs.toList(),
        photoIds: _photoIDs.toList(),
        targetBranchId: _branchID ?? '',
        startGeneration: start,
        attachParentId: _attachParent?.id ?? '',
        note: _note.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('合并完成'),
          content: Text(
            '已合并 ${result.importedPersons} 位人物、'
            '${result.importedStories} 篇故事、${result.importedPhotos} 张照片。'
            '${result.sourceArchived ? '原家族已归档。' : '原家族仍有其他成员，继续保持独立。'}',
            style: const TextStyle(fontSize: 12.5, height: 1.7),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    }
  }

  Future<void> _reject() async {
    final detail = _detail;
    if (detail == null) return;
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('拒绝合并申请'),
        content: TextField(
          controller: note,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '拒绝原因（可选）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认拒绝'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      await SessionScope.of(
        context,
      ).rejectMerge(requestId: detail.request.id, note: note.text.trim());
      note.dispose();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      note.dispose();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final request = detail?.request ?? widget.initial;
    final pending = request.isPending;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '合并申请',
              subtitle:
                  '「${request.sourceFamilyName}」并入「${request.targetFamilyName}」',
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _error != null && detail == null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        8,
                        18,
                        MediaQuery.paddingOf(context).bottom + 26,
                      ),
                      children: [
                        SoftCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '来自「${request.sourceFamilyName}」',
                                      style: AppTheme.serif(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  StatusPill(
                                    label: request.statusLabel,
                                    foreground: pending
                                        ? AppColors.gold
                                        : AppColors.inkMuted,
                                    background: pending
                                        ? AppColors.goldSoft
                                        : AppColors.slateSoft,
                                    compact: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '申请人：${request.requesterName} · '
                                '${request.personCount} 位人物 / '
                                '${request.storyCount} 篇故事 / '
                                '${request.photoCount} 张照片',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              if (request.reviewNote.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                Text(
                                  '族长备注：${request.reviewNote}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (detail != null) ...[
                          const SizedBox(height: 16),
                          _SectionHeader(
                            title: '可合并人物',
                            trailing:
                                '${_personIDs.length}/${detail.persons.length}',
                            onAll: pending && detail.persons.isNotEmpty
                                ? () => setState(() {
                                    if (_personIDs.length ==
                                        detail.persons.length) {
                                      _personIDs.clear();
                                    } else {
                                      _personIDs
                                        ..clear()
                                        ..addAll(
                                          detail.persons.map(
                                            (person) => person.id,
                                          ),
                                        );
                                    }
                                  })
                                : null,
                          ),
                          const SizedBox(height: 8),
                          if (detail.persons.isEmpty)
                            const _EmptyLine('原家族没有人物')
                          else
                            SoftCard(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Column(
                                children: [
                                  for (
                                    var i = 0;
                                    i < detail.persons.length;
                                    i++
                                  )
                                    CheckboxListTile(
                                      dense: true,
                                      value: _personIDs.contains(
                                        detail.persons[i].id,
                                      ),
                                      onChanged: pending
                                          ? (value) => setState(() {
                                              final id = detail.persons[i].id;
                                              if (value == true) {
                                                _personIDs.add(id);
                                              } else {
                                                _personIDs.remove(id);
                                              }
                                            })
                                          : null,
                                      title: Text(
                                        detail.persons[i].fullName,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        '${detail.persons[i].branchName.isEmpty ? '未分家支' : detail.persons[i].branchName} · 第 ${detail.persons[i].generationNo} 世'
                                        '${detail.persons[i].lifeStatus == 'living' ? '' : ' · 已故'}',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          _SectionHeader(
                            title: '可合并故事',
                            trailing:
                                '${_storyIDs.length}/${detail.stories.length}',
                            onAll: pending && detail.stories.isNotEmpty
                                ? () => setState(() {
                                    if (_storyIDs.length ==
                                        detail.stories.length) {
                                      _storyIDs.clear();
                                    } else {
                                      _storyIDs
                                        ..clear()
                                        ..addAll(
                                          detail.stories.map(
                                            (story) => story.id,
                                          ),
                                        );
                                    }
                                  })
                                : null,
                          ),
                          const SizedBox(height: 8),
                          if (detail.stories.isEmpty)
                            const _EmptyLine('原家族没有故事')
                          else
                            SoftCard(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Column(
                                children: [
                                  for (final story in detail.stories)
                                    CheckboxListTile(
                                      dense: true,
                                      value: _storyIDs.contains(story.id),
                                      onChanged: pending
                                          ? (value) => setState(() {
                                              if (value == true) {
                                                _storyIDs.add(story.id);
                                              } else {
                                                _storyIDs.remove(story.id);
                                              }
                                            })
                                          : null,
                                      title: Text(
                                        story.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        '${story.photoCount} 张配图'
                                        '${story.personName.isEmpty ? '' : ' · ${story.personName}'}',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          _SectionHeader(
                            title: '可合并照片',
                            trailing:
                                '${_photoIDs.length}/${detail.photos.length}',
                            onAll: pending && detail.photos.isNotEmpty
                                ? () => setState(() {
                                    if (_photoIDs.length ==
                                        detail.photos.length) {
                                      _photoIDs.clear();
                                    } else {
                                      _photoIDs
                                        ..clear()
                                        ..addAll(
                                          detail.photos.map(
                                            (photo) => photo.id,
                                          ),
                                        );
                                    }
                                  })
                                : null,
                          ),
                          const SizedBox(height: 8),
                          if (detail.photos.isEmpty)
                            const _EmptyLine('原家族没有照片')
                          else
                            SoftCard(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Column(
                                children: [
                                  for (final photo in detail.photos)
                                    CheckboxListTile(
                                      dense: true,
                                      value: _photoIDs.contains(photo.id),
                                      onChanged: pending
                                          ? (value) => setState(() {
                                              if (value == true) {
                                                _photoIDs.add(photo.id);
                                              } else {
                                                _photoIDs.remove(photo.id);
                                              }
                                            })
                                          : null,
                                      title: Text(
                                        photo.caption.isEmpty
                                            ? '未命名照片'
                                            : photo.caption,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        photo.personNames.isEmpty
                                            ? '未关联人物'
                                            : photo.personNames.join('、'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          const _SectionHeader(title: '加入位置'),
                          const SizedBox(height: 8),
                          SoftCard(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '目标家支',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                DropdownButtonFormField<String>(
                                  initialValue: _branchID,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: [
                                    for (final branch in detail.branches)
                                      DropdownMenuItem(
                                        value: branch.id,
                                        child: Text(branch.name),
                                      ),
                                  ],
                                  onChanged: pending
                                      ? (value) =>
                                            setState(() => _branchID = value)
                                      : null,
                                ),
                                const SizedBox(height: 13),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        '起始世代',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: pending
                                          ? () => setState(
                                              () => _startGeneration =
                                                  (_startGeneration - 1).clamp(
                                                    1,
                                                    99,
                                                  ),
                                            )
                                          : null,
                                      icon: const Icon(
                                        Icons.remove_circle_outline_rounded,
                                      ),
                                    ),
                                    Text(
                                      '第 $_startGeneration 世',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: pending
                                          ? () => setState(
                                              () => _startGeneration =
                                                  (_startGeneration + 1).clamp(
                                                    1,
                                                    99,
                                                  ),
                                            )
                                          : null,
                                      icon: const Icon(
                                        Icons.add_circle_outline_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  detail.minGeneration > 0
                                      ? '原家族第 ${detail.minGeneration} 世 → 本家族第 $_startGeneration 世（整体平移）'
                                      : '原家族没有人物，世代设置不会生效',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                                const SizedBox(height: 13),
                                OutlinedButton.icon(
                                  onPressed: pending ? _pickParent : null,
                                  icon: const Icon(
                                    Icons.person_pin_circle_outlined,
                                    size: 17,
                                  ),
                                  label: Text(
                                    _attachParent == null
                                        ? '挂到本家族某位人物名下（可选）'
                                        : '挂到 ${_attachParent!.fullName} 名下',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_attachParent != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: pending
                                          ? () => setState(
                                              () => _attachParent = null,
                                            )
                                          : null,
                                      child: const Text('不挂到任何人名下'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _note,
                            maxLength: 500,
                            maxLines: 2,
                            enabled: pending,
                            decoration: const InputDecoration(
                              labelText: '族长备注（可选）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.cinnabar,
                              ),
                            ),
                          ],
                          if (pending) ...[
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _submitting ? null : _approve,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('确认合并所选内容'),
                            ),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: _submitting ? null : _reject,
                              child: const Text(
                                '拒绝这次合并申请',
                                style: TextStyle(color: AppColors.cinnabar),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing, this.onAll});

  final String title;
  final String? trailing;
  final VoidCallback? onAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(
            trailing!,
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
          ),
        ],
        const Spacer(),
        if (onAll != null)
          TextButton(
            onPressed: onAll,
            child: const Text('全选/清空', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
      ),
    );
  }
}
