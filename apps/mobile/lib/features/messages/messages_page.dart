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
  List<ApiNotification> _items = const [];
  int _unread = 0;
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
      final page = await SessionScope.of(context).notifications();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _unread = page.unreadCount;
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

  Future<void> _open(ApiNotification item) async {
    final session = SessionScope.of(context);
    if (!item.isRead) {
      try {
        await session.markNotificationRead(id: item.id);
        if (mounted) {
          setState(() {
            _items = _items
                .map(
                  (value) => value.id == item.id
                      ? ApiNotification(
                          id: value.id,
                          kind: value.kind,
                          title: value.title,
                          body: value.body,
                          targetType: value.targetType,
                          targetId: value.targetId,
                          isRead: true,
                          createdAt: value.createdAt,
                        )
                      : value,
                )
                .toList(growable: false);
            _unread = _unread > 0 ? _unread - 1 : 0;
          });
        }
      } on ApiException {
        // Opening the destination is still useful if read-marking failed.
      }
    }
    if (!mounted) return;
    final page = item.targetType == 'binding_request'
        ? const BindingRequestsPage()
        : const RequestsPage();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _load();
  }

  Future<void> _markAllRead() async {
    try {
      await SessionScope.of(context).markNotificationRead(all: true);
      if (!mounted) return;
      setState(() {
        _unread = 0;
        _items = _items
            .map(
              (value) => ApiNotification(
                id: value.id,
                kind: value.kind,
                title: value.title,
                body: value.body,
                targetType: value.targetType,
                targetId: value.targetId,
                isRead: true,
                createdAt: value.createdAt,
              ),
            )
            .toList(growable: false);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
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
              title: '消息',
              subtitle: _loading
                  ? '正在加载'
                  : _unread == 0
                  ? '全部通知已读'
                  : '$_unread 条未读通知',
              showBack: false,
              padding: const EdgeInsets.fromLTRB(22, 8, 16, 8),
              actions: [
                HeaderIconButton(
                  icon: Icons.done_all_rounded,
                  onTap: _unread == 0 ? () {} : _markAllRead,
                ),
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
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          18,
                          8,
                          18,
                          MediaQuery.paddingOf(context).bottom + 28,
                        ),
                        children: [
                          _EntryCard(
                            icon: Icons.edit_note_rounded,
                            color: AppColors.gold,
                            background: AppColors.goldSoft,
                            title: '资料修改申请',
                            subtitle: '查看自己提交或需要审核的资料修改',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RequestsPage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _EntryCard(
                            icon: Icons.person_pin_circle_outlined,
                            color: AppColors.primary,
                            background: AppColors.primarySoft,
                            title: '人物绑定申请',
                            subtitle: '查看人物绑定审核和申请进度',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BindingRequestsPage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const SectionTitle(title: '通知'),
                          const SizedBox(height: 9),
                          if (_items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 50),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.notifications_none_rounded,
                                    size: 40,
                                    color: AppColors.inkMuted,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    '还没有通知',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '资料修改、人物绑定审核会在这里通知你',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            for (var i = 0; i < _items.length; i++) ...[
                              _NotificationCard(
                                item: _items[i],
                                onTap: () => _open(_items[i]),
                              ),
                              if (i != _items.length - 1)
                                const SizedBox(height: 8),
                            ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final ApiNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBinding = item.targetType == 'binding_request';
    return SoftCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isBinding ? AppColors.primarySoft : AppColors.goldSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBinding
                      ? Icons.person_pin_circle_outlined
                      : Icons.edit_note_rounded,
                  size: 19,
                  color: isBinding ? AppColors.primary : AppColors.gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.cinnabar,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 5),
                        StatusPill(
                          label: item.isRead ? '已读' : '未读',
                          foreground: item.isRead
                              ? AppColors.inkMuted
                              : AppColors.cinnabar,
                          background: item.isRead
                              ? AppColors.slateSoft
                              : AppColors.cinnabarSoft,
                          compact: true,
                        ),
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      _notificationTime(item.createdAt),
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
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

String _notificationTime(DateTime? value) {
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
