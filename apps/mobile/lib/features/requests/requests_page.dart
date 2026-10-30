import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/status_pill.dart';
import '../../models/family_activity.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../search/member_search_page.dart';
import 'edit_request_page.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key, this.initialFilter});

  final RequestStatus? initialFilter;

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<ApiEditRequest> _items = const [];
  String? _status;
  bool _loading = true;
  bool _started = false;
  String? _error;
  bool _mineOnly = false;
  bool _canReview = false;

  @override
  void initState() {
    super.initState();
    _status = switch (widget.initialFilter) {
      RequestStatus.pending => 'pending',
      RequestStatus.approved => 'approved',
      RequestStatus.rejected => 'rejected',
      _ => null,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final session = SessionScope.of(context);
    _canReview = session.membership?.canReview ?? false;
    _mineOnly = !_canReview;
    if (_canReview && _status == null) {
      _status = 'pending';
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await SessionScope.of(
        context,
      ).editRequests(status: _status, mine: _mineOnly, limit: 100);
      if (!mounted) return;
      setState(() {
        _items = page.items;
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

  void _changeStatus(String? status) {
    setState(() => _status = status);
    _load();
  }

  Future<void> _startRequest() async {
    final person = await Navigator.of(context).push<ApiPerson>(
      MaterialPageRoute<ApiPerson>(
        builder: (_) => const MemberSearchPage(selectMode: true),
      ),
    );
    if (person == null || !mounted) return;
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            EditRequestPage(personId: person.id, initialPerson: person),
      ),
    );
    if (submitted == true && mounted) {
      _changeStatus('pending');
    }
  }

  Future<void> _review(ApiEditRequest request, bool approve) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? '通过申请' : '拒绝申请'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approve ? '通过后会把本次修改写入正式档案。' : '拒绝时必须填写原因，申请人会看到审核意见。',
              style: const TextStyle(fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: '审核意见（拒绝时必填）',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (!approve && value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: Text(approve ? '确认通过' : '确认拒绝'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return;

    try {
      final session = SessionScope.of(context);
      await session.reviewEditRequest(request.id, approve: approve, note: note);
      await session.refreshTree();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(approve ? '申请已通过' : '申请已拒绝')));
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _canReview ? '资料审核' : '我的申请';
    final subtitle = _canReview
        ? (_status == 'pending'
              ? '待审核 $countPending 条 · 通过后写入正式档案'
              : '审核资料修改申请')
        : '资料修改 · 审核进度';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: title,
              subtitle: subtitle,
              actions: [
                HeaderIconButton(
                  icon: Icons.help_outline_rounded,
                  onTap: () => _showHelp(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: _FilterBar(selected: _status, onChanged: _changeStatus),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Text(
                    _status == null ? '全部申请' : _statusTitle(_status!),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_items.length} 条',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const Spacer(),
                  if (_canReview)
                    InkWell(
                      onTap: () {
                        setState(() => _mineOnly = !_mineOnly);
                        _load();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 3,
                        ),
                        child: Text(
                          '当前：${_mineOnly ? '我的申请' : '全家申请'}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    const Text(
                      '通过后才写入正式档案',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? _RequestsError(error: _error!, onRetry: _load)
                  : _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _items.isEmpty
                  ? const _EmptyRequests()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final request = _items[index];
                          return _RequestCard(
                            request: request,
                            onTap: () => _showRequestDetail(context, request),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: OutlinedButton.icon(
            onPressed: _startRequest,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('发起资料申请'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get countPending =>
      _items.where((request) => request.status == 'pending').length;

  String _statusTitle(String status) => switch (status) {
    'pending' => '待审核申请',
    'approved' => '已通过申请',
    'rejected' => '已拒绝申请',
    'cancelled' => '已取消申请',
    _ => '全部申请',
  };

  void _showHelp(BuildContext context) {
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
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary, size: 21),
                SizedBox(width: 8),
                Text(
                  '审核说明',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 13),
            const _HelpLine(index: '01', text: '普通成员修改资料时，需先提交审核申请。'),
            const _HelpLine(index: '02', text: '族长或管理员核对后，正式档案才会更新。'),
            const _HelpLine(index: '03', text: '拒绝申请时必须保留审核意见，历史记录不会被删除。'),
            const SizedBox(height: 6),
            const Text(
              '数据安全边界由服务端统一校验，客户端按钮仅作展示。',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.inkMuted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDetail(BuildContext context, ApiEditRequest request) {
    final canReviewThis = _canReview && request.isPending;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
        child: SingleChildScrollView(
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
                  Expanded(
                    child: Text(
                      request.summary.isNotEmpty
                          ? request.summary
                          : '${request.targetName} · 资料修改',
                      style: AppTheme.serif(fontSize: 21),
                    ),
                  ),
                  _RequestStatusPill(status: request.status),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '申请人：${request.requesterName} · ${_formatDate(request.submittedAt)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '申请内容',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (request.requestType != 'update_person') ...[
                Text(
                  request.summary.isEmpty ? '写入申请' : request.summary,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '通过后会由服务端校验并写入正式族谱。',
                  style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
                ),
              ] else if (request.changedFields.isEmpty)
                const Text(
                  '没有字段变更',
                  style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                )
              else
                for (final key in request.changedFields)
                  _ChangeRow(
                    label: ApiEditChanges.labelFor(key),
                    value: _changeValue(request, key),
                  ),
              if (request.reviewNote.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: request.isRejected
                        ? AppColors.cinnabarSoft
                        : AppColors.jadeSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.isRejected ? '拒绝原因' : '审核意见',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: request.isRejected
                              ? AppColors.cinnabar
                              : AppColors.jade,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        request.reviewNote,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.65,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (canReviewThis) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _review(request, false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.cinnabar,
                          side: const BorderSide(color: AppColors.cinnabar),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text('拒绝'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _review(request, true);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text('通过'),
                      ),
                    ),
                  ],
                ),
              ] else
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text('知道了'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _changeValue(ApiEditRequest request, String key) {
    final changes = request.changes;
    final value = switch (key) {
      'birthPlace' => changes.birthPlace,
      'residence' => changes.residence,
      'occupation' => changes.occupation,
      'education' => changes.education,
      'biography' => changes.biography,
      _ => null,
    };
    if (value == null) return '—';
    return value.isEmpty ? '（清空）' : value;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(String, String?)>[
      ('全部', null),
      ('待审核', 'pending'),
      ('已通过', 'approved'),
      ('已拒绝', 'rejected'),
    ];
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFF3F5F6)),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option.$2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == option.$2
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    option.$1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected == option.$2
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected == option.$2
                          ? Colors.white
                          : AppColors.inkMuted,
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final ApiEditRequest request;
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
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.summary.isNotEmpty
                          ? request.summary
                          : '${request.targetName} · 资料修改',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  _RequestStatusPill(status: request.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '申请人：${request.requesterName} · ${_formatDate(request.submittedAt)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.inkMuted,
                ),
              ),
              if (request.changedFields.isNotEmpty) ...[
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final key in request.changedFields)
                      TagPill(
                        label: ApiEditChanges.labelFor(key),
                        color: AppColors.primary,
                        background: AppColors.primarySoft,
                      ),
                  ],
                ),
              ],
              if (request.reviewNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '审核意见：${request.reviewNote}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.45,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestStatusPill extends StatelessWidget {
  const _RequestStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      'approved' => ('已通过', AppColors.jade, AppColors.jadeSoft),
      'rejected' => ('已拒绝', AppColors.cinnabar, AppColors.cinnabarSoft),
      'cancelled' => ('已取消', AppColors.inkMuted, AppColors.slateSoft),
      _ => ('待审核', AppColors.gold, AppColors.goldSoft),
    };
    return TagPill(label: label, color: color, background: background);
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                height: 1.55,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpLine extends StatelessWidget {
  const _HelpLine({required this.index, required this.text});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              index,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.65,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 32,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '这里还没有申请',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              '修改资料后提交，审核进度会显示在这里',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsError extends StatelessWidget {
  const _RequestsError({required this.error, required this.onRetry});

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

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
