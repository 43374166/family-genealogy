import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/soft_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../services/api_client.dart';
import '../../services/api_models.dart';
import '../../services/app_session.dart';
import '../family/binding_requests_page.dart';
import '../requests/requests_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<_InboxItem> _items = const [];
  bool _loading = true;
  String? _error;
  bool _started = false;

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
      final session = SessionScope.of(context);
      final canReview = session.canWrite;
      final results = await Future.wait([
        session.editRequests(
          status: canReview ? 'pending' : null,
          mine: !canReview,
          limit: 50,
        ),
        session.bindingRequests(
          status: canReview ? 'pending' : null,
          mine: !canReview,
          limit: 50,
        ),
      ]);
      final editPage = results[0] as ApiEditRequestPage;
      final bindingPage = results[1] as ApiBindingRequestPage;
      final items =
          <_InboxItem>[
            for (final request in editPage.items)
              _InboxItem(
                id: request.id,
                title: canReview ? '资料修改待审核' : '我的资料修改',
                subtitle: canReview
                    ? '${request.requesterName} 申请修改 ${request.targetName}'
                    : '${request.targetName} · ${request.summary}',
                time: request.submittedAt,
                status: request.status,
                pending: request.isPending,
                kind: _InboxKind.edit,
              ),
            for (final request in bindingPage.items)
              _InboxItem(
                id: request.id,
                title: canReview ? '人物绑定待审核' : '我的人物绑定',
                subtitle: canReview
                    ? '${request.requesterName} 申请绑定 ${request.personName}'
                    : '申请绑定 ${request.personName}',
                time: request.submittedAt,
                status: request.status,
                pending: request.isPending,
                kind: _InboxKind.binding,
              ),
          ]..sort((a, b) {
            final left = a.time ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.time ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
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

  Future<void> _open(_InboxItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => item.kind == _InboxKind.edit
            ? const RequestsPage()
            : const BindingRequestsPage(),
      ),
    );
    if (mounted) await _load();
  }

  int get _pendingCount => _items.where((item) => item.pending).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppPageHeader(
              title: '消息',
              subtitle: _loading
                  ? '正在加载'
                  : _pendingCount == 0
                  ? '暂无待处理'
                  : '$_pendingCount 条待处理',
              showBack: false,
              padding: const EdgeInsets.fromLTRB(22, 8, 16, 8),
              actions: [
                HeaderIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: _loading ? () {} : _load,
                ),
              ],
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
                  : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mark_email_read_outlined,
                            size: 44,
                            color: AppColors.inkMuted,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '没有新消息',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '资料修改和人物绑定审核会出现在这里',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          18,
                          8,
                          18,
                          MediaQuery.paddingOf(context).bottom + 28,
                        ),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _InboxCard(
                            item: item,
                            onTap: () => _open(item),
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

enum _InboxKind { edit, binding }

class _InboxItem {
  const _InboxItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.status,
    required this.pending,
    required this.kind,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime? time;
  final String status;
  final bool pending;
  final _InboxKind kind;
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.item, required this.onTap});

  final _InboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusView(item);
    return SoftCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.kind == _InboxKind.edit
                      ? AppColors.goldSoft
                      : AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.kind == _InboxKind.edit
                      ? Icons.edit_note_rounded
                      : Icons.person_pin_circle_outlined,
                  size: 20,
                  color: item.kind == _InboxKind.edit
                      ? AppColors.gold
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        StatusPill(
                          label: status.$1,
                          foreground: status.$2,
                          background: status.$3,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Text(
                          _messageTime(item.time),
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 17,
                          color: AppColors.inkMuted,
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

(String, Color, Color) _statusView(_InboxItem item) {
  if (item.pending) {
    return ('待处理', AppColors.gold, AppColors.goldSoft);
  }
  return switch (item.status) {
    'approved' => ('已通过', AppColors.jade, AppColors.jadeSoft),
    'rejected' => ('已驳回', AppColors.cinnabar, AppColors.cinnabarSoft),
    'cancelled' => ('已取消', AppColors.inkMuted, AppColors.slateSoft),
    _ => ('已处理', AppColors.inkMuted, AppColors.slateSoft),
  };
}

String _messageTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  var local = value.toLocal();
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
